import Foundation

@MainActor
final class ConsoleSettingsViewModel: ObservableObject {
    @Published var kgAPIKey: String
    @Published var keychainStatusMessage: String?
    @Published var keychainErrorMessage: String?

    init() {
        self.kgAPIKey = ConsoleAppSettings.kgAPIKey
        if kgAPIKey.isEmpty == false {
            keychainStatusMessage = AppLocalization.string(
                "settings.credentials.status.keychain_stored",
                fallback: "Knowledge Graph API key is stored in the macOS Keychain."
            )
        }
    }

    var hasStoredAPIKey: Bool {
        kgAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func saveKnowledgeGraphAPIKey() {
        do {
            try ConsoleAppSettings.saveKnowledgeGraphAPIKey(kgAPIKey)
            kgAPIKey = ConsoleAppSettings.kgAPIKey
            keychainErrorMessage = nil
            keychainStatusMessage = hasStoredAPIKey
                ? AppLocalization.string(
                    "settings.credentials.status.saved",
                    fallback: "Knowledge Graph API key saved to the macOS Keychain."
                )
                : AppLocalization.string(
                    "settings.credentials.status.cleared",
                    fallback: "Knowledge Graph API key cleared from the macOS Keychain."
                )
        } catch {
            keychainErrorMessage = error.localizedDescription
            keychainStatusMessage = nil
        }
    }

    func clearKnowledgeGraphAPIKey() {
        kgAPIKey = ""
        do {
            try ConsoleAppSettings.deleteKnowledgeGraphAPIKey()
            keychainErrorMessage = nil
            keychainStatusMessage = AppLocalization.string(
                "settings.credentials.status.cleared",
                fallback: "Knowledge Graph API key cleared from the macOS Keychain."
            )
        } catch {
            keychainErrorMessage = error.localizedDescription
            keychainStatusMessage = nil
        }
    }
}
