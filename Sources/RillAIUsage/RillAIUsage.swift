import AppKit
import Foundation
import RillExtensionKit

@main
struct RillAIUsage {
    static let extensionID = "dev.rill.aiusage"
    static let contributionID = "ai-usage"

    @MainActor
    static func main() async {
        let session = PerplexitySession()
        if CommandLine.arguments.contains("--connect-claude") {
            do {
                _ = try UsageCredentials.claudeToken(interactive: true)
                print("Claude credential access granted. RillAIUsage never changes credentials.")
            } catch { report("Claude access unavailable. Sign in to Claude Code and try again.") }
            return
        }
        if CommandLine.arguments.contains("--connect-perplexity") {
            session.showSignIn()
            return
        }
        let demo = CommandLine.arguments.contains("--demo") || ProcessInfo.processInfo.environment["RILL_AI_USAGE_DEMO"] == "1"
        let directory = ProcessInfo.processInfo.environment["RILL_EXTENSION_DIRECTORY"] ?? FileManager.default.currentDirectoryPath
        let settingsURL = URL(fileURLWithPath: directory).appendingPathComponent("usage.local.json")
        let settings: UsageSettings
        do {
            settings = try UsageSettings.load(from: settingsURL)
        } catch {
            report("Could not load usage.local.json: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        }
        let client = UsageClient()
        if CommandLine.arguments.contains("--check") {
            let snapshots = demo ? UsageSnapshot.demo(providers: settings.enabledProviders)
                : await snapshots(providers: settings.enabledProviders, client: client, session: session)
            do {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                FileHandle.standardOutput.write(try encoder.encode(snapshots))
                FileHandle.standardOutput.write(Data("\n".utf8))
            } catch { report("Could not encode usage") }
            return
        }
        let connection = RillExtensionConnection()
        let messages = AsyncThrowingStream<RillExtensionMessage, Error> { continuation in
            Task.detached {
                let reader = RillExtensionConnection()
                do {
                    while let message = try reader.receive() { continuation.yield(message) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
        var refresh: Task<Void, Never>?
        defer { refresh?.cancel() }
        do {
            for try await message in messages {
                if message.kind == .shutdown { break }
                guard message.kind == .context, refresh == nil else { continue }
                try connection.send(.init(kind: .hello, extensionID: extensionID))
                refresh = Task {
                    var currentSettings = settings
                    while !Task.isCancelled {
                        do {
                            currentSettings = try UsageSettings.load(from: settingsURL)
                        } catch {
                            report("Could not reload usage.local.json; keeping previous providers: \(error.localizedDescription)")
                        }
                        let readings = demo ? UsageSnapshot.demo(providers: currentSettings.enabledProviders)
                            : await snapshots(providers: currentSettings.enabledProviders, client: client, session: session)
                        guard !Task.isCancelled else { break }
                        do {
                            try connection.send(.init(kind: .update, extensionID: extensionID,
                                contributionID: contributionID, presentation: UsageSnapshot.presentation(readings)))
                            try await Task.sleep(for: .seconds(60))
                        } catch { break }
                    }
                }
            }
        } catch { report("Rill connection closed") }
    }

    @MainActor
    private static func snapshots(providers: [UsageProvider], client: UsageClient, session: PerplexitySession) async -> [UsageSnapshot] {
        await withTaskGroup(of: UsageSnapshot.self) { group in
            for provider in providers {
                group.addTask { await client.fetch(provider, perplexity: session) }
            }
            var readings: [UsageProvider: UsageSnapshot] = [:]
            for await reading in group { readings[reading.provider] = reading }
            return providers.compactMap { readings[$0] }
        }
    }

    private static func report(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
