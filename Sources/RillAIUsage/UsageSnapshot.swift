import Foundation
import RillExtensionKit

enum UsageProvider: String, Codable, CaseIterable, Sendable {
    case claude, codex, perplexity

    var title: String {
        switch self {
        case .claude: "Claude Usage"
        case .codex: "Codex Usage"
        case .perplexity: "Perplexity Usage"
        }
    }

    var icon: String { "Resources/\(self == .codex ? "openai" : rawValue).png" }
    var accent: RillMetricAccent {
        switch self {
        case .claude: .orange
        case .codex: .mint
        case .perplexity: .yellow
        }
    }
}

struct UsageWindow: Codable, Equatable, Sendable {
    let title: String
    let percent: Double?
    let resetsAt: Date?
    let remaining: Int?

    init(title: String, percent: Double? = nil, resetsAt: Date? = nil, remaining: Int? = nil) {
        self.title = title; self.percent = percent; self.resetsAt = resetsAt; self.remaining = remaining
    }
}

struct UsageSnapshot: Codable, Equatable, Sendable {
    let provider: UsageProvider
    let windows: [UsageWindow]
    let status: String?

    var metric: RillMetricContent {
        let primary = windows.first
        let percent = primary?.percent
        let text = percent.map { "\(Int($0.rounded()))%" }
            ?? primary?.remaining.map { "\($0) left" } ?? "?"
        var rows = windows.map { window in
            RillMetricRow(title: window.title, value: window.percent.map { $0 / 100 },
                detail: window.remaining.map { "\($0) remaining" } ?? Self.resetText(window.resetsAt))
        }
        if let status { rows.append(.init(title: status)) }
        return .init(title: provider.title, icon: provider.icon, value: percent.map { $0 / 100 },
                     text: text, accent: provider.accent, rows: rows)
    }

    static func resetText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let minutes = max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
        if minutes < 60 { return "Resets in \(minutes) min" }
        if minutes < 1440 { return "Resets in \(minutes / 60)h \(minutes % 60)m" }
        return "Resets \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
    }

    static func demo(providers: [UsageProvider] = UsageProvider.allCases, now: Date = Date()) -> [UsageSnapshot] {
        [
            .init(provider: .claude, windows: [
                .init(title: "Current session", percent: 73, resetsAt: now.addingTimeInterval(51 * 60)),
                .init(title: "All models", percent: 7, resetsAt: now.addingTimeInterval(2 * 86400))
            ], status: nil),
            .init(provider: .codex, windows: [
                .init(title: "Current session", percent: 21, resetsAt: now.addingTimeInterval(127 * 60)),
                .init(title: "Weekly usage", percent: 12, resetsAt: now.addingTimeInterval(3 * 86400))
            ], status: nil),
            .init(provider: .perplexity, windows: [
                .init(title: "Pro searches", percent: 52, resetsAt: now.addingTimeInterval(8 * 3600)),
                .init(title: "Research", percent: 18, resetsAt: now.addingTimeInterval(8 * 3600))
            ], status: nil)
        ].filter { providers.contains($0.provider) }
    }

    static func presentation(_ snapshots: [UsageSnapshot]) -> RillExtensionPresentation {
        .init(compact: .vStack(snapshots.map { .init(kind: .metric, metric: $0.metric) }))
    }
}

enum UsageError: Error, LocalizedError, Sendable {
    case signIn, invalidResponse, rateLimited(TimeInterval), http(Int), unavailable

    var errorDescription: String? {
        switch self {
        case .signIn: "Sign in required"
        case .invalidResponse: "Usage response unavailable"
        case .rateLimited: "Rate limited, retrying later"
        case .http(let status): "Service error (\(status))"
        case .unavailable: "Connection unavailable"
        }
    }
}

struct UsageParser {
    static func percent(_ value: Double) throws -> Double {
        guard value.isFinite, (0...100).contains(value) else { throw UsageError.invalidResponse }
        return value
    }

    static func claude(_ data: Data) throws -> [UsageWindow] {
        struct Response: Decodable {
            struct Window: Decodable { let utilization: Double; let resets_at: String? }
            struct Limit: Decodable { let kind: String; let percent: Double; let resetsAt: String? }
            let five_hour: Window?
            let seven_day: Window?
            let limits: [Limit]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        var windows: [UsageWindow] = []
        for (label, window) in [("Current session", response.five_hour), ("All models", response.seven_day)] {
            if let window {
                windows.append(.init(title: label, percent: try percent(window.utilization), resetsAt: date(window.resets_at)))
            }
        }
        if windows.isEmpty, let limits = response.limits {
            for limit in limits.prefix(6) {
                let title = limit.kind == "five_hour" || limit.kind == "session" ? "Current session"
                    : ["seven_day", "weekly", "weekly_all"].contains(limit.kind) ? "All models" : limit.kind
                windows.append(.init(title: title, percent: try percent(limit.percent), resetsAt: date(limit.resetsAt)))
            }
        }
        guard !windows.isEmpty else { throw UsageError.invalidResponse }
        return windows
    }

    static func codex(_ data: Data) throws -> [UsageWindow] {
        struct Response: Decodable {
            struct Limits: Decodable {
                struct Window: Decodable { let used_percent: Double; let reset_at: Double?; let reset_after_seconds: Double? }
                let primary_window: Window?
                let secondary_window: Window?
            }
            let rate_limit: Limits?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let windows = try [("Current session", response.rate_limit?.primary_window),
                           ("Weekly usage", response.rate_limit?.secondary_window)].compactMap { label, window -> UsageWindow? in
            guard let window else { return nil }
            let resetsAt = window.reset_at.map { Date(timeIntervalSince1970: $0) }
                ?? window.reset_after_seconds.map { Date().addingTimeInterval($0) }
            return .init(title: label, percent: try percent(window.used_percent), resetsAt: resetsAt)
        }
        guard !windows.isEmpty else { throw UsageError.invalidResponse }
        return windows
    }

    static func perplexity(_ data: Data) throws -> [UsageWindow] {
        struct Response: Decodable {
            let remaining_pro: Int?
            let remaining_research: Int?
            let remaining_agentic_research: Int?
            let remaining_labs: Int?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let windows = [("Pro searches", response.remaining_pro), ("Research", response.remaining_research),
                       ("Agentic research", response.remaining_agentic_research), ("Labs", response.remaining_labs)]
            .compactMap { label, count -> UsageWindow? in
                guard let count, count >= 0 else { return nil }
                return .init(title: label, remaining: count)
            }
        guard !windows.isEmpty else { throw UsageError.invalidResponse }
        return windows
    }

    private static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
