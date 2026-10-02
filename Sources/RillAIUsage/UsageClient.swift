import Foundation
import Security
import LocalAuthentication
import CryptoKit

struct UsageCredentials {
    struct Claude: Decodable {
        struct OAuth: Decodable { let accessToken: String }
        let claudeAiOauth: OAuth
    }

    struct Codex: Decodable {
        struct Tokens: Decodable { let access_token: String; let account_id: String? }
        let tokens: Tokens
    }

    static func claudeToken(interactive: Bool = false) throws -> String {
        let environment = ProcessInfo.processInfo.environment
        let directory = environment["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude"
        let file = URL(fileURLWithPath: directory).appendingPathComponent(".credentials.json")
        if FileManager.default.fileExists(atPath: file.path) {
            let credential = try JSONDecoder().decode(Claude.self, from: Data(contentsOf: file))
            guard !credential.claudeAiOauth.accessToken.isEmpty else { throw UsageError.signIn }
            return credential.claudeAiOauth.accessToken
        }
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        let suffix = SHA256.hash(data: Data(URL(fileURLWithPath: directory).standardizedFileURL.path.utf8))
            .map { String(format: "%02x", $0) }.joined().prefix(8)
        let services = ["Claude Code-credentials-\(suffix)", "Claude Code-credentials"]
        for service in services {
            let query: [String: NSObject] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service as NSString,
                kSecReturnData as String: kCFBooleanTrue,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
                continue
            }
            let credential = try JSONDecoder().decode(Claude.self, from: data)
            if !credential.claudeAiOauth.accessToken.isEmpty { return credential.claudeAiOauth.accessToken }
        }
        throw UsageError.signIn
    }

    static func codex() throws -> Codex.Tokens {
        let environment = ProcessInfo.processInfo.environment
        let directory = environment["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex"
        let file = URL(fileURLWithPath: directory).appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: file.path) else { throw UsageError.signIn }
        let credential = try JSONDecoder().decode(Codex.self, from: Data(contentsOf: file))
        guard !credential.tokens.access_token.isEmpty else { throw UsageError.signIn }
        return credential.tokens
    }
}

actor UsageClient {
    private let session: URLSession
    private var retryDates: [UsageProvider: Date] = [:]
    private var lastGood: [UsageProvider: UsageSnapshot] = [:]
    private var sampledAt: [UsageProvider: Date] = [:]

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }

    func fetch(_ provider: UsageProvider, perplexity: PerplexitySession) async -> UsageSnapshot {
        do {
            if let retry = retryDates[provider], retry > Date() { throw UsageError.rateLimited(retry.timeIntervalSinceNow) }
            let windows: [UsageWindow]
            switch provider {
            case .claude:
                let token = try UsageCredentials.claudeToken()
                let data = try await request(url: "https://api.anthropic.com/api/oauth/usage?cedar_ember=1",
                    headers: ["Authorization": "Bearer \(token)", "anthropic-beta": "oauth-2025-04-20"])
                windows = try UsageParser.claude(data)
            case .codex:
                let credential = try UsageCredentials.codex()
                var headers = ["Authorization": "Bearer \(credential.access_token)"]
                if let accountID = credential.account_id { headers["ChatGPT-Account-Id"] = accountID }
                let data = try await request(url: "https://chatgpt.com/backend-api/wham/usage", headers: headers)
                windows = try UsageParser.codex(data)
            case .perplexity:
                windows = try await UsageParser.perplexity(perplexity.fetch())
            }
            let snapshot = UsageSnapshot(provider: provider, windows: windows, status: nil)
            lastGood[provider] = snapshot; sampledAt[provider] = Date(); retryDates[provider] = nil
            return snapshot
        } catch {
            if case UsageError.rateLimited(let delay) = error {
                retryDates[provider] = Date().addingTimeInterval(max(60, delay))
            }
            let message = (error as? UsageError)?.errorDescription ?? UsageError.unavailable.errorDescription ?? "Unavailable"
            let cached = lastGood[provider]
            let age = sampledAt[provider].map { max(0, Int(Date().timeIntervalSince($0) / 60)) }
            let status = cached == nil ? message : "\(message). Last reading: \(age ?? 0) min ago"
            return .init(provider: provider, windows: cached?.windows ?? [], status: status)
        }
    }

    private func request(url: String, headers: [String: String]) async throws -> Data {
        guard let url = URL(string: url) else { throw UsageError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UsageError.invalidResponse }
        if response.statusCode == 401 || response.statusCode == 403 { throw UsageError.signIn }
        if response.statusCode == 429 {
            let delay = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 300
            throw UsageError.rateLimited(delay.isFinite ? min(max(60, delay), 86400) : 300)
        }
        guard (200..<300).contains(response.statusCode) else { throw UsageError.http(response.statusCode) }
        guard data.count <= 1_048_576 else { throw UsageError.invalidResponse }
        return data
    }
}
