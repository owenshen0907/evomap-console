import Foundation

enum ConsoleAppSettings {
    static let hubBaseURLKey = "settings.hubBaseURL"
    static let kgAPIKeyKey = "settings.kgAPIKey"
    static let appLanguageKey = "settings.appLanguage"
    static let defaultNodeNameKey = "settings.defaultNodeName"
    static let defaultNodeModelKey = "settings.defaultNodeModel"
    static let showRawPayloadsKey = "settings.showRawPayloads"
    static let patchCourierRelayEmailKey = "settings.patchCourierRelayEmail"
    static let patchCourierProjectSlugKey = "settings.patchCourierProjectSlug"

    private static let kgAPIKeyStore: KnowledgeGraphAPIKeyStoring = KeychainKnowledgeGraphAPIKeyStore()

    static var hubBaseURL: String {
        normalizedString(for: hubBaseURLKey) ?? "https://evomap.ai"
    }

    static var defaultNodeName: String {
        normalizedString(for: defaultNodeNameKey) ?? AppLocalization.phrase("Primary Mac Node")
    }

    static var defaultNodeModel: String {
        normalizedString(for: defaultNodeModelKey) ?? "gpt-5"
    }

    static var kgAPIKey: String {
        migrateLegacyKnowledgeGraphAPIKeyIfNeeded()
        return (try? kgAPIKeyStore.loadAPIKey()) ?? ""
    }

    static var showRawPayloads: Bool {
        UserDefaults.standard.object(forKey: showRawPayloadsKey) as? Bool ?? true
    }

    static var patchCourierRelayEmail: String {
        normalizedString(for: patchCourierRelayEmailKey) ?? ""
    }

    static var patchCourierProjectSlug: String {
        normalizedString(for: patchCourierProjectSlugKey) ?? "evomap-tasks"
    }

    static var appLanguage: ConsoleLanguage {
        let rawValue = UserDefaults.standard.string(forKey: appLanguageKey) ?? ConsoleLanguage.system.rawValue
        return ConsoleLanguage(rawValue: rawValue) ?? .system
    }

    static var defaultIdentityDoc: String {
        AppLocalization.string(
            "defaults.identity_doc",
            fallback: "Native macOS console for managing EvoMap nodes, skills, services, orders, and knowledge graph operations."
        )
    }

    static var defaultConstitution: String {
        AppLocalization.string(
            "defaults.constitution",
            fallback: "Operate safely, preserve user control, favor verifiable actions, and avoid destructive changes without confirmation."
        )
    }

    static func saveKnowledgeGraphAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try kgAPIKeyStore.deleteAPIKey()
        } else {
            try kgAPIKeyStore.saveAPIKey(trimmed)
        }
        UserDefaults.standard.removeObject(forKey: kgAPIKeyKey)
    }

    static func deleteKnowledgeGraphAPIKey() throws {
        try kgAPIKeyStore.deleteAPIKey()
        UserDefaults.standard.removeObject(forKey: kgAPIKeyKey)
    }

    private static func normalizedString(for key: String) -> String? {
        guard let value = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func migrateLegacyKnowledgeGraphAPIKeyIfNeeded() {
        guard let legacyValue = normalizedString(for: kgAPIKeyKey) else {
            return
        }

        do {
            try kgAPIKeyStore.saveAPIKey(legacyValue)
            UserDefaults.standard.removeObject(forKey: kgAPIKeyKey)
        } catch {
            // Leave the legacy value in UserDefaults so the user can still recover it.
        }
    }
}
