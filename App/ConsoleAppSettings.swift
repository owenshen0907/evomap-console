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
    static let patchCourierBackendEnabledKey = "settings.patchCourierBackendEnabled"
    static let patchCourierBackendSenderEmailKey = "settings.patchCourierBackendSenderEmail"
    static let patchCourierBackendIMAPHostKey = "settings.patchCourierBackendIMAPHost"
    static let patchCourierBackendIMAPPortKey = "settings.patchCourierBackendIMAPPort"
    static let patchCourierBackendIMAPSecurityKey = "settings.patchCourierBackendIMAPSecurity"
    static let patchCourierBackendSMTPHostKey = "settings.patchCourierBackendSMTPHost"
    static let patchCourierBackendSMTPPortKey = "settings.patchCourierBackendSMTPPort"
    static let patchCourierBackendSMTPSecurityKey = "settings.patchCourierBackendSMTPSecurity"
    static let patchCourierBackendPollIntervalSecondsKey = "settings.patchCourierBackendPollIntervalSeconds"

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

    static var patchCourierBackendEnabled: Bool {
        UserDefaults.standard.bool(forKey: patchCourierBackendEnabledKey)
    }

    static var patchCourierBackendSenderEmail: String {
        normalizedString(for: patchCourierBackendSenderEmailKey) ?? ""
    }

    static var patchCourierBackendIMAPHost: String {
        normalizedString(for: patchCourierBackendIMAPHostKey) ?? ""
    }

    static var patchCourierBackendIMAPPort: Int {
        let value = UserDefaults.standard.integer(forKey: patchCourierBackendIMAPPortKey)
        return value > 0 ? value : 993
    }

    static var patchCourierBackendIMAPSecurity: PatchCourierMailSecurity {
        let rawValue = UserDefaults.standard.string(forKey: patchCourierBackendIMAPSecurityKey) ?? PatchCourierMailSecurity.sslTLS.rawValue
        return PatchCourierMailSecurity(rawValue: rawValue) ?? .sslTLS
    }

    static var patchCourierBackendSMTPHost: String {
        normalizedString(for: patchCourierBackendSMTPHostKey) ?? ""
    }

    static var patchCourierBackendSMTPPort: Int {
        let value = UserDefaults.standard.integer(forKey: patchCourierBackendSMTPPortKey)
        return value > 0 ? value : 465
    }

    static var patchCourierBackendSMTPSecurity: PatchCourierMailSecurity {
        let rawValue = UserDefaults.standard.string(forKey: patchCourierBackendSMTPSecurityKey) ?? PatchCourierMailSecurity.sslTLS.rawValue
        return PatchCourierMailSecurity(rawValue: rawValue) ?? .sslTLS
    }

    static var patchCourierBackendPollIntervalSeconds: Int {
        let value = UserDefaults.standard.integer(forKey: patchCourierBackendPollIntervalSecondsKey)
        return max(30, value > 0 ? value : 60)
    }

    static var patchCourierMailTransportScriptURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("runtime-tools", isDirectory: true)
            .appendingPathComponent("patch_courier_mail_transport.py")
    }

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EvomapConsole", isDirectory: true)
    }

    static var patchCourierBackendAccount: PatchCourierMailAccount? {
        guard let senderEmail = patchCourierBackendSenderEmail.nonEmpty,
              let imapHost = patchCourierBackendIMAPHost.nonEmpty,
              let smtpHost = patchCourierBackendSMTPHost.nonEmpty else {
            return nil
        }
        let now = Date()
        return PatchCourierMailAccount(
            id: senderEmail.lowercased(),
            label: "EvomapConsole",
            emailAddress: senderEmail,
            role: "operator",
            workspaceRoot: NSHomeDirectory(),
            imap: PatchCourierMailEndpoint(
                host: imapHost,
                port: patchCourierBackendIMAPPort,
                security: patchCourierBackendIMAPSecurity
            ),
            smtp: PatchCourierMailEndpoint(
                host: smtpHost,
                port: patchCourierBackendSMTPPort,
                security: patchCourierBackendSMTPSecurity
            ),
            pollingIntervalSeconds: patchCourierBackendPollIntervalSeconds,
            createdAt: now,
            updatedAt: now
        )
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
