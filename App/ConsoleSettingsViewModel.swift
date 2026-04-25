import Foundation

@MainActor
final class ConsoleSettingsViewModel: ObservableObject {
    @Published var kgAPIKey: String
    @Published var patchCourierMailPassword: String = ""
    @Published var keychainStatusMessage: String?
    @Published var keychainErrorMessage: String?
    @Published var patchCourierBackendStatusMessage: String?
    @Published var patchCourierBackendErrorMessage: String?
    @Published var isTestingPatchCourierBackend = false

    private let patchCourierPasswordStore: PatchCourierMailPasswordStoring
    private let patchCourierTransportClient: PatchCourierMailTransportClient

    init(
        patchCourierPasswordStore: PatchCourierMailPasswordStoring = KeychainPatchCourierMailPasswordStore(),
        patchCourierTransportClient: PatchCourierMailTransportClient = PatchCourierMailTransportClient()
    ) {
        self.patchCourierPasswordStore = patchCourierPasswordStore
        self.patchCourierTransportClient = patchCourierTransportClient
        self.kgAPIKey = ConsoleAppSettings.kgAPIKey
        self.patchCourierMailPassword = (try? patchCourierPasswordStore.loadPassword(account: ConsoleAppSettings.patchCourierBackendSenderEmail)) ?? ""
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

    var hasStoredPatchCourierMailPassword: Bool {
        patchCourierMailPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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

    func reloadPatchCourierMailPasswordForCurrentSender() {
        patchCourierMailPassword = (try? patchCourierPasswordStore.loadPassword(account: ConsoleAppSettings.patchCourierBackendSenderEmail)) ?? ""
    }

    func savePatchCourierMailPassword() {
        do {
            guard let sender = ConsoleAppSettings.patchCourierBackendSenderEmail.nonEmpty else {
                patchCourierBackendErrorMessage = AppLocalization.string(
                    "settings.patch_courier.backend.error.no_sender",
                    fallback: "Enter the sender mailbox before saving its app password."
                )
                patchCourierBackendStatusMessage = nil
                return
            }
            let trimmed = patchCourierMailPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try patchCourierPasswordStore.deletePassword(account: sender)
            } else {
                try patchCourierPasswordStore.savePassword(trimmed, account: sender)
            }
            patchCourierBackendErrorMessage = nil
            patchCourierBackendStatusMessage = trimmed.isEmpty
                ? AppLocalization.string("settings.patch_courier.backend.status.password_cleared", fallback: "Patch Courier backend mail password cleared from Keychain.")
                : AppLocalization.string("settings.patch_courier.backend.status.password_saved", fallback: "Patch Courier backend mail password saved to Keychain.")
        } catch {
            patchCourierBackendErrorMessage = error.localizedDescription
            patchCourierBackendStatusMessage = nil
        }
    }

    func clearPatchCourierMailPassword() {
        do {
            if let sender = ConsoleAppSettings.patchCourierBackendSenderEmail.nonEmpty {
                try patchCourierPasswordStore.deletePassword(account: sender)
            }
            patchCourierMailPassword = ""
            patchCourierBackendErrorMessage = nil
            patchCourierBackendStatusMessage = AppLocalization.string(
                "settings.patch_courier.backend.status.password_cleared",
                fallback: "Patch Courier backend mail password cleared from Keychain."
            )
        } catch {
            patchCourierBackendErrorMessage = error.localizedDescription
            patchCourierBackendStatusMessage = nil
        }
    }

    func testPatchCourierBackendConnection() {
        guard let account = ConsoleAppSettings.patchCourierBackendAccount else {
            patchCourierBackendErrorMessage = AppLocalization.string(
                "settings.patch_courier.backend.error.incomplete",
                fallback: "Complete sender, IMAP, and SMTP settings before testing."
            )
            patchCourierBackendStatusMessage = nil
            return
        }
        let password = patchCourierMailPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password.isEmpty == false else {
            patchCourierBackendErrorMessage = AppLocalization.string(
                "settings.patch_courier.backend.error.no_password",
                fallback: "Save or enter the mailbox app password before testing."
            )
            patchCourierBackendStatusMessage = nil
            return
        }

        isTestingPatchCourierBackend = true
        patchCourierBackendErrorMessage = nil
        patchCourierBackendStatusMessage = nil
        let transportClient = patchCourierTransportClient
        Task {
            do {
                let result = try await Task.detached {
                    try transportClient.probe(account: account, password: password)
                }.value
                await MainActor.run {
                    isTestingPatchCourierBackend = false
                    if result.imap.ok && result.smtp.ok {
                        patchCourierBackendStatusMessage = AppLocalization.string(
                            "settings.patch_courier.backend.status.probe_ok",
                            fallback: "IMAP and SMTP checks passed."
                        )
                        patchCourierBackendErrorMessage = nil
                    } else {
                        patchCourierBackendStatusMessage = nil
                        patchCourierBackendErrorMessage = [
                            result.imap.detail.map { "IMAP: \($0)" },
                            result.smtp.detail.map { "SMTP: \($0)" }
                        ]
                        .compactMap { $0 }
                        .joined(separator: "\n")
                    }
                }
            } catch {
                await MainActor.run {
                    isTestingPatchCourierBackend = false
                    patchCourierBackendErrorMessage = error.localizedDescription
                    patchCourierBackendStatusMessage = nil
                }
            }
        }
    }
}
