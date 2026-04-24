import SwiftUI

struct NodeConnectionSheet: View {
    @Binding var draft: NodeConnectionDraft
    let isConnecting: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.editingNodeID == nil
                ? AppLocalization.string("node_connection.title.connect", fallback: "Connect Node")
                : AppLocalization.string("node_connection.title.reconnect", fallback: "Reconnect Node"))
                .font(.title2.weight(.bold))

            Text(AppLocalization.string(
                "node_connection.description",
                fallback: "Register this Mac app as an EvoMap node through the official `/a2a/hello` handshake, then store the returned `node_secret` securely in the Keychain."
            ))
                .foregroundStyle(.secondary)

            Form {
                Section(AppLocalization.string("node_connection.section.identity", fallback: "Identity")) {
                    TextField(AppLocalization.string("node.field.node_name", fallback: "Node name"), text: $draft.nodeName)
                    TextField(AppLocalization.string("node.field.sender_id", fallback: "Sender ID"), text: $draft.senderID)
                    TextField(AppLocalization.string("node.field.model", fallback: "Model"), text: $draft.modelName)
                    Picker(AppLocalization.string("node.field.environment", fallback: "Environment"), selection: $draft.environment) {
                        ForEach(NodeEnvironment.allCases, id: \.self) { environment in
                            Text(environment.title).tag(environment)
                        }
                    }
                }

                Section(AppLocalization.string("node_connection.section.hub", fallback: "Hub")) {
                    TextField(AppLocalization.string("node.field.base_url", fallback: "Base URL"), text: $draft.baseURL)
                    TextField(AppLocalization.string("node.field.referrer_optional", fallback: "Referrer (optional)"), text: $draft.referrer)
                }

                Section(AppLocalization.string("node_connection.section.counts", fallback: "Counts")) {
                    Stepper(
                        AppLocalization.string("node_connection.count.genes", fallback: "Genes: %d", draft.geneCount),
                        value: $draft.geneCount,
                        in: 0...999
                    )
                    Stepper(
                        AppLocalization.string("node_connection.count.capsules", fallback: "Capsules: %d", draft.capsuleCount),
                        value: $draft.capsuleCount,
                        in: 0...999
                    )
                }

                Section(AppLocalization.string("node_connection.section.profile", fallback: "Profile")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.string("node_connection.identity_doc", fallback: "Identity Doc"))
                            .font(.headline)
                        TextEditor(text: $draft.identityDoc)
                            .frame(minHeight: 96)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.string("node_connection.constitution", fallback: "Constitution"))
                            .font(.headline)
                        TextEditor(text: $draft.constitution)
                            .frame(minHeight: 96)
                    }
                }
            }
            .formStyle(.grouped)

            if let errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            HStack {
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel, action: onCancel)
                Spacer()
                Button {
                    onSubmit()
                } label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(AppLocalization.string("node_connection.send_hello", fallback: "Send Hello"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting || !isDraftReady)
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 720)
    }

    private var isDraftReady: Bool {
        !draft.nodeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.senderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    NodeConnectionSheet(
        draft: .constant(
            NodeConnectionDraft(
                editingNodeID: nil,
                nodeName: AppLocalization.phrase("Primary Mac Node"),
                senderID: "node_primary_mac",
                baseURL: "https://evomap.ai",
                environment: .production,
                modelName: "gpt-5",
                geneCount: 0,
                capsuleCount: 0,
                referrer: "",
                identityDoc: ConsoleAppSettings.defaultIdentityDoc,
                constitution: ConsoleAppSettings.defaultConstitution
            )
        ),
        isConnecting: false,
        errorMessage: nil,
        onCancel: {},
        onSubmit: {}
    )
}
