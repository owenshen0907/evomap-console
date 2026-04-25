import SwiftUI

struct ConsoleSettingsView: View {
    @AppStorage(ConsoleAppSettings.appLanguageKey) private var appLanguageRawValue = ConsoleLanguage.system.rawValue
    @AppStorage(ConsoleAppSettings.hubBaseURLKey) private var hubBaseURL = "https://evomap.ai"
    @AppStorage(ConsoleAppSettings.defaultNodeNameKey) private var defaultNodeName = AppLocalization.phrase("Primary Mac Node")
    @AppStorage(ConsoleAppSettings.defaultNodeModelKey) private var defaultNodeModel = "gpt-5"
    @AppStorage(ConsoleAppSettings.showRawPayloadsKey) private var showRawPayloads = true
    @AppStorage(ConsoleAppSettings.patchCourierRelayEmailKey) private var patchCourierRelayEmail = ""
    @AppStorage(ConsoleAppSettings.patchCourierProjectSlugKey) private var patchCourierProjectSlug = "evomap-tasks"
    @AppStorage(ConsoleAppSettings.patchCourierBackendEnabledKey) private var patchCourierBackendEnabled = false
    @AppStorage(ConsoleAppSettings.patchCourierBackendSenderEmailKey) private var patchCourierBackendSenderEmail = ""
    @AppStorage(ConsoleAppSettings.patchCourierBackendIMAPHostKey) private var patchCourierBackendIMAPHost = ""
    @AppStorage(ConsoleAppSettings.patchCourierBackendIMAPPortKey) private var patchCourierBackendIMAPPort = 993
    @AppStorage(ConsoleAppSettings.patchCourierBackendIMAPSecurityKey) private var patchCourierBackendIMAPSecurity = PatchCourierMailSecurity.sslTLS.rawValue
    @AppStorage(ConsoleAppSettings.patchCourierBackendSMTPHostKey) private var patchCourierBackendSMTPHost = ""
    @AppStorage(ConsoleAppSettings.patchCourierBackendSMTPPortKey) private var patchCourierBackendSMTPPort = 465
    @AppStorage(ConsoleAppSettings.patchCourierBackendSMTPSecurityKey) private var patchCourierBackendSMTPSecurity = PatchCourierMailSecurity.sslTLS.rawValue
    @AppStorage(ConsoleAppSettings.patchCourierBackendPollIntervalSecondsKey) private var patchCourierBackendPollIntervalSeconds = 60
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

            Section(AppLocalization.string("settings.section.patch_courier", fallback: "Patch Courier")) {
                TextField(
                    AppLocalization.string("settings.patch_courier.relay_email", fallback: "Relay mailbox"),
                    text: $patchCourierRelayEmail
                )
                TextField(
                    AppLocalization.string("settings.patch_courier.project_slug", fallback: "Managed project slug"),
                    text: $patchCourierProjectSlug
                )
                Text(AppLocalization.string(
                    "settings.patch_courier.note",
                    fallback: "Use a Patch Courier managed project such as evomap-tasks. EvomapConsole opens task/status emails through your mail app; Patch Courier executes and replies asynchronously."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section(AppLocalization.string("settings.patch_courier.backend.section", fallback: "Patch Courier backend mail")) {
                Toggle(
                    AppLocalization.string("settings.patch_courier.backend.enabled", fallback: "Enable silent send and auto check"),
                    isOn: $patchCourierBackendEnabled
                )

                TextField(
                    AppLocalization.string("settings.patch_courier.backend.sender_email", fallback: "Sender / reply mailbox"),
                    text: $patchCourierBackendSenderEmail
                )
                .onChange(of: patchCourierBackendSenderEmail) { _, _ in
                    viewModel.reloadPatchCourierMailPasswordForCurrentSender()
                }

                SecureField(
                    AppLocalization.string("settings.patch_courier.backend.password", fallback: "Mailbox app password"),
                    text: $viewModel.patchCourierMailPassword
                )

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text(AppLocalization.string("settings.patch_courier.backend.imap", fallback: "IMAP"))
                            .foregroundStyle(.secondary)
                        TextField(AppLocalization.string("settings.patch_courier.backend.host", fallback: "Host"), text: $patchCourierBackendIMAPHost)
                        TextField(AppLocalization.string("settings.patch_courier.backend.port", fallback: "Port"), value: $patchCourierBackendIMAPPort, format: .number)
                            .frame(width: 72)
                        Picker("", selection: $patchCourierBackendIMAPSecurity) {
                            ForEach(PatchCourierMailSecurity.allCases) { security in
                                Text(security.title).tag(security.rawValue)
                            }
                        }
                        .labelsHidden()
                    }

                    GridRow {
                        Text(AppLocalization.string("settings.patch_courier.backend.smtp", fallback: "SMTP"))
                            .foregroundStyle(.secondary)
                        TextField(AppLocalization.string("settings.patch_courier.backend.host", fallback: "Host"), text: $patchCourierBackendSMTPHost)
                        TextField(AppLocalization.string("settings.patch_courier.backend.port", fallback: "Port"), value: $patchCourierBackendSMTPPort, format: .number)
                            .frame(width: 72)
                        Picker("", selection: $patchCourierBackendSMTPSecurity) {
                            ForEach(PatchCourierMailSecurity.allCases) { security in
                                Text(security.title).tag(security.rawValue)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Stepper(
                    AppLocalization.string(
                        "settings.patch_courier.backend.poll_interval",
                        fallback: "Auto check every %d seconds",
                        patchCourierBackendPollIntervalSeconds
                    ),
                    value: $patchCourierBackendPollIntervalSeconds,
                    in: 30...600,
                    step: 30
                )

                HStack {
                    Button(AppLocalization.string("settings.patch_courier.backend.save_password", fallback: "Save password")) {
                        viewModel.savePatchCourierMailPassword()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(AppLocalization.string("settings.patch_courier.backend.clear_password", fallback: "Clear password")) {
                        viewModel.clearPatchCourierMailPassword()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.hasStoredPatchCourierMailPassword)

                    Button(
                        viewModel.isTestingPatchCourierBackend
                            ? AppLocalization.string("settings.patch_courier.backend.testing", fallback: "Testing")
                            : AppLocalization.string("settings.patch_courier.backend.test", fallback: "Test connection")
                    ) {
                        viewModel.testPatchCourierBackendConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isTestingPatchCourierBackend)
                }

                if let status = viewModel.patchCourierBackendStatusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let error = viewModel.patchCourierBackendErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Text(AppLocalization.string(
                    "settings.patch_courier.backend.note",
                    fallback: "This mailbox sends EVOMAP_EXECUTE to the relay and checks replies in its INBOX. The app password is stored in Keychain; EvoMap node secrets are never sent to Patch Courier."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
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
