import SwiftUI

struct ConsoleSettingsView: View {
    @AppStorage(ConsoleAppSettings.appLanguageKey) private var appLanguageRawValue = ConsoleLanguage.system.rawValue
    @AppStorage(ConsoleAppSettings.hubBaseURLKey) private var hubBaseURL = "https://evomap.ai"
    @AppStorage(ConsoleAppSettings.defaultNodeNameKey) private var defaultNodeName = AppLocalization.phrase("Primary Mac Node")
    @AppStorage(ConsoleAppSettings.defaultNodeModelKey) private var defaultNodeModel = "gpt-5"
    @AppStorage(ConsoleAppSettings.showRawPayloadsKey) private var showRawPayloads = true
    @StateObject private var viewModel = ConsoleSettingsViewModel()

    var body: some View {
        Form {
            Section(AppLocalization.string("settings.section.language", fallback: "Language")) {
                Picker(
                    AppLocalization.string("settings.language.label", fallback: "App language"),
                    selection: $appLanguageRawValue
                ) {
                    ForEach(ConsoleLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }

                Text(AppLocalization.string(
                    "settings.language.note",
                    fallback: "Switch the operator console language between Simplified Chinese, English, and Japanese. The selection is saved locally on this Mac."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section(AppLocalization.string("settings.section.endpoints", fallback: "Endpoints")) {
                TextField(AppLocalization.string("settings.endpoints.hub_base_url", fallback: "Hub Base URL"), text: $hubBaseURL)
                Toggle(
                    AppLocalization.string("settings.endpoints.show_raw_payloads", fallback: "Show raw payload inspectors by default"),
                    isOn: $showRawPayloads
                )
            }

            Section(AppLocalization.string("settings.section.credentials", fallback: "Credentials")) {
                SecureField(AppLocalization.string("settings.credentials.kg_api_key", fallback: "Knowledge Graph API Key"), text: $viewModel.kgAPIKey)
                HStack {
                    Button(AppLocalization.string("settings.credentials.save_to_keychain", fallback: "Save to Keychain")) {
                        viewModel.saveKnowledgeGraphAPIKey()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(AppLocalization.string("settings.credentials.clear", fallback: "Clear")) {
                        viewModel.clearKnowledgeGraphAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.hasStoredAPIKey)
                }

                LabeledContent(
                    AppLocalization.string("settings.credentials.storage_label", fallback: "Storage"),
                    value: viewModel.hasStoredAPIKey
                        ? AppLocalization.string("settings.credentials.storage_ready", fallback: "Keychain ready")
                        : AppLocalization.string("settings.credentials.storage_empty", fallback: "No API key stored")
                )

                if let status = viewModel.keychainStatusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let error = viewModel.keychainErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Text(AppLocalization.string(
                    "settings.credentials.node_secret_note",
                    fallback: "Node secrets are stored per sender ID in the macOS Keychain after a successful `/a2a/hello` response."
                ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(AppLocalization.string(
                    "settings.credentials.kg_api_key_note",
                    fallback: "The Knowledge Graph API key is also stored in the macOS Keychain so the local console can call `/kg/*` endpoints directly without keeping secrets in plain text settings."
                ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.string("settings.section.defaults", fallback: "Defaults")) {
                TextField(AppLocalization.string("settings.defaults.node_nickname", fallback: "Default node nickname"), text: $defaultNodeName)
                TextField(AppLocalization.string("settings.defaults.node_model", fallback: "Default node model"), text: $defaultNodeModel)
            }

            Section(AppLocalization.string("settings.section.build", fallback: "Build")) {
                LabeledContent(AppLocalization.string("settings.build.version", fallback: "Version"), value: AppBuildMetadata.version)
                LabeledContent(AppLocalization.string("settings.build.build", fallback: "Build"), value: AppBuildMetadata.build)
                LabeledContent(AppLocalization.string("settings.build.updated", fallback: "Updated"), value: AppBuildMetadata.updatedAt)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560)
    }
}

#Preview {
    ConsoleSettingsView()
}
