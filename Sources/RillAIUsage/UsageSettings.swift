import Foundation

struct UsageSettings: Decodable, Equatable, Sendable {
    let enabledProviders: [UsageProvider]

    private enum CodingKeys: String, CodingKey {
        case enabledProviders = "enabled_providers"
    }

    init(enabledProviders: [UsageProvider] = UsageProvider.allCases) {
        self.enabledProviders = enabledProviders
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let providers = try fields.decode([UsageProvider].self, forKey: .enabledProviders)
        guard !providers.isEmpty, Set(providers).count == providers.count else {
            throw DecodingError.dataCorruptedError(forKey: .enabledProviders, in: fields,
                debugDescription: "Choose at least one provider without duplicates.")
        }
        enabledProviders = UsageProvider.allCases.filter { providers.contains($0) }
    }

    static func load(from url: URL) throws -> UsageSettings {
        do {
            return try JSONDecoder().decode(UsageSettings.self, from: Data(contentsOf: url))
        } catch CocoaError.fileReadNoSuchFile {
            return UsageSettings()
        }
    }
}
