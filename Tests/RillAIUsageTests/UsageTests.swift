import Foundation
import Testing
import RillExtensionKit
@testable import RillAIUsage

@Test func providerSelectionRemovesDisabledServicesFromThePresentation() throws {
    let settings = try JSONDecoder().decode(UsageSettings.self,
        from: Data(#"{"enabled_providers":["codex","claude"]}"#.utf8))
    #expect(settings.enabledProviders == [.claude, .codex])
    let readings = UsageSnapshot.demo(providers: settings.enabledProviders)
    #expect(readings.map(\.provider) == [.claude, .codex])
    let presentation = UsageSnapshot.presentation(readings)
    #expect(presentation.compact.children.compactMap(\.metric).map(\.title) == ["Claude Usage", "Codex Usage"])
}

@Test func codexCanBeUsedAlone() throws {
    let settings = try JSONDecoder().decode(UsageSettings.self, from: Data(#"{"enabled_providers":["codex"]}"#.utf8))
    #expect(UsageSnapshot.demo(providers: settings.enabledProviders).map(\.provider) == [.codex])
}

@Test func rejectsInvalidProviderSelection() {
    for json in [#"{"enabled_providers":[]}"#, #"{"enabled_providers":["codex","codex"]}"#,
                 #"{"enabled_providers":["unknown"]}"#, #"{}"#] {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(UsageSettings.self, from: Data(json.utf8)) }
    }
}

@Test func settingsReloadFromDiskAndDefaultOnlyWhenMissing() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("usage.local.json")
    #expect(try UsageSettings.load(from: file).enabledProviders == UsageProvider.allCases)
    try Data(#"{"enabled_providers":["claude","codex"]}"#.utf8).write(to: file)
    #expect(try UsageSettings.load(from: file).enabledProviders == [.claude, .codex])
    try Data(#"{"enabled_providers":["codex"]}"#.utf8).write(to: file)
    #expect(try UsageSettings.load(from: file).enabledProviders == [.codex])
    try Data("invalid".utf8).write(to: file)
    #expect(throws: DecodingError.self) { try UsageSettings.load(from: file) }
}

@Test func parsesClaudeUsageAndResetTime() throws {
    let json = #"{"five_hour":{"utilization":73,"resets_at":"2026-10-02T12:30:00.000Z"},"seven_day":{"utilization":7,"resets_at":null}}"#
    let windows = try UsageParser.claude(Data(json.utf8))
    #expect(windows.map(\.percent) == [73, 7])
    #expect(windows[0].resetsAt != nil)
    #expect(windows[1].resetsAt == nil)
}

@Test func parsesNewClaudeLimits() throws {
    let json = #"{"limits":[{"kind":"session","percent":32,"resetsAt":"2026-10-02T12:30:00Z"}]}"#
    let windows = try UsageParser.claude(Data(json.utf8))
    #expect(windows.first?.title == "Current session")
    #expect(windows.first?.percent == 32)
}

@Test func codexUsesAccountWindows() throws {
    let json = #"{"rate_limit":{"primary_window":{"used_percent":21,"reset_at":1790944200},"secondary_window":{"used_percent":12,"reset_after_seconds":3600}},"additional_rate_limits":[{"limit_name":"other"}]}"#
    let windows = try UsageParser.codex(Data(json.utf8))
    #expect(windows.map(\.percent) == [21, 12])
    #expect(windows[0].resetsAt == Date(timeIntervalSince1970: 1790944200))
}

@Test func perplexityDoesNotInventPercentages() throws {
    let json = #"{"remaining_pro":52,"remaining_research":0,"remaining_labs":3}"#
    let windows = try UsageParser.perplexity(Data(json.utf8))
    let metric = UsageSnapshot(provider: .perplexity, windows: windows, status: nil).metric
    #expect(metric.value == nil)
    #expect(metric.text == "52 left")
    #expect(metric.rows.allSatisfy { $0.value == nil })
}

@Test func unavailableDoesNotBecomeZero() {
    let metric = UsageSnapshot(provider: .claude, windows: [], status: "Sign in required").metric
    #expect(metric.value == nil)
    #expect(metric.text == "?")
    #expect(metric.rows.first?.title == "Sign in required")
}

@Test func rejectsMissingAndInvalidReadings() {
    for json in [#"{}"#, #"{"five_hour":{"utilization":101}}"#, #"{"five_hour":{"utilization":-1}}"#] {
        #expect(throws: UsageError.self) { try UsageParser.claude(Data(json.utf8)) }
    }
}

@Test func demoMatchesReferenceAndValidatesProtocol() throws {
    let readings = UsageSnapshot.demo()
    #expect(readings.map { $0.metric.text } == ["73%", "21%", "52%"])
    let presentation = UsageSnapshot.presentation(readings)
    let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    try presentation.validate(packageDirectory: package)
    let message = RillExtensionMessage(kind: .update, extensionID: "dev.rill.aiusage",
        contributionID: "ai-usage", presentation: presentation)
    #expect(try RillExtensionFrameCodec.decode(RillExtensionFrameCodec.encode(message)) == message)
}
