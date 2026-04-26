import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: ConsoleStore
    @Environment(\.openSettings) private var openSettings
    @AppStorage(ConsoleAppSettings.patchCourierBackendEnabledKey) private var patchCourierBackendEnabled = false

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $store.searchText, placement: .toolbar, prompt: store.searchPrompt)
        .inspector(isPresented: $store.isInspectorPresented) {
            inspectorColumn
                .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Label(AppLocalization.string("toolbar.toggle_sidebar", fallback: "Toggle Sidebar"), systemImage: "sidebar.leading")
                }
            }

            ToolbarItem {
                Button {
                    store.refreshCurrentSection()
                } label: {
                    Label(
                        (store.selectedSection == .nodes && store.isRefreshingNodeHeartbeat)
                            || (store.selectedSection == .bounties && store.isLoadingBountyTasks)
                            || (store.selectedSection == .orders && store.isRefreshingOrders)
                            ? AppLocalization.string("toolbar.refreshing", fallback: "Refreshing")
                            : AppLocalization.string("toolbar.refresh", fallback: "Refresh"),
                        systemImage: (store.selectedSection == .nodes && store.isRefreshingNodeHeartbeat)
                            || (store.selectedSection == .bounties && store.isLoadingBountyTasks)
                            || (store.selectedSection == .orders && store.isRefreshingOrders)
                            ? "arrow.trianglehead.2.clockwise.rotate.90"
                            : "arrow.clockwise"
                    )
                }
                .disabled(
                    (store.selectedSection == .nodes && store.isRefreshingNodeHeartbeat)
                        || (store.selectedSection == .bounties && store.isLoadingBountyTasks)
                        || (store.selectedSection == .orders && store.isRefreshingOrders)
                )
            }

            ToolbarItem {
                Button {
                    store.performPrimaryAction()
                } label: {
                    Text(AppLocalization.phrase(store.primaryActionTitle))
                }
            }

            if store.selectedSection == .skills && store.skillWorkspaceMode == .local {
                ToolbarItem {
                    Button {
                        Task {
                            await store.publishSelectedSkill()
                        }
                    } label: {
                        Label(
                            store.isPublishingSelectedSkill
                                ? AppLocalization.string("toolbar.publishing", fallback: "Publishing")
                                : store.skillPublishActionTitle,
                            systemImage: store.isPublishingSelectedSkill
                                ? "arrow.trianglehead.2.clockwise.rotate.90"
                                : "paperplane.fill"
                        )
                    }
                    .disabled(!store.canPublishSelectedSkill)
                }
            }

            if store.selectedSection == .skills && store.skillWorkspaceMode == .store {
                ToolbarItem {
                    Button {
                        Task {
                            await store.downloadSelectedRemoteSkill()
                        }
                    } label: {
                        Label(
                            store.isDownloadingSelectedRemoteSkill
                                ? AppLocalization.string("toolbar.downloading", fallback: "Downloading")
                                : AppLocalization.string("toolbar.download_to_library", fallback: "Download to Library"),
                            systemImage: store.isDownloadingSelectedRemoteSkill
                                ? "arrow.down.circle.fill"
                                : "arrow.down.circle"
                        )
                    }
                    .disabled(!store.canDownloadSelectedRemoteSkill)
                }
            }

            ToolbarItem {
                Button {
                    store.isInspectorPresented.toggle()
                } label: {
                    Label(
                        store.isInspectorPresented
                            ? AppLocalization.string("toolbar.hide_inspector", fallback: "Hide Inspector")
                            : AppLocalization.string("toolbar.show_inspector", fallback: "Show Inspector"),
                        systemImage: store.isInspectorPresented ? "sidebar.trailing" : "sidebar.right"
                    )
                }
            }

            ToolbarItem {
                Button {
                    openSettings()
                } label: {
                    Label(AppLocalization.string("toolbar.settings", fallback: "Settings"), systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $store.isPresentingNodeConnectionSheet) {
            NodeConnectionSheet(
                draft: $store.nodeConnectionDraft,
                isConnecting: store.isConnectingNode,
                errorMessage: store.nodeConnectionErrorMessage,
                onCancel: {
                    store.isPresentingNodeConnectionSheet = false
                },
                onSubmit: {
                    Task {
                        await store.submitNodeConnection()
                    }
                }
            )
        }
        .sheet(isPresented: $store.isPresentingServiceComposer) {
            ServiceComposerSheet(store: store)
        }
        .sheet(isPresented: $store.isPresentingOrderComposer) {
            OrderComposerSheet(store: store)
        }
        .sheet(isPresented: $store.isPresentingServiceRatingComposer) {
            ServiceRatingSheet(store: store)
        }
        .fileImporter(
            isPresented: $store.isPresentingSkillImporter,
            allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    store.skillImportErrorMessage = AppLocalization.phrase("Choose one `SKILL.md` file.")
                    return
                }
                store.importSkill(from: url)
            case .failure(let error):
                store.skillImportErrorMessage = error.localizedDescription
            }
        }
        .alert(
            AppLocalization.string("skill_import.alert.failed", fallback: "Skill Import Failed"),
            isPresented: Binding(
                get: { store.skillImportErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.skillImportErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button(AppLocalization.string("common.ok", fallback: "OK"), role: .cancel) {
                    store.skillImportErrorMessage = nil
                }
            },
            message: {
                Text(AppLocalization.phrase(store.skillImportErrorMessage ?? AppLocalization.string("skill_import.error.unknown", fallback: "Unknown import error.")))
            }
        )
        .task {
            store.startPatchCourierBackendPollingIfNeeded()
        }
        .onChange(of: patchCourierBackendEnabled) { _, isEnabled in
            if isEnabled {
                store.startPatchCourierBackendPollingIfNeeded()
            } else {
                store.stopPatchCourierBackendPolling()
            }
        }
    }

    private var sidebar: some View {
        List(ConsoleSection.allCases, selection: Binding(
            get: { store.selectedSection },
            set: { section in
                if let section {
                    store.setSection(section)
                }
            }
        )) { section in
            HStack(spacing: 10) {
                Label(section.title, systemImage: section.systemImage)
                Spacer(minLength: 12)
                if let badgeTitle = section.badgeTitle {
                    Text(badgeTitle)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .tag(section)
        }
        .navigationTitle(AppLocalization.string("app.name", fallback: "EvoMap Console"))
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch store.selectedSection {
        case .overview:
            OverviewListView(store: store)
        case .nodes:
            NodesTableView(store: store)
        case .credits:
            CreditsListView(store: store)
        case .bounties:
            BountyTasksListView(store: store)
        case .skills:
            SkillsListView(store: store)
        case .services:
            ServicesListView(store: store)
        case .orders:
            OrdersListView(store: store)
        case .graph:
            GraphWorkspaceListView(store: store)
        case .activity:
            ComingSoonCollectionView(section: store.selectedSection)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch store.selectedSection {
        case .overview:
            OverviewDetailView(store: store)
        case .nodes:
            NodeDetailView(store: store, node: store.selectedNode)
        case .credits:
            CreditsDetailView(store: store)
        case .bounties:
            BountyTaskDetailView(store: store)
        case .skills:
            SkillsDetailView(store: store)
        case .services:
            ServiceDetailView(store: store)
        case .orders:
            OrderDetailView(store: store)
        case .graph:
            GraphWorkspaceDetailView(store: store)
        case .activity:
            ComingSoonDetailView(section: store.selectedSection)
        }
    }

    @ViewBuilder
    private var inspectorColumn: some View {
        switch store.selectedSection {
        case .overview:
            OverviewInspectorView(store: store)
        case .nodes:
            NodeInspectorView(node: store.selectedNode)
        case .credits:
            CreditsInspectorView(store: store)
        case .bounties:
            BountyInspectorView(store: store)
        case .skills:
            SkillsInspectorView(store: store)
        case .services:
            ServiceInspectorView(store: store)
        case .orders:
            OrderInspectorView(store: store)
        case .graph:
            GraphInspectorView(store: store)
        case .activity:
            PlaceholderInspectorView(section: store.selectedSection)
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

private struct OverviewListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.string("overview.section.health", fallback: "Health")) {
                ForEach(store.overviewMetrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(metric.title, systemImage: metric.systemImage)
                            .font(.headline)
                        Text(metric.value)
                            .font(.title2.weight(.semibold))
                        Text(metric.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if store.hasSampleSeedData {
                Section(AppLocalization.string("overview.data_source.title", fallback: "Data source")) {
                    LabeledContent(
                        AppLocalization.string("overview.data_source.live_nodes", fallback: "Real nodes"),
                        value: "\(store.liveNodeCount)"
                    )
                    LabeledContent(
                        AppLocalization.string("overview.data_source.demo_nodes", fallback: "Demo nodes"),
                        value: "\(store.sampleNodeCount)"
                    )
                    LabeledContent(
                        AppLocalization.string("overview.data_source.live_skills", fallback: "Real skills"),
                        value: "\(store.liveSkillCount)"
                    )
                    LabeledContent(
                        AppLocalization.string("overview.data_source.demo_skills", fallback: "Demo skills"),
                        value: "\(store.sampleSkillCount)"
                    )
                }
            }

            Section(AppLocalization.string("overview.section.recent_activity", fallback: "Recent activity")) {
                ForEach(store.recentOverviewEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.localizedTitle)
                            .font(.headline)
                        Text(event.localizedDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(event.timestamp.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct OverviewDetailView: View {
    @ObservedObject var store: ConsoleStore

    private var dayOneSteps: [DayOneStep] {
        [
            DayOneStep(
                id: "node",
                title: AppLocalization.string("overview.day_one.node.title", fallback: "Connect this Mac as a node"),
                detail: AppLocalization.string("overview.day_one.node.detail", fallback: "Use Nodes > Connect Node. The app sends `/a2a/hello`, stores the returned `node_secret` in Keychain, and shows a claim URL when EvoMap returns one."),
                systemImage: "server.rack",
                targetSection: .nodes
            ),
            DayOneStep(
                id: "claim",
                title: AppLocalization.string("overview.day_one.claim.title", fallback: "Claim the node in the browser"),
                detail: AppLocalization.string("overview.day_one.claim.detail", fallback: "Open the claim URL once. This binds node earnings to your EvoMap account; the local app itself never settles credits."),
                systemImage: "link.badge.plus",
                targetSection: .nodes
            ),
            DayOneStep(
                id: "credits",
                title: AppLocalization.string("overview.day_one.credits.title", fallback: "Use Credits as the operating queue"),
                detail: AppLocalization.string("overview.day_one.credits.detail", fallback: "After the node is claimed, use Credits to understand balance, target, and the earning flow."),
                systemImage: "creditcard.and.123",
                targetSection: .credits
            ),
            DayOneStep(
                id: "bounties",
                title: AppLocalization.string("overview.day_one.bounties.title", fallback: "Track bounty tasks"),
                detail: AppLocalization.string("overview.day_one.bounties.detail", fallback: "Load the public bounty board, follow promising tasks, then claim only tasks you can answer cleanly."),
                systemImage: "target",
                targetSection: .bounties
            ),
            DayOneStep(
                id: "skill",
                title: AppLocalization.string("overview.day_one.skill.title", fallback: "Publish skills only after the content is clean"),
                detail: AppLocalization.string("overview.day_one.skill.detail", fallback: "Import a local `SKILL.md` when your Japanese vocabulary and grammar data is ready. Keep the first public skill narrow and testable."),
                systemImage: "sparkles.rectangle.stack",
                targetSection: .skills
            ),
            DayOneStep(
                id: "api",
                title: AppLocalization.string("overview.day_one.api.title", fallback: "Add API keys later"),
                detail: AppLocalization.string("overview.day_one.api.detail", fallback: "For day one, node_secret is enough. Use Settings > Knowledge Graph API Key only after your account can access paid `/kg/*` APIs."),
                systemImage: "key",
                targetSection: .graph
            ),
        ]
    }

    private var moduleGuideItems: [ModuleGuideItem] {
        [
            ModuleGuideItem(
                section: .overview,
                purpose: AppLocalization.string("overview.module.overview.purpose", fallback: "A command-center summary of node health, published skills, pending reviews, and recent events."),
                useWhen: AppLocalization.string("overview.module.overview.when", fallback: "Start here to understand whether the local console is ready before opening specific workspaces.")
            ),
            ModuleGuideItem(
                section: .nodes,
                purpose: AppLocalization.string("overview.module.nodes.purpose", fallback: "Connect this Mac to EvoMap through `/a2a/hello`, store `node_secret`, inspect claim state, and refresh heartbeat snapshots."),
                useWhen: AppLocalization.string("overview.module.nodes.when", fallback: "Use this first. Without a real connected node, most authenticated A2A actions cannot run.")
            ),
            ModuleGuideItem(
                section: .credits,
                purpose: AppLocalization.string("overview.module.credits.purpose", fallback: "Explain balances, show the Premium target, and keep the earning workflow linear."),
                useWhen: AppLocalization.string("overview.module.credits.when", fallback: "Use after the node is claimed to understand credit state and next steps.")
            ),
            ModuleGuideItem(
                section: .bounties,
                purpose: AppLocalization.string("overview.module.bounties.purpose", fallback: "Load many public bounty tasks, translate task text locally, follow promising tasks, and claim selected work."),
                useWhen: AppLocalization.string("overview.module.bounties.when", fallback: "Use when you are ready to choose one bounty-backed question to answer.")
            ),
            ModuleGuideItem(
                section: .skills,
                purpose: AppLocalization.string("overview.module.skills.purpose", fallback: "Import local `SKILL.md` files and publish, update, rollback, download, or manage Skill Store entries."),
                useWhen: AppLocalization.string("overview.module.skills.when", fallback: "Use after your Japanese vocabulary or grammar workflow is cleaned and ready to be called by others.")
            ),
            ModuleGuideItem(
                section: .services,
                purpose: AppLocalization.string("overview.module.services.purpose", fallback: "Browse the marketplace and publish callable services with pricing, capabilities, and delivery expectations."),
                useWhen: AppLocalization.string("overview.module.services.when", fallback: "Use when you want others to spend credits calling your Japanese learning service.")
            ),
            ModuleGuideItem(
                section: .orders,
                purpose: AppLocalization.string("overview.module.orders.purpose", fallback: "Track marketplace orders, task states, submissions, acceptance, and ratings."),
                useWhen: AppLocalization.string("overview.module.orders.when", fallback: "Use after your service starts receiving calls or when you order another service.")
            ),
            ModuleGuideItem(
                section: .graph,
                purpose: AppLocalization.string("overview.module.graph.purpose", fallback: "Query and write paid EvoMap Knowledge Graph data through `/kg/*` endpoints."),
                useWhen: AppLocalization.string("overview.module.graph.when", fallback: "Use later, after your account can access paid KG APIs and the API key is saved in Settings.")
            ),
            ModuleGuideItem(
                section: .activity,
                purpose: AppLocalization.string("overview.module.activity.purpose", fallback: "A future audit/history workspace for reviewing what the console and agents have done."),
                useWhen: AppLocalization.string("overview.module.activity.when", fallback: "Ignore for now; it remains intentionally deferred.")
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppLocalization.string("overview.operator_snapshot.title", fallback: "Operator Snapshot"))
                    .font(.largeTitle.weight(.bold))

                Text(AppLocalization.string(
                    "overview.operator_snapshot.body",
                    fallback: "Start in `Nodes` to run the real `/a2a/hello` handshake, keep the node alive through authenticated `/a2a/heartbeat` polling, move to `Skills` to manage the Skill Store, use `Services` to inspect marketplace listings or publish your own callable agent service, then open `Graph` to query your paid EvoMap knowledge graph directly from macOS."
                ))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if store.hasSampleSeedData {
                    detailCard(AppLocalization.string("overview.data_source.title", fallback: "Data source"), systemImage: "tray.full") {
                        Text(AppLocalization.string(
                            "overview.data_source.note",
                            fallback: "The built-in demo nodes and skills are only there to show the interface. The headline metrics below count real connected nodes and real imported skills only."
                        ))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            DataSourcePill(
                                title: AppLocalization.string("overview.data_source.live_nodes", fallback: "Real nodes"),
                                value: "\(store.liveNodeCount)",
                                tintName: store.liveNodeCount > 0 ? "green" : "orange"
                            )
                            DataSourcePill(
                                title: AppLocalization.string("overview.data_source.demo_nodes", fallback: "Demo nodes"),
                                value: "\(store.sampleNodeCount)",
                                tintName: "secondary"
                            )
                            DataSourcePill(
                                title: AppLocalization.string("overview.data_source.live_skills", fallback: "Real skills"),
                                value: "\(store.liveSkillCount)",
                                tintName: store.liveSkillCount > 0 ? "green" : "orange"
                            )
                            DataSourcePill(
                                title: AppLocalization.string("overview.data_source.demo_skills", fallback: "Demo skills"),
                                value: "\(store.sampleSkillCount)",
                                tintName: "secondary"
                            )
                        }

                        if store.liveNodeCount == 0 {
                            Button {
                                store.prepareNodeConnection()
                            } label: {
                                Label(AppLocalization.string("overview.data_source.connect", fallback: "Connect a real node"), systemImage: "server.rack")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                detailCard(AppLocalization.string("overview.day_one.title", fallback: "Use it today"), systemImage: "map") {
                    Text(AppLocalization.string(
                        "overview.day_one.note",
                        fallback: "Treat this app as your local EvoMap control room. It does not replace EvoMap's hosted service and it does not require your own server for normal use."
                    ))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        ForEach(dayOneSteps) { step in
                            DayOneStepRow(step: step) {
                                store.setSection(step.targetSection)
                            }
                        }
                    }
                }

                detailCard(AppLocalization.string("overview.runtime.title", fallback: "What runs where"), systemImage: "desktopcomputer") {
                    LabeledContent(
                        AppLocalization.string("overview.runtime.local.title", fallback: "This Mac"),
                        value: AppLocalization.string("overview.runtime.local.value", fallback: "Operator UI, Keychain storage, local drafts")
                    )
                    LabeledContent(
                        AppLocalization.string("overview.runtime.evomap.title", fallback: "EvoMap"),
                        value: AppLocalization.string("overview.runtime.evomap.value", fallback: "Hosted A2A APIs, account credits, Skill Store, marketplace, KG")
                    )
                    Text(AppLocalization.string(
                        "overview.runtime.note",
                        fallback: "You only need a server if you later want a fully autonomous always-on worker. For manual management, this Mac app plus the official EvoMap endpoints is enough."
                    ))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                detailCard(AppLocalization.string("overview.module_guide.title", fallback: "Module guide"), systemImage: "square.grid.2x2") {
                    Text(AppLocalization.string(
                        "overview.module_guide.note",
                        fallback: "Use this as the map for the left sidebar. The normal path is Nodes -> Credits -> Skills -> Services -> Orders; Graph and Activity can wait."
                    ))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        ForEach(moduleGuideItems) { item in
                            ModuleGuideRow(item: item) {
                                store.setSection(item.section)
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(store.overviewMetrics) { metric in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(metric.title, systemImage: metric.systemImage)
                                .font(.headline)
                            Text(metric.value)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(metric.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.string("overview.section.build", fallback: "Build"))
                        .font(.headline)
                    Text(AppLocalization.string(
                        "overview.build.version",
                        fallback: "Version %@ (build %@)",
                        AppBuildMetadata.version,
                        AppBuildMetadata.build
                    ))
                        .font(.body.monospaced())
                    Text(AppLocalization.string(
                        "overview.build.updated",
                        fallback: "Updated %@",
                        AppBuildMetadata.updatedAt
                    ))
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct DataSourcePill: View {
    let title: String
    let value: String
    let tintName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Text(value)
                    .font(.title2.weight(.bold))
                Spacer()
                BadgeLabel(text: badgeText, tintName: tintName)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var badgeText: String {
        switch tintName {
        case "green":
            return AppLocalization.string("overview.data_source.badge_live", fallback: "Live")
        case "orange":
            return AppLocalization.string("overview.data_source.badge_missing", fallback: "Missing")
        default:
            return AppLocalization.string("overview.data_source.badge_demo", fallback: "Demo")
        }
    }
}

private struct ModuleGuideItem: Identifiable {
    let section: ConsoleSection
    let purpose: String
    let useWhen: String

    var id: String { section.rawValue }
}

private struct ModuleGuideRow: View {
    let item: ModuleGuideItem
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.section.systemImage)
                .font(.title3)
                .foregroundStyle(item.section.isAvailableInV1 ? Color.accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.section.title)
                        .font(.headline)
                    if let badgeTitle = item.section.badgeTitle {
                        BadgeLabel(text: badgeTitle, tintName: "secondary")
                    }
                }
                Text(item.purpose)
                    .foregroundStyle(.secondary)
                Text(AppLocalization.string("overview.module.when_prefix", fallback: "When to use: %@", item.useWhen))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            Button(AppLocalization.string("overview.day_one.open", fallback: "Open")) {
                onOpen()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DayOneStep: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let targetSection: ConsoleSection
}

private struct DayOneStepRow: View {
    let step: DayOneStep
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                Text(step.detail)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(AppLocalization.string("overview.day_one.open", fallback: "Open")) {
                onOpen()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NodesTableView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        Table(store.filteredNodes, selection: $store.selectedNodeID) {
            TableColumn(AppLocalization.string("node.column.node", fallback: "Node")) { node in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(AppLocalization.phrase(node.name))
                            .fontWeight(.semibold)
                        if node.isSampleData {
                            BadgeLabel(
                                text: AppLocalization.string("overview.data_source.badge_demo", fallback: "Demo"),
                                tintName: "secondary"
                            )
                        }
                    }
                    Text(node.senderID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 190, ideal: 220)

            TableColumn(AppLocalization.string("node.column.claim", fallback: "Claim")) { node in
                BadgeLabel(text: node.claimState.title, tintName: node.claimState.tintName)
            }
            .width(90)

            TableColumn(AppLocalization.string("node.column.heartbeat", fallback: "Heartbeat")) { node in
                BadgeLabel(text: node.heartbeat.title, tintName: node.heartbeat.tintName)
            }
            .width(90)

            TableColumn(AppLocalization.string("node.column.queue", fallback: "Queue")) { node in
                Text("\(node.dispatchCount)")
                    .foregroundStyle(node.dispatchCount > 0 ? .primary : .secondary)
            }
            .width(64)

            TableColumn(AppLocalization.string("node.column.events", fallback: "Events")) { node in
                Text("\(node.pendingEventCount)")
                    .foregroundStyle(node.pendingEventCount > 0 ? .primary : .secondary)
            }
            .width(64)

            TableColumn(AppLocalization.string("node.column.environment", fallback: "Environment")) { node in
                Text(node.environment.title)
            }
            .width(110)

            TableColumn(AppLocalization.string("node.column.model", fallback: "Model")) { node in
                Text(node.modelName)
            }
            .width(min: 120, ideal: 150)

            TableColumn(AppLocalization.string("node.column.last_seen", fallback: "Last Seen")) { node in
                Text(node.lastSeen.formatted(.relative(presentation: .named)))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct NodeDetailView: View {
    @ObservedObject var store: ConsoleStore
    @State private var isShowingForgetNodeConfirmation = false

    let node: NodeRecord?

    var body: some View {
        if let node {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(node)
                    claimPriorityCard(node)
                    nodeRecoveryCard(node)

                    detailCard(AppLocalization.string("node.card.connection", fallback: "Connection"), systemImage: "antenna.radiowaves.left.and.right") {
                        LabeledContent(AppLocalization.string("node.field.sender_id", fallback: "Sender ID"), value: node.senderID)
                        LabeledContent(AppLocalization.string("node.field.api_base_url", fallback: "API Base URL"), value: node.apiBaseURL)
                        LabeledContent(AppLocalization.string("node.field.environment", fallback: "Environment"), value: node.environment.title)
                        LabeledContent(AppLocalization.string("node.field.model", fallback: "Model"), value: node.modelName)
                        LabeledContent(AppLocalization.string("node.field.genes", fallback: "Genes"), value: "\(node.geneCount)")
                        LabeledContent(AppLocalization.string("node.field.capsules", fallback: "Capsules"), value: "\(node.capsuleCount)")
                        LabeledContent(AppLocalization.string("node.field.workers", fallback: "Workers"), value: "\(node.onlineWorkers)")
                        if let heartbeatEndpoint = node.heartbeatEndpoint {
                            LabeledContent(AppLocalization.string("node.field.heartbeat_endpoint", fallback: "Heartbeat endpoint"), value: heartbeatEndpoint)
                        }
                        if let cadence = node.recommendedHeartbeatIntervalMS {
                            LabeledContent(AppLocalization.string("node.field.recommended_cadence", fallback: "Recommended cadence"), value: heartbeatCadenceLabel(milliseconds: cadence))
                        }
                    }

                    detailCard(AppLocalization.string("node.card.health", fallback: "Health"), systemImage: "heart.text.square") {
                        HStack {
                            BadgeLabel(text: node.heartbeat.title, tintName: node.heartbeat.tintName)
                        }
                        LabeledContent(AppLocalization.string("node.field.last_heartbeat", fallback: "Last heartbeat"), value: node.lastSeen.formatted(date: .abbreviated, time: .shortened))
                        if let nextHeartbeatAt = node.heartbeatSnapshot?.nextHeartbeatAt {
                            LabeledContent(AppLocalization.string("node.field.next_heartbeat", fallback: "Next heartbeat"), value: nextHeartbeatAt.formatted(.relative(presentation: .named)))
                        }
                LabeledContent(AppLocalization.string("node.field.credit_balance", fallback: "Credit balance"), value: "\(node.creditBalance)")
                        if let reputationScore = node.reputationScore {
                            LabeledContent(AppLocalization.string("node.field.reputation", fallback: "Reputation"), value: reputationScore.formatted(.number.precision(.fractionLength(0))))
                        }
                        LabeledContent(AppLocalization.string("node.field.survival_status", fallback: "Survival status"), value: node.survivalStatus ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.string("node.field.node_secret", fallback: "Node secret"), value: node.nodeSecretStored ? AppLocalization.string("common.stored_in_keychain", fallback: "Stored in Keychain") : AppLocalization.string("common.not_stored", fallback: "Not stored"))
                        LabeledContent(AppLocalization.string("node.field.dispatch_queue", fallback: "Dispatch queue"), value: "\(node.dispatchCount)")
                        LabeledContent(AppLocalization.string("node.field.pending_events", fallback: "Pending events"), value: "\(node.pendingEventCount)")
                        LabeledContent(AppLocalization.string("node.field.peers", fallback: "Peers"), value: "\(node.peerCount)")
                    }

                    if let skillStore = node.skillStoreStatus {
                        detailCard(AppLocalization.string("section.skills", fallback: "Skills"), systemImage: "sparkles.rectangle.stack") {
                            LabeledContent(AppLocalization.string("skill_store.field.eligible", fallback: "Eligible"), value: AppLocalization.yesNo(skillStore.eligible))
                            LabeledContent(AppLocalization.string("skill_store.field.published_skills", fallback: "Published skills"), value: "\(skillStore.publishedSkillCount)")
                            LabeledContent(AppLocalization.string("skill_store.field.publish_endpoint", fallback: "Publish endpoint"), value: skillStore.publishEndpoint ?? AppLocalization.unknown)
                            if let hint = skillStore.hint {
                                Text(AppLocalization.phrase(hint))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let snapshot = node.heartbeatSnapshot,
                       snapshot.availableTasks.isEmpty == false || snapshot.availableWork.isEmpty == false || snapshot.overdueTasks.isEmpty == false {
                        detailCard(AppLocalization.string("node.card.task_queue", fallback: "Task queue"), systemImage: "shippingbox") {
                            if snapshot.availableTasks.isEmpty == false {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.available_tasks", fallback: "Available tasks"))
                                        .font(.headline)
                                    ForEach(snapshot.availableTasks) { task in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(AppLocalization.phrase(task.title))
                                                .font(.body.weight(.semibold))
                                            if let summary = task.summary {
                                                Text(AppLocalization.phrase(summary))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(taskMetaLine(for: task))
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            if snapshot.availableWork.isEmpty == false {
                                Divider()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.available_work", fallback: "Available work"))
                                        .font(.headline)
                                    ForEach(snapshot.availableWork) { task in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(AppLocalization.phrase(task.title))
                                                .font(.body.weight(.semibold))
                                            if let summary = task.summary {
                                                Text(AppLocalization.phrase(summary))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(taskMetaLine(for: task))
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            if snapshot.overdueTasks.isEmpty == false {
                                Divider()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.overdue_commitments", fallback: "Overdue commitments"))
                                        .font(.headline)
                                    ForEach(snapshot.overdueTasks) { task in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(AppLocalization.phrase(task.title))
                                                .font(.body.weight(.semibold))
                                            Text(overdueMetaLine(for: task))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }

                    if let snapshot = node.heartbeatSnapshot,
                       snapshot.pendingEvents.isEmpty == false || snapshot.peers.isEmpty == false {
                        detailCard(AppLocalization.string("node.card.live_signals", fallback: "Live signals"), systemImage: "dot.radiowaves.left.and.right") {
                            if snapshot.pendingEvents.isEmpty == false {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.pending_events", fallback: "Pending events"))
                                        .font(.headline)
                                    ForEach(snapshot.pendingEvents) { event in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(event.type)
                                                    .font(.body.weight(.semibold))
                                                if let priority = event.priority {
                                                    Text(AppLocalization.string("node.priority.short", fallback: "P%d", priority))
                                                        .font(.caption2.weight(.bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.quaternary, in: Capsule())
                                                }
                                            }
                                            Text(event.summary)
                                                .foregroundStyle(.secondary)
                                            if let createdAt = event.createdAt {
                                                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            if snapshot.peers.isEmpty == false {
                                Divider()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.peers", fallback: "Peers"))
                                        .font(.headline)
                                    ForEach(snapshot.peers) { peer in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(peer.alias ?? peer.id)
                                                    .font(.body.weight(.semibold))
                                                Spacer()
                                                BadgeLabel(text: peer.online ? AppLocalization.phrase("Online") : AppLocalization.phrase("Offline"), tintName: peer.online ? "green" : "red")
                                            }
                                            Text(peerMetaLine(for: peer))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }

                    if let accountability = node.heartbeatSnapshot?.accountability {
                        detailCard(AppLocalization.string("node.card.accountability", fallback: "Accountability"), systemImage: "checklist") {
                            LabeledContent(AppLocalization.string("node.field.penalty", fallback: "Penalty"), value: "\(accountability.reputationPenalty)")
                            LabeledContent(AppLocalization.string("node.field.quarantine_strikes", fallback: "Quarantine strikes"), value: "\(accountability.quarantineStrikes)")
                            LabeledContent(
                                AppLocalization.string("node.field.publish_cooldown", fallback: "Publish cooldown"),
                                value: accountability.publishCooldownUntil?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.none
                            )
                            if let recommendation = accountability.recommendation {
                                Text(AppLocalization.phrase(recommendation))
                                    .foregroundStyle(.secondary)
                            }
                            if accountability.topPatterns.isEmpty == false {
                                Divider()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(AppLocalization.string("node.section.error_patterns", fallback: "Error patterns"))
                                        .font(.headline)
                                    ForEach(accountability.topPatterns) { pattern in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(pattern.id)
                                                .font(.body.weight(.semibold))
                                            Text(patternMetaLine(for: pattern))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }

                    detailCard(AppLocalization.string("node.card.notes", fallback: "Notes"), systemImage: "note.text") {
                        Text(AppLocalization.phrase(node.notes))
                            .foregroundStyle(.secondary)
                        if let lastErrorMessage = node.lastErrorMessage {
                            Label(AppLocalization.phrase(lastErrorMessage), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.callout)
                        }
                    }

                    detailCard(AppLocalization.string("node.card.recent_events", fallback: "Recent events"), systemImage: "clock.arrow.circlepath") {
                        ForEach(node.recentEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.localizedTitle)
                                    .font(.headline)
                                Text(event.localizedDetail)
                                    .foregroundStyle(.secondary)
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                            if event.id != node.recentEvents.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(node.name))
        } else {
            ContentUnavailableView(
                AppLocalization.string("node.empty.title", fallback: "Select a node"),
                systemImage: "server.rack",
                description: Text(AppLocalization.string(
                    "node.empty.description",
                    fallback: "Choose a node from the table to inspect auth, heartbeat, and recent events."
                ))
            )
        }
    }

    @ViewBuilder
    private func nodeRecoveryCard(_ node: NodeRecord) -> some View {
        if node.isSampleData == false {
            detailCard(AppLocalization.string("node.card.recovery", fallback: "Recovery and cleanup"), systemImage: "externaldrive.badge.checkmark") {
                Label(
                    node.nodeSecretStored
                        ? AppLocalization.string("node.recovery.secret_present", fallback: "Keychain auth is recoverable")
                        : AppLocalization.string("node.recovery.secret_missing", fallback: "No local node_secret"),
                    systemImage: node.nodeSecretStored ? "key.fill" : "key.slash"
                )
                .font(.headline)
                .foregroundStyle(node.nodeSecretStored ? .green : .orange)

                Text(nodeRecoveryBody(for: node))
                    .foregroundStyle(.secondary)

                if node.claimState != .claimed && node.claimURL?.nonEmpty == nil {
                    Text(AppLocalization.string(
                        "node.recovery.missing_claim_link",
                        fallback: "This recovered node has no stored claim link. Use the same sender ID to refresh /a2a/hello before creating another node."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.refreshSelectedNodeHeartbeat()
                        }
                    } label: {
                        Label(
                            store.isRefreshingNodeHeartbeat
                                ? AppLocalization.string("toolbar.refreshing", fallback: "Refreshing")
                                : AppLocalization.string("node.action.verify_heartbeat", fallback: "Verify heartbeat"),
                            systemImage: "heart.text.square"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isRefreshingNodeHeartbeat || node.nodeSecretStored == false)

                    if node.claimState != .claimed {
                        Button {
                            store.prepareNodeConnection()
                        } label: {
                            Label(AppLocalization.string("node.action.refresh_claim_link", fallback: "Refresh claim link"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        isShowingForgetNodeConfirmation = true
                    } label: {
                        Label(AppLocalization.string("node.action.forget_node", fallback: "Forget node and secret"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .confirmationDialog(
                AppLocalization.string("node.forget.confirm_title", fallback: "Forget this node?"),
                isPresented: $isShowingForgetNodeConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    AppLocalization.string("node.action.forget_node", fallback: "Forget node and secret"),
                    role: .destructive
                ) {
                    store.forgetSelectedNodeAndSecret()
                }
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalization.string(
                    "node.forget.confirm_message",
                    fallback: "This removes the local node record and its Keychain node_secret, so it will not be auto-restored on restart. It does not delete EvoMap server history."
                ))
            }
        }
    }

    private func nodeRecoveryBody(for node: NodeRecord) -> String {
        if node.nodeSecretStored == false {
            return AppLocalization.string(
                "node.recovery.body.no_secret",
                fallback: "This node cannot make authenticated A2A calls from this Mac. Reconnect it or forget it locally."
            )
        }

        if node.heartbeat == .healthy {
            return AppLocalization.string(
                "node.recovery.body.healthy",
                fallback: "The latest heartbeat succeeded. Keep this node and continue using it for bounty, skill, and service work."
            )
        }

        return AppLocalization.string(
            "node.recovery.body.keychain",
            fallback: "A node_secret still exists locally, so this node is worth testing before deletion. Verify heartbeat once: success means keep it; auth/not-found errors mean forget it; 429 only means rate limit."
        )
    }

    @ViewBuilder
    private func header(_ node: NodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.phrase(node.name))
                .font(.largeTitle.bold())
            Text(AppLocalization.string(
                "node.header.description",
                fallback: "Use this workspace to confirm handshake readiness, inspect claim details, and verify secure node_secret storage for local-first poll mode."
            ))
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack {
                BadgeLabel(text: node.heartbeat.title, tintName: node.heartbeat.tintName)
            }
        }
    }

    @ViewBuilder
    private func claimPriorityCard(_ node: NodeRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        AppLocalization.string("node.claim.priority_title", fallback: "Step 1: claim this node"),
                        systemImage: node.claimState == .claimed ? "checkmark.seal.fill" : "link.badge.plus"
                    )
                    .font(.title2.bold())

                    Text(node.claimState == .claimed
                        ? AppLocalization.string(
                            "node.claim.priority_claimed_body",
                            fallback: "This node is marked as claimed. The next useful step is heartbeat sync, then bounty or service work."
                        )
                        : AppLocalization.string(
                            "node.claim.priority_pending_body",
                            fallback: "Claim is the first gate. Finish it before heartbeat, bounty tasks, or paid service work."
                        )
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()
                BadgeLabel(text: node.claimState.title, tintName: node.claimState.tintName)
            }

            if node.isSampleData {
                Text(AppLocalization.string(
                    "node.claim.demo_warning",
                    fallback: "This is seeded demo data. Its claim code is intentionally not valid. Use Connect Node to request a fresh claim URL from EvoMap."
                ))
                .foregroundStyle(.secondary)
            } else if node.claimState == .claimed {
                Label(
                    AppLocalization.string("node.claim.complete_title", fallback: "Claim complete"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.green)
            } else {
                if let claimCode = node.claimCode?.nonEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.string("node.field.claim_code", fallback: "Claim code"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(claimCode)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .textSelection(.enabled)
                    }
                }

                HStack(spacing: 10) {
                    if let claimURL = node.claimURL?.nonEmpty, let url = URL(string: claimURL) {
                        Link(destination: url) {
                            Label(AppLocalization.string("node.action.open_claim_url", fallback: "Open Claim URL"), systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text(AppLocalization.string(
                            "node.claim.missing_link_note",
                            fallback: "No active claim link is stored locally. Run Connect Node again only if EvoMap rejected the latest code."
                        ))
                        .foregroundStyle(.secondary)
                    }

                    Button {
                        store.markSelectedNodeClaimed()
                    } label: {
                        Label(AppLocalization.string("node.action.mark_claimed", fallback: "I completed the browser claim"), systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.bordered)
                }

                Text(AppLocalization.string(
                    "node.claim.expiry_note",
                    fallback: "Claim links can expire. If EvoMap says the code is invalid, run Connect Node again and use the newest claim URL."
                ))
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    node.claimState == .claimed ? Color.green.opacity(0.12) : Color.orange.opacity(0.18),
                    Color.yellow.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(node.claimState == .claimed ? Color.green.opacity(0.28) : Color.orange.opacity(0.38), lineWidth: 1)
        }
    }

    private func taskMetaLine(for task: NodeTaskPreview) -> String {
        [
            task.domain,
            task.kind,
            task.rewardCredits.map { AppLocalization.string("credits.unit.count", fallback: "%d credits", $0) },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func overdueMetaLine(for task: NodeOverdueTask) -> String {
        [
            task.commitmentDeadline.map {
                AppLocalization.string(
                    "node.meta.deadline",
                    fallback: "Deadline %@",
                    $0.formatted(date: .abbreviated, time: .shortened)
                )
            },
            task.overdueMinutes.map { AppLocalization.string("node.meta.minutes_overdue", fallback: "%d min overdue", $0) },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func peerMetaLine(for peer: NodePeerPreview) -> String {
        [
            peer.reputation.map {
                AppLocalization.string(
                    "node.meta.reputation",
                    fallback: "Reputation %@",
                    $0.formatted(.number.precision(.fractionLength(2)))
                )
            },
            peer.workload.map { AppLocalization.string("node.meta.workload", fallback: "Workload %d", $0) },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func patternMetaLine(for pattern: NodeErrorPatternPreview) -> String {
        [
            AppLocalization.string("node.meta.count", fallback: "Count %d", pattern.count),
            pattern.escalation,
            pattern.reason,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func heartbeatCadenceLabel(milliseconds: Int) -> String {
        let seconds = max(milliseconds / 1000, 1)
        if seconds < 60 {
            return AppLocalization.string("time.every_seconds", fallback: "Every %ds", seconds)
        }
        return AppLocalization.string("time.every_minutes", fallback: "Every %dm", max(seconds / 60, 1))
    }
}

private struct CreditsListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.string("credits.section.sprint", fallback: "Sprint")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(AppLocalization.string("credits.fast_path.title", fallback: "Credits path"), systemImage: "bolt.circle")
                        .font(.headline)
                    Text(AppLocalization.phrase(store.creditSprintStatusLine))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section(AppLocalization.string("credits.section.open", fallback: "Open")) {
                Link(destination: store.evoMapBountiesURL) {
                    Label(AppLocalization.string("credits.open.bounty_board", fallback: "Bounty board"), systemImage: "target")
                }

                Link(destination: store.evoMapPricingURL) {
                    Label(AppLocalization.string("credits.open.pricing_rules", fallback: "Pricing and earning rules"), systemImage: "creditcard")
                }
            }
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct CreditsDetailView: View {
    @ObservedObject var store: ConsoleStore

    private var serviceTemplates: [CreditServiceTemplate] {
        [
        CreditServiceTemplate(
            title: AppLocalization.string("credits.service.vocabulary.title", fallback: "JLPT Vocabulary Explainer"),
            price: AppLocalization.string("credits.service.vocabulary.price", fallback: "15-25 cr"),
            detail: AppLocalization.string(
                "credits.service.vocabulary.detail",
                fallback: "Word meaning, nuance, example sentence, pitch/accent notes, and learner mistakes."
            )
        ),
        CreditServiceTemplate(
            title: AppLocalization.string("credits.service.grammar.title", fallback: "Japanese Grammar Corrector"),
            price: AppLocalization.string("credits.service.grammar.price", fallback: "20-40 cr"),
            detail: AppLocalization.string(
                "credits.service.grammar.detail",
                fallback: "Corrects learner sentences and explains the rule in Chinese, English, or Japanese."
            )
        ),
        CreditServiceTemplate(
            title: AppLocalization.string("credits.service.quiz.title", fallback: "Quiz Generator"),
            price: AppLocalization.string("credits.service.quiz.price", fallback: "15-30 cr"),
            detail: AppLocalization.string(
                "credits.service.quiz.detail",
                fallback: "Turns vocabulary or grammar lists into N5-N1 practice questions with answer keys."
            )
        ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppLocalization.string("credits.detail.title", fallback: "Credits"))
                    .font(.largeTitle.bold())
                Text(AppLocalization.string(
                    "credits.detail.body",
                    fallback: "This page starts after the Node page. Use it only to read balances, work bounty tasks, draft paid Japanese-learning services, and decide when to upgrade."
                ))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                detailCard(AppLocalization.string("credits.card.balance_target", fallback: "Balance and target"), systemImage: "gauge.with.dots.needle.50percent") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        CreditMetricBlock(
                            title: AppLocalization.string("credits.label.official_account_balance", fallback: "Official account balance"),
                            value: store.officialAccountBalanceDisplayValue,
                            detail: store.officialAccountBalanceDetailLine
                        )
                        CreditMetricBlock(
                            title: AppLocalization.string("credits.label.node_returned_balance", fallback: "Node-reported balance"),
                            value: AppLocalization.string("credits.unit.count", fallback: "%d credits", store.totalNodeCreditBalance),
                            detail: AppLocalization.string("credits.number.node_balance.value", fallback: "Only real connected nodes, never sample data")
                        )
                        CreditMetricBlock(
                            title: AppLocalization.string("credits.label.public_premium_target", fallback: "Public Premium target"),
                            value: AppLocalization.string("credits.unit.count", fallback: "%d credits", store.premiumCreditTarget),
                            detail: AppLocalization.string("credits.number.premium_target.value", fallback: "A goal line, not your current credits")
                        )
                        CreditMetricBlock(
                            title: AppLocalization.string("credits.label.remaining_gap", fallback: "Remaining gap"),
                            value: store.premiumCreditGapDisplayValue,
                            detail: AppLocalization.string("credits.balance.gap_note", fallback: "This is a planning gap. EvoMap remains the source of truth.")
                        )
                    }

                    ProgressView(value: store.creditProgressFraction)

                    HStack {
                        Button {
                            Task {
                                await store.refreshOfficialAccountBalance()
                            }
                        } label: {
                            Label(AppLocalization.string("credits.action.refresh_official_balance", fallback: "Refresh official balance"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isLoadingAccountBalance)

                        if store.isLoadingAccountBalance {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let message = store.accountBalanceMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    if let error = store.accountBalanceErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                detailCard(AppLocalization.string("credits.card.today_queue", fallback: "Credits workflow"), systemImage: "checklist") {
                    Text(AppLocalization.string(
                        "credits.workflow.note",
                        fallback: "No node setup actions live here. If a prerequisite is missing, finish it in Nodes first, then return here."
                    ))
                    .foregroundStyle(.secondary)

                    ForEach(store.creditSprintSteps) { step in
                        CreditSprintStepRow(step: step)
                    }
                }

                detailCard(AppLocalization.string("credits.card.bounty_workbench", fallback: "Bounty task workbench"), systemImage: "target") {
                    Text(AppLocalization.string(
                        "credits.bounty.moved_note",
                        fallback: "Bounty volume is high, so tracking moved into the dedicated Bounties page. Keep Credits as the balance and workflow checkpoint."
                    ))
                    .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        CreditMetricBlock(
                            title: AppLocalization.string("bounties.metric.loaded", fallback: "Loaded bounties"),
                            value: "\(store.bountyTasks.count)",
                            detail: store.bountyTaskLoadedCountLine
                        )
                        CreditMetricBlock(
                            title: AppLocalization.string("bounties.metric.following", fallback: "Following"),
                            value: "\(store.followedBountyTaskIDs.count)",
                            detail: AppLocalization.string("bounties.metric.following.detail", fallback: "Local watchlist saved on this Mac")
                        )
                    }

                    HStack {
                        Button {
                            store.setSection(.bounties)
                        } label: {
                            Label(AppLocalization.string("credits.action.open_bounty_tracker", fallback: "Open Bounty Tracker"), systemImage: "target")
                        }
                        .buttonStyle(.borderedProminent)

                        Link(destination: store.evoMapBountiesURL) {
                            Label(AppLocalization.string("credits.open.bounty_board", fallback: "Bounty board"), systemImage: "safari")
                        }
                    }
                }

                detailCard(AppLocalization.string("credits.card.japanese_service_offers", fallback: "Japanese service offers"), systemImage: "character.book.closed") {
                    ForEach(serviceTemplates) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(template.title)
                                    .font(.headline)
                                Spacer()
                                BadgeLabel(text: template.price, tintName: "blue")
                            }
                            Text(template.detail)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    Button {
                        store.prepareJapaneseLearningServiceComposer()
                    } label: {
                        Label(AppLocalization.string("credits.action.draft_japanese_service", fallback: "Draft Japanese Service"), systemImage: "shippingbox")
                    }
                    .buttonStyle(.bordered)

                    Text(AppLocalization.string(
                        "credits.service.note",
                        fallback: "Keep the first service narrow. The goal is repeatable paid calls, not a broad demo that is hard to evaluate."
                    ))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                detailCard(AppLocalization.string("credits.card.paid_api_gate", fallback: "Upgrade and API key"), systemImage: "key") {
                    LabeledContent(
                        AppLocalization.string("credits.label.kg_api_key", fallback: "KG API key"),
                        value: ConsoleAppSettings.kgAPIKey.nonEmpty == nil
                            ? AppLocalization.string("common.not_stored", fallback: "Not stored")
                            : AppLocalization.string("common.stored_in_keychain", fallback: "Stored in Keychain")
                    )
                    Link(destination: store.evoMapPricingURL) {
                        Label(AppLocalization.string("credits.open.pricing", fallback: "Open pricing"), systemImage: "creditcard")
                    }
                    Link(destination: store.evoMapAPIKeysURL) {
                        Label(AppLocalization.string("credits.open.api_key_page", fallback: "Open API key page"), systemImage: "key")
                    }
                    Text(AppLocalization.string(
                        "credits.api_gate.note",
                        fallback: "Use API keys after the account reaches Premium or Ultra. A2A node, claim, skill, service, and bounty work should start with node_secret instead."
                    ))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct BountyTasksListView: View {
    @ObservedObject var store: ConsoleStore
    @State private var filter: BountyListFilter = .claimable

    var body: some View {
        List {
            Section {
                BountyAutopilotStatusHeader(store: store)
                    .padding(.vertical, 4)

                Picker("", selection: $filter) {
                    ForEach(BountyListFilter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if filter == .claimable && store.bountyAutopilotCandidates.isEmpty == false {
                Section(AppLocalization.string("bounties.section.top_candidates", fallback: "Top candidates")) {
                    ForEach(Array(store.bountyAutopilotCandidates.prefix(3))) { candidate in
                        Button {
                            store.selectedBountyTaskID = candidate.task.id
                        } label: {
                            BountyAutopilotCandidateRow(candidate: candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(filter.sectionTitle) {
                if filter == .claimable, let blocker = store.bountyTaskPrerequisiteBlocker {
                    Text(blocker).foregroundStyle(.secondary)
                }

                let tasksForFilter = filter.tasks(store: store)
                if tasksForFilter.isEmpty {
                    Text(filter.emptyMessage(store: store))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasksForFilter) { task in
                        bountyTaskButton(task)
                    }
                }

                if (filter == .claimable || filter == .all) && store.hasMoreBountyTasks {
                    Button {
                        Task { await store.loadMoreBountyTasks() }
                    } label: {
                        Label(
                            store.isLoadingBountyTasks
                                ? AppLocalization.string("bounties.action.loading_more", fallback: "Loading more")
                                : AppLocalization.string("bounties.action.load_more", fallback: "Load more"),
                            systemImage: "plus.circle"
                        )
                    }
                    .disabled(store.isLoadingBountyTasks)
                }
            }

            Section(AppLocalization.string("bounties.section.tracker", fallback: "Tracker")) {
                Toggle(
                    AppLocalization.string("bounties.action.show_all_loaded", fallback: "Show all loaded tasks"),
                    isOn: $store.bountyShowsAllLoadedTasks
                )
                .toggleStyle(.switch)

                Button {
                    Task { await store.refreshBountyTasks() }
                } label: {
                    Label(AppLocalization.string("credits.action.refresh_bounties", fallback: "Refresh bounties"), systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoadingBountyTasks || store.selectedOrFirstCreditNode == nil)

                Button {
                    Task { await store.refreshClaimedBountyTasks() }
                } label: {
                    Label(
                        store.isLoadingClaimedBountyTasks
                            ? AppLocalization.string("bounties.action.refreshing_claimed", fallback: "Refreshing claimed tasks")
                            : AppLocalization.string("bounties.action.refresh_claimed", fallback: "Refresh my claimed tasks"),
                        systemImage: "tray.and.arrow.down"
                    )
                }
                .disabled(store.isLoadingClaimedBountyTasks || store.selectedOrFirstCreditNode == nil)

                Button {
                    Task { await store.importOpenClawBountyHistory() }
                } label: {
                    Label(
                        store.isImportingBountyAutopilotHistory
                            ? AppLocalization.string("bounties.autopilot.importing", fallback: "Importing OpenClaw history")
                            : AppLocalization.string("bounties.autopilot.import", fallback: "Import OpenClaw history"),
                        systemImage: "tray.and.arrow.down.fill"
                    )
                }
                .disabled(store.isImportingBountyAutopilotHistory)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.bountyTaskLoadedCountLine)
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(store.claimedBountyTaskCountLine)
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(AppLocalization.string("bounties.list.sort_hint", fallback: "Sorted by claimable tasks first, then higher credits."))
                        .font(.footnote).foregroundStyle(.secondary)
                    if store.bountyShowsAllLoadedTasks == false {
                        Text(AppLocalization.string(
                            "bounties.list.default_filter_note",
                            fallback: "Default view shows only claimable tasks for the selected node. Hidden: %d.",
                            store.hiddenBountyTaskCount
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let error = store.bountyTaskErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(AppLocalization.string("section.bounties", fallback: "Bounties"))
        .navigationSplitViewColumnWidth(min: 360, ideal: 430, max: 540)
        .task {
            if store.bountyTasks.isEmpty {
                await store.refreshBountyTasks()
            } else if store.claimedBountyTasks.isEmpty {
                await store.refreshClaimedBountyTasks()
            }
        }
    }

    private func bountyTaskButton(_ task: EvoMapBountyTask) -> some View {
        Button {
            store.selectedBountyTaskID = task.id
        } label: {
            BountyTaskRow(
                task: task,
                isSelected: store.selectedBountyTaskID == task.id,
                isClaiming: store.activeBountyClaimTaskID == task.id,
                isFollowed: store.isFollowingBountyTask(task),
                isClaimed: store.isClaimedBountyTask(task),
                submissionStatus: store.claimedSubmissionStatus(for: task),
                requiredReputation: store.bountyRequiredReputation(for: task),
                nodeReputation: store.selectedNodeReputationScore,
                isOpenForClaim: store.bountyTaskCanAttemptClaim(task)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BountyAutopilotCandidateRow: View {
    let candidate: BountyAutopilotCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppLocalization.bountyText(candidate.task.title))
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                BadgeLabel(
                    text: AppLocalization.string("bounties.autopilot.score", fallback: "Score %d", candidate.score),
                    tintName: candidate.score > 70 ? "green" : "blue"
                )
            }

            HStack(spacing: 8) {
                if let credits = candidate.task.displayCredits {
                    BadgeLabel(text: AppLocalization.string("credits.unit.count", fallback: "%d credits", credits), tintName: "green")
                }
                if let status = AppLocalization.bountyTerm(candidate.task.status) ?? candidate.task.status {
                    BadgeLabel(text: status, tintName: "secondary")
                }
            }

            if candidate.reasons.isEmpty == false {
                Text(candidate.reasons.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if candidate.risks.isEmpty == false {
                Text(candidate.risks.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BountyAutopilotRunRow: View {
    let run: BountyAutopilotRun
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                BadgeLabel(text: run.status.title, tintName: run.status.tintName)
            }

            HStack(spacing: 8) {
                if let reward = run.rewardCredits {
                    BadgeLabel(text: AppLocalization.string("credits.unit.count", fallback: "%d credits", reward), tintName: "green")
                }
                Text(run.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum BountyDetailTab: String, CaseIterable, Identifiable {
    case task, execute, audit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:
            return AppLocalization.string("bounties.detail.tab.task", fallback: "Task")
        case .execute:
            return AppLocalization.string("bounties.detail.tab.execute", fallback: "Execute")
        case .audit:
            return AppLocalization.string("bounties.detail.tab.audit", fallback: "Audit")
        }
    }

    var systemImage: String {
        switch self {
        case .task:
            return "doc.text"
        case .execute:
            return "bolt.fill"
        case .audit:
            return "list.clipboard"
        }
    }
}

private enum BountyListFilter: String, CaseIterable, Identifiable {
    case claimable, following, claimed, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claimable:
            return AppLocalization.string("bounties.list.filter.claimable", fallback: "Claimable")
        case .following:
            return AppLocalization.string("bounties.list.filter.following", fallback: "Following")
        case .claimed:
            return AppLocalization.string("bounties.list.filter.claimed", fallback: "Claimed")
        case .all:
            return AppLocalization.string("bounties.list.filter.all", fallback: "All loaded")
        }
    }

    var sectionTitle: String {
        switch self {
        case .claimable:
            return AppLocalization.string("bounties.section.claimable", fallback: "Claimable for selected node")
        case .following:
            return AppLocalization.string("bounties.section.following", fallback: "Following")
        case .claimed:
            return AppLocalization.string("bounties.section.claimed", fallback: "My claimed tasks")
        case .all:
            return AppLocalization.string("bounties.section.all", fallback: "All loaded tasks")
        }
    }

    @MainActor
    func tasks(store: ConsoleStore) -> [EvoMapBountyTask] {
        switch self {
        case .claimable:
            return store.visibleBountyTasks
        case .following:
            return store.followedBountyTasks
        case .claimed:
            return store.claimedBountyDisplayTasks
        case .all:
            return store.bountyTasks
        }
    }

    func emptyMessage(store: ConsoleStore) -> String {
        switch self {
        case .claimable:
            return AppLocalization.string("bounties.empty.no_claimable", fallback: "No claimable tasks for the selected node in the loaded page. Show all loaded tasks or load more.")
        case .following:
            return AppLocalization.string("bounties.empty.no_following", fallback: "Not following any bounty yet. Bookmark tasks from Claimable or All loaded.")
        case .claimed:
            return AppLocalization.string("bounties.empty.no_claimed", fallback: "No claimed bounties yet. Refresh after the node has claimed work.")
        case .all:
            return AppLocalization.string("credits.bounty.empty", fallback: "No bounty tasks loaded yet. Refresh after the node is connected and claimed.")
        }
    }
}

private struct BountyAutopilotStatusHeader: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    AppLocalization.string("bounties.autopilot.title", fallback: "Autopilot Cockpit"),
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )
                .font(.subheadline.weight(.semibold))
                Spacer()
                if let run = store.latestBountyAutopilotRun {
                    BadgeLabel(text: run.status.title, tintName: run.status.tintName)
                }
            }

            Text(store.bountyAutopilotStatusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if store.isRunningBountyAutopilot {
                    Button(role: .destructive) {
                        store.cancelBountyAutopilot()
                    } label: {
                        Label(
                            store.isCancellingBountyAutopilot
                                ? AppLocalization.string("bounties.autopilot.cancelling_short", fallback: "Cancelling…")
                                : AppLocalization.string("bounties.autopilot.cancel", fallback: "Cancel run"),
                            systemImage: "stop.fill"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isCancellingBountyAutopilot)
                } else {
                    Button {
                        store.startBountyAutopilot()
                    } label: {
                        Label(
                            AppLocalization.string("bounties.autopilot.start", fallback: "Run next bounty automatically"),
                            systemImage: "play.fill"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(store.selectedOrFirstCreditNode == nil)
                }

                Toggle(
                    AppLocalization.string("bounties.autopilot.auto_submit_short", fallback: "Auto-submit"),
                    isOn: $store.bountyAutopilotAutoSubmit
                )
                .toggleStyle(.switch)
                .controlSize(.small)

                Toggle(
                    AppLocalization.string("bounties.autopilot.use_native_short", fallback: "Native engine"),
                    isOn: $store.bountyAutopilotUseNativeEngine
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Text(
                store.bountyAutopilotUseNativeEngine
                    ? AppLocalization.string(
                        "bounties.autopilot.use_native.note",
                        fallback: "Native engine: Console drafts the answer locally with template matching. No OpenClaw process is launched."
                    )
                    : AppLocalization.string(
                        "bounties.autopilot.use_native.note_off",
                        fallback: "Legacy mode: Autopilot shells out to OpenClaw to draft the answer."
                    )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if store.bountyAutopilotAutoSubmit {
                Text(AppLocalization.string(
                    "bounties.autopilot.auto_submit.warning",
                    fallback: "Risky: the app will publish and complete immediately after the executor returns an answer."
                ))
                .font(.caption2)
                .foregroundStyle(.orange)
            }

            if let message = store.bountyAutopilotMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            if let error = store.bountyAutopilotErrorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct BountyTaskDetailView: View {
    @ObservedObject var store: ConsoleStore
    @State private var detailTab: BountyDetailTab = .task

    var body: some View {
        if let task = store.selectedBountyTask {
            VStack(spacing: 0) {
                Picker("", selection: $detailTab) {
                    ForEach(BountyDetailTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 24)
                .padding(.top, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleHeader(for: task)

                        switch detailTab {
                        case .task:
                            actionsCard(for: task)
                            taskContextCard(for: task)
                        case .execute:
                            executionHandoffPanel()
                            patchCourierAdvancedCard()
                            submissionEditorsCard()
                        case .audit:
                            autopilotAuditCardOrEmpty()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .navigationTitle(AppLocalization.string("section.bounties", fallback: "Bounties"))
        } else if let run = store.selectedBountyAutopilotRun {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(AppLocalization.string("bounties.autopilot.history.title", fallback: "Historical Autopilot Run"))
                        .font(.largeTitle.bold())
                    Text(AppLocalization.string(
                        "bounties.autopilot.history.note",
                        fallback: "This run was imported from OpenClaw history. It may not exist in the currently loaded public bounty page, but the local audit record is preserved here."
                    ))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                    BountyAutopilotRunAuditCard(run: run)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.string("section.bounties", fallback: "Bounties"))
        } else {
            ContentUnavailableView(
                AppLocalization.string("bounties.empty.title", fallback: "Select a bounty"),
                systemImage: "target",
                description: Text(AppLocalization.string("bounties.empty.description", fallback: "Refresh the bounty list and choose one task to inspect, follow, or claim."))
            )
        }
    }

    private func taskContextCard(for task: EvoMapBountyTask) -> some View {
        detailCard(AppLocalization.string("bounties.card.context", fallback: "Task context"), systemImage: "doc.text.magnifyingglass") {
            if let body = store.bountyBody(for: task)?.nonEmpty {
                Text(AppLocalization.bountyText(body))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(AppLocalization.string("bounties.no_summary", fallback: "No summary returned by the public bounty API."))
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup(AppLocalization.string("bounties.disclosure.task_details", fallback: "Show task details, IDs, and flow")) {
                VStack(alignment: .leading, spacing: 8) {
                    if let body = store.bountyBody(for: task)?.nonEmpty {
                        Text(AppLocalization.bountyText(body))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if AppLocalization.hasBountyTranslation(for: body) {
                            Text(AppLocalization.string("bounties.raw_summary", fallback: "Original summary: %@", body))
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    } else {
                        Text(AppLocalization.string("bounties.no_summary", fallback: "No summary returned by the public bounty API."))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text(AppLocalization.string("bounties.field.task_id", fallback: "Task ID"))
                                .foregroundStyle(.secondary)
                            Text(task.claimableTaskID ?? AppLocalization.string("bounties.value.resolve_before_claim", fallback: "Resolve before claim"))
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text(AppLocalization.string("bounties.field.bounty_id", fallback: "Bounty ID"))
                                .foregroundStyle(.secondary)
                            Text(task.bountyID ?? AppLocalization.unknown)
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text(AppLocalization.string("bounties.field.question_id", fallback: "Question ID"))
                                .foregroundStyle(.secondary)
                            Text(task.questionID ?? AppLocalization.unknown)
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text(AppLocalization.string("bounties.field.deadline", fallback: "Deadline"))
                                .foregroundStyle(.secondary)
                            Text(task.deadline ?? AppLocalization.unknown)
                        }
                        GridRow {
                            Text(AppLocalization.string("bounties.field.required_reputation", fallback: "Required reputation"))
                                .foregroundStyle(.secondary)
                            Text(store.bountyRequiredReputation(for: task).map { ">= \($0)" } ?? AppLocalization.unknown)
                        }
                        GridRow {
                            Text(AppLocalization.string("bounties.field.node_reputation", fallback: "Node reputation"))
                                .foregroundStyle(.secondary)
                            Text(store.selectedNodeReputationScore.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? AppLocalization.unknown)
                        }
                    }
                    .font(.footnote)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        BountyFollowStepRow(
                            systemImage: "bookmark",
                            title: AppLocalization.string("bounties.follow.step.watch.title", fallback: "1. Follow"),
                            detail: AppLocalization.string("bounties.follow.step.watch.detail", fallback: "Save promising tasks locally so they do not disappear in a large list."),
                            isComplete: store.selectedBountyTaskIsFollowed
                        )
                        BountyFollowStepRow(
                            systemImage: "hand.raised",
                            title: AppLocalization.string("bounties.follow.step.claim.title", fallback: "2. Claim"),
                            detail: AppLocalization.string("bounties.follow.step.claim.detail", fallback: "Resolve task_id from bounty_id, then claim with the selected node_id."),
                            isComplete: store.selectedBountyTaskIsClaimed
                        )
                        BountyFollowStepRow(
                            systemImage: "doc.badge.plus",
                            title: AppLocalization.string("bounties.follow.step.answer.title", fallback: "3. Answer"),
                            detail: AppLocalization.string("bounties.follow.step.answer.detail", fallback: "Prepare a verifiable answer Capsule and complete the task through EvoMap settlement."),
                            isComplete: store.bountyAnswerDraft.publishedAssetID != nil
                        )
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func executionHandoffPanel() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppLocalization.string("bounties.autopilot.selected.title", fallback: "Automatic model execution"))
                    .font(.headline)
                BadgeLabel(text: AppLocalization.string("bounties.autopilot.selected.badge", fallback: "OpenClaw + Skills"), tintName: "green")
                Spacer()
            }

            Text(AppLocalization.string(
                "bounties.autopilot.selected.note",
                fallback: "Run the selected bounty directly through the local model and Skills loop. Console still keeps claim, prompt, raw output, final draft, and submit decision visible."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                BountyFollowStepRow(
                    systemImage: "hand.raised",
                    title: AppLocalization.string("bounties.autopilot.selected.step.claim.title", fallback: "1. Claim if needed"),
                    detail: AppLocalization.string("bounties.autopilot.selected.step.claim.detail", fallback: "Console resolves task_id, uses the selected node, and records the claim state."),
                    isComplete: store.selectedBountyTaskIsClaimed
                )
                BountyFollowStepRow(
                    systemImage: "sparkles",
                    title: AppLocalization.string("bounties.autopilot.selected.step.execute.title", fallback: "2. Run model + Skills"),
                    detail: AppLocalization.string("bounties.autopilot.selected.step.execute.detail", fallback: "OpenClaw receives the locked prompt, calls the configured model and Skills, then returns a final Markdown answer."),
                    isComplete: store.bountyAnswerDraft.answerText.nonEmpty != nil
                )
                BountyFollowStepRow(
                    systemImage: "checkmark.seal",
                    title: AppLocalization.string("bounties.autopilot.selected.step.submit.title", fallback: "3. Review or auto-submit"),
                    detail: AppLocalization.string("bounties.autopilot.selected.step.submit.detail", fallback: "By default the draft stops in Final answer for review; enable auto-submit only when you trust the run."),
                    isComplete: store.bountyAnswerDraft.publishedAssetID != nil
                )
            }

            if store.bountyAutopilotAutoSubmit {
                Label(
                    AppLocalization.string(
                        "bounties.autopilot.auto_submit.indicator",
                        fallback: "Auto-submit is ON · adjust in the cockpit header"
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            HStack {
                if store.isRunningBountyAutopilot {
                    Button(role: .destructive) {
                        store.cancelBountyAutopilot()
                    } label: {
                        Label(
                            store.isCancellingBountyAutopilot
                                ? AppLocalization.string("bounties.autopilot.cancelling_short", fallback: "Cancelling…")
                                : AppLocalization.string("bounties.autopilot.cancel", fallback: "Cancel run"),
                            systemImage: "stop.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isCancellingBountyAutopilot)
                } else {
                    Button {
                        store.runSelectedBountyAutopilot()
                    } label: {
                        Label(
                            AppLocalization.string("bounties.autopilot.selected.start", fallback: "Run selected bounty automatically"),
                            systemImage: "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedOrFirstCreditNode == nil)
                }
            }

            if store.isRunningBountyAutopilot && store.bountyAutopilotLiveOutput.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        AppLocalization.string("bounties.autopilot.live_output.title", fallback: "Live output"),
                        systemImage: "terminal"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    ScrollView {
                        Text(store.bountyAutopilotLiveOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            if store.selectedOrFirstCreditNode == nil {
                Text(AppLocalization.string(
                    "bounties.autopilot.selected.node_hint",
                    fallback: "Connect or select a claimed node first so Console can claim and submit bounty tasks."
                ))
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if let message = store.bountyAutopilotMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
            if let error = store.bountyAutopilotErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            DisclosureGroup(AppLocalization.string("bounties.autopilot.selected.manual_fallback", fallback: "Manual prompt fallback")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(AppLocalization.string(
                        "bounties.autopilot.selected.manual_note",
                        fallback: "Only use this if the automatic run fails or you want to paste the same prompt into Codex or Claude Code yourself."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        store.copySelectedBountyExecutionBrief()
                    } label: {
                        Label(AppLocalization.string("bounties.executor.copy_brief", fallback: "Copy execution brief"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    if let message = store.bountyExecutionMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }

                    Text(store.selectedBountyExecutionBrief)
                        .font(.system(.caption, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textSelection(.enabled)
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    private func titleHeader(for task: EvoMapBountyTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.bountyText(task.title))
                .font(.largeTitle.bold())
            if AppLocalization.hasBountyTranslation(for: task.title) {
                Text(AppLocalization.string("bounties.raw_title", fallback: "Original: %@", task.title))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack {
                if let credits = task.displayCredits {
                    BadgeLabel(text: AppLocalization.string("credits.unit.count", fallback: "%d credits", credits), tintName: "green")
                }
                if store.selectedBountyTaskIsFollowed {
                    BadgeLabel(text: AppLocalization.string("bounties.badge.following", fallback: "Following"), tintName: "blue")
                }
                BadgeLabel(text: AppLocalization.bountyTerm(task.status) ?? AppLocalization.unknown, tintName: "secondary")
            }
        }
    }

    private func actionsCard(for task: EvoMapBountyTask) -> some View {
        detailCard(AppLocalization.string("bounties.card.actions", fallback: "Actions"), systemImage: "hand.point.up.left") {
            if let blocker = store.bountyTaskPrerequisiteBlocker {
                Text(blocker)
                    .foregroundStyle(.secondary)
            } else {
                Text(AppLocalization.string(
                    "bounties.actions.note",
                    fallback: "Follow high-signal tasks first. Claim only when you can answer cleanly; failed claims can still reveal reputation requirements."
                ))
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    store.toggleSelectedBountyTaskFollow()
                } label: {
                    Label(
                        store.selectedBountyTaskIsFollowed
                            ? AppLocalization.string("bounties.action.unfollow", fallback: "Remove follow")
                            : AppLocalization.string("bounties.action.follow", fallback: "Follow task"),
                        systemImage: store.selectedBountyTaskIsFollowed ? "bookmark.slash" : "bookmark"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await store.claimBountyTask(task) }
                } label: {
                    Label(
                        store.selectedBountyTaskIsClaimed
                            ? AppLocalization.string("bounties.action.claimed", fallback: "Claimed")
                            : AppLocalization.string("credits.action.claim_selected_bounty", fallback: "Claim selected bounty"),
                        systemImage: store.selectedBountyTaskIsClaimed ? "checkmark.circle" : "hand.raised"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.selectedBountyTaskIsClaimed || !store.canClaimBountyTask(task))

                Link(destination: store.evoMapBountiesURL) {
                    Label(AppLocalization.string("credits.open.bounty_board", fallback: "Bounty board"), systemImage: "safari")
                }

                Link(destination: store.evoMapReputationDocsURL) {
                    Label(AppLocalization.string("bounties.open.reputation_docs", fallback: "Reputation rules"), systemImage: "book")
                }
            }

            if let contextLine = store.selectedBountyClaimContextLine {
                Label(contextLine, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let eligibilityLine = store.selectedBountyEligibilityLine {
                Label(
                    eligibilityLine,
                    systemImage: store.canSelectedNodeClaimBounty(task) == false ? "exclamationmark.triangle" : "checkmark.shield"
                )
                .font(.footnote)
                .foregroundStyle(store.canSelectedNodeClaimBounty(task) == false ? .orange : .secondary)
            }
            if let message = store.bountyTaskMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
            if let error = store.bountyTaskErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func autopilotAuditCardOrEmpty() -> some View {
        if let run = store.selectedBountyAutopilotRun {
            BountyAutopilotRunAuditCard(run: run)
        } else {
            detailCard(AppLocalization.string("bounties.audit.empty.title", fallback: "Audit trail"), systemImage: "list.clipboard") {
                Text(AppLocalization.string(
                    "bounties.audit.empty.detail",
                    fallback: "No autopilot run is associated with this task yet. Trigger Run selected on the Execute tab to capture an audit trail."
                ))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func patchCourierAdvancedCard() -> some View {
        detailCard(AppLocalization.string("bounties.card.alternate_executors", fallback: "Alternate executors"), systemImage: "envelope.badge") {
            Text(AppLocalization.string(
                "bounties.alternate_executors.note",
                fallback: "Use these only when OpenClaw cannot run locally. Patch Courier hands the task off via mail and writes the answer back when it replies."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)

            DisclosureGroup(AppLocalization.string("bounties.patch_courier.advanced_disclosure", fallback: "Advanced: Patch Courier mail handoff")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(AppLocalization.string("bounties.patch_courier.backend.title", fallback: "Patch Courier backend"))
                            .font(.headline)
                        Spacer()
                        if store.isPatchCourierBackendPolling {
                            Label(AppLocalization.string("bounties.patch_courier.backend.polling", fallback: "Auto checking"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(AppLocalization.string(
                        "bounties.patch_courier.backend.note",
                        fallback: "Silent SMTP sends the claimed task to Patch Courier. IMAP checks replies and writes FINAL_ANSWER_MARKDOWN back into the draft; EvoMap submission stays manual."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Label(store.selectedBountyPatchCourierBackendStatusLine, systemImage: store.patchCourierBackendIsConfigured ? "checkmark.shield" : "gearshape")
                        .font(.footnote)
                        .foregroundStyle(store.patchCourierBackendIsConfigured ? Color.secondary : Color.orange)
                        .textSelection(.enabled)

                    HStack {
                        Button {
                            Task { await store.sendSelectedBountyToPatchCourierBackend() }
                        } label: {
                            Label(
                                store.isSendingPatchCourierBackendTask
                                    ? AppLocalization.string("bounties.patch_courier.backend.sending", fallback: "Sending")
                                    : AppLocalization.string("bounties.patch_courier.backend.send_execute", fallback: "Send silently"),
                                systemImage: "paperplane.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            !store.patchCourierBackendIsConfigured
                                || !store.selectedBountyTaskIsClaimed
                                || store.isSendingPatchCourierBackendTask
                        )

                        Button {
                            Task { await store.checkSelectedBountyPatchCourierBackendInbox() }
                        } label: {
                            Label(
                                store.isCheckingPatchCourierBackendInbox
                                    ? AppLocalization.string("bounties.patch_courier.backend.checking", fallback: "Checking")
                                    : AppLocalization.string("bounties.patch_courier.backend.check_now", fallback: "Check replies"),
                                systemImage: "tray.and.arrow.down"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.patchCourierBackendIsConfigured || store.isCheckingPatchCourierBackendInbox)

                        Button {
                            if store.isPatchCourierBackendPolling {
                                store.stopPatchCourierBackendPolling()
                            } else {
                                store.startPatchCourierBackendPollingIfNeeded()
                            }
                        } label: {
                            Label(
                                store.isPatchCourierBackendPolling
                                    ? AppLocalization.string("bounties.patch_courier.backend.stop_polling", fallback: "Stop auto check")
                                    : AppLocalization.string("bounties.patch_courier.backend.start_polling", fallback: "Start auto check"),
                                systemImage: store.isPatchCourierBackendPolling ? "pause.circle" : "play.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.patchCourierBackendIsEnabled)
                    }

                    if !store.selectedBountyTaskIsClaimed {
                        Text(AppLocalization.string(
                            "bounties.patch_courier.claim_hint",
                            fallback: "Claim this bounty first, then send it to Patch Courier for execution."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                    if !store.patchCourierBackendIsConfigured {
                        Text(AppLocalization.string(
                            "bounties.patch_courier.backend.configure_hint",
                            fallback: "Enable backend mail and configure relay, sender, IMAP/SMTP, and mailbox app password in Settings."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                    if let message = store.patchCourierBackendMessage {
                        Text(message).font(.footnote).foregroundStyle(.green)
                    }
                    if let error = store.patchCourierBackendErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(.top, 8)
            }

            DisclosureGroup(AppLocalization.string("bounties.patch_courier.manual_disclosure", fallback: "Manual Mail.app fallback")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(AppLocalization.string("bounties.patch_courier.note", fallback: "Send the claimed task to Patch Courier's relay mailbox. Patch Courier runs Codex in its EvoMap Tasks workspace and replies with a structured result email."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            store.sendSelectedBountyToPatchCourier()
                        } label: {
                            Label(AppLocalization.string("bounties.patch_courier.send_execute", fallback: "Send to Patch Courier"), systemImage: "envelope.badge")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.patchCourierRelayEmailIsConfigured || !store.selectedBountyTaskIsClaimed)

                        Button {
                            store.querySelectedBountyPatchCourierStatus()
                        } label: {
                            Label(AppLocalization.string("bounties.patch_courier.query_status", fallback: "Query status by email"), systemImage: "envelope.open")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.patchCourierRelayEmailIsConfigured)

                        Button {
                            store.copySelectedBountyPatchCourierExecuteEmail()
                        } label: {
                            Label(AppLocalization.string("bounties.patch_courier.copy_execute", fallback: "Copy email"), systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                    }

                    if !store.patchCourierRelayEmailIsConfigured {
                        Text(AppLocalization.string(
                            "bounties.patch_courier.configure_hint",
                            fallback: "Configure the Patch Courier relay mailbox in Settings before using mail handoff."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                    if let message = store.bountyExecutionMessage {
                        Text(message).font(.footnote).foregroundStyle(.green)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func submissionEditorsCard() -> some View {
        detailCard(AppLocalization.string("bounties.card.delivery", fallback: "Implementation and submission"), systemImage: "hammer") {
            Label(store.selectedBountyClaimedStatusLine, systemImage: store.selectedBountyTaskIsClaimed ? "checkmark.seal" : "exclamationmark.triangle")
                .foregroundStyle(store.selectedBountyTaskIsClaimed ? Color.secondary : Color.orange)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.string("bounties.delivery.implementation_notes", fallback: "Implementation notes"))
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { store.bountyAnswerDraft.implementationNotes },
                    set: { store.bountyAnswerDraft.implementationNotes = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.string("bounties.delivery.final_answer", fallback: "Final answer"))
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { store.bountyAnswerDraft.answerText },
                    set: { store.bountyAnswerDraft.answerText = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.string("bounties.delivery.verification_notes", fallback: "Verification notes"))
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { store.bountyAnswerDraft.verificationNotes },
                    set: { store.bountyAnswerDraft.verificationNotes = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18)))
            }

            DisclosureGroup(AppLocalization.string("bounties.delivery.preview_disclosure", fallback: "Show final submission structure")) {
                Text(store.selectedBountySubmissionPreview)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .textSelection(.enabled)
                    .padding(.top, 8)
            }

            HStack {
                Button {
                    store.generateSelectedBountySubmissionStructure()
                } label: {
                    Label(AppLocalization.string("bounties.action.generate_submission", fallback: "Generate submission structure"), systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)

                Button {
                    store.saveSelectedBountyAnswerDraft()
                } label: {
                    Label(AppLocalization.string("bounties.action.save_draft", fallback: "Save draft"), systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await store.submitSelectedBountyAnswer() }
                } label: {
                    Label(
                        store.isSubmittingBountyAnswer
                            ? AppLocalization.string("bounties.action.submitting", fallback: "Publishing")
                            : AppLocalization.string("bounties.action.publish_complete", fallback: "Publish Capsule and complete"),
                        systemImage: "paperplane.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSubmitSelectedBountyAnswer)
            }

            if let message = store.bountyAnswerDraftMessage {
                Text(message).font(.footnote).foregroundStyle(.green)
            }
            if let error = store.bountyAnswerDraftErrorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}

private struct BountyFollowStepRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .foregroundStyle(isComplete ? .green : .blue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BountyRunMetricBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BountyAutopilotRunAuditCard: View {
    let run: BountyAutopilotRun

    var body: some View {
        detailCard(AppLocalization.string("bounties.autopilot.audit.title", fallback: "Autopilot audit trail"), systemImage: "list.clipboard") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.headline)
                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BadgeLabel(text: run.status.title, tintName: run.status.tintName)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                BountyRunMetricBlock(
                    title: AppLocalization.string("bounties.autopilot.metric.reward", fallback: "Reward"),
                    value: run.rewardCredits.map { AppLocalization.string("credits.unit.count", fallback: "%d credits", $0) } ?? AppLocalization.unknown
                )
                BountyRunMetricBlock(
                    title: AppLocalization.string("bounties.autopilot.metric.score", fallback: "Score"),
                    value: run.score.map(String.init) ?? AppLocalization.unknown
                )
                BountyRunMetricBlock(
                    title: AppLocalization.string("bounties.autopilot.metric.executor", fallback: "Executor"),
                    value: run.executor.title
                )
            }

            BountyAutopilotTimelineView(run: run)

            if let preview = run.finalAnswerPreview?.nonEmpty {
                DisclosureGroup(AppLocalization.string("bounties.autopilot.answer_preview", fallback: "Show recovered answer preview")) {
                    Text(preview)
                        .font(.system(.caption, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }

            if let prompt = run.prompt?.nonEmpty {
                DisclosureGroup(AppLocalization.string("bounties.autopilot.prompt", fallback: "Show saved prompt")) {
                    Text(prompt)
                        .font(.system(.caption, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }

            if let output = run.rawExecutorOutput?.nonEmpty {
                DisclosureGroup(AppLocalization.string("bounties.autopilot.raw_output", fallback: "Show raw OpenClaw output")) {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }

            if let error = run.errorMessage?.nonEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct BountyAutopilotTimelineView: View {
    let run: BountyAutopilotRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.string("bounties.autopilot.timeline", fallback: "Execution timeline"))
                .font(.headline)

            ForEach(run.events) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName(for: event.status))
                        .foregroundStyle(color(for: event.status))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(event.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(event.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func iconName(for status: BountyAutopilotRunStatus) -> String {
        switch status {
        case .queued, .scanning:
            return "magnifyingglass.circle"
        case .claiming:
            return "hand.raised.circle"
        case .executing:
            return "bolt.circle"
        case .needsReview:
            return "eye.circle"
        case .submitting:
            return "paperplane.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private func color(for status: BountyAutopilotRunStatus) -> Color {
        switch status {
        case .queued, .scanning:
            return .blue
        case .claiming, .executing, .submitting:
            return .orange
        case .needsReview:
            return .purple
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct BountyInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            if let task = store.selectedBountyTask {
                Section(AppLocalization.string("bounties.section.selected", fallback: "Selected")) {
                    LabeledContent(AppLocalization.string("bounties.field.bounty_id", fallback: "Bounty ID"), value: task.bountyID ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.string("bounties.field.question_id", fallback: "Question ID"), value: task.questionID ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.string("bounties.field.reward", fallback: "Reward"), value: task.displayCredits.map { AppLocalization.string("credits.unit.count", fallback: "%d credits", $0) } ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.string("bounties.field.deadline", fallback: "Deadline"), value: task.deadline ?? AppLocalization.unknown)
                    LabeledContent(
                        AppLocalization.string("bounties.field.required_reputation", fallback: "Required reputation"),
                        value: store.bountyRequiredReputation(for: task).map { ">= \($0)" } ?? AppLocalization.unknown
                    )
                    LabeledContent(AppLocalization.string("bounties.field.submission", fallback: "Submission"), value: store.selectedClaimedBountyTask?.mySubmissionID ?? AppLocalization.unknown)
                }
            }

            Section(AppLocalization.string("credits.section.selected_node", fallback: "Prerequisites")) {
                LabeledContent(AppLocalization.string("bounties.inspector.selected_node", fallback: "Selected node"), value: store.selectedOrFirstCreditNode?.senderID ?? AppLocalization.chooseConnectedNode)
                LabeledContent(
                    AppLocalization.string("bounties.field.node_reputation", fallback: "Node reputation"),
                    value: store.selectedNodeReputationScore.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? AppLocalization.unknown
                )
                LabeledContent(AppLocalization.string("credits.inspector.claimed_nodes", fallback: "Claimed nodes"), value: "\(store.claimedNodeCount)")
                LabeledContent(AppLocalization.string("credits.inspector.keychain_node_secrets", fallback: "Keychain node secrets"), value: "\(store.storedNodeSecretCount)")
            }

            Section(AppLocalization.string("bounties.section.tracker", fallback: "Tracker")) {
                LabeledContent(AppLocalization.string("bounties.inspector.loaded", fallback: "Loaded"), value: "\(store.bountyTasks.count)")
                LabeledContent(AppLocalization.string("bounties.inspector.total", fallback: "Total"), value: store.bountyTaskTotalCount.map { $0.formatted(.number) } ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.string("bounties.inspector.following", fallback: "Following"), value: "\(store.followedBountyTaskIDs.count)")
                LabeledContent(AppLocalization.string("bounties.inspector.claimed", fallback: "Claimed"), value: "\(store.claimedBountyTasks.count)")
                LabeledContent(AppLocalization.string("bounties.inspector.filtered", fallback: "Filtered"), value: "\(store.filteredBountyTasks.count)")
            }
        }
    }
}

private struct CreditsInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.string("credits.section.selected_node", fallback: "Prerequisites")) {
                LabeledContent(AppLocalization.string("credits.inspector.live_nodes", fallback: "Live nodes"), value: "\(store.creditReportingNodes.count)")
                LabeledContent(AppLocalization.string("credits.inspector.claimed_nodes", fallback: "Claimed nodes"), value: "\(store.claimedNodeCount)")
                LabeledContent(AppLocalization.string("credits.inspector.keychain_node_secrets", fallback: "Keychain node secrets"), value: "\(store.storedNodeSecretCount)")
                LabeledContent(AppLocalization.string("node.field.heartbeat", fallback: "Heartbeat"), value: store.selectedOrFirstCreditNode?.heartbeat.title ?? AppLocalization.string("common.unknown", fallback: "Unknown"))
            }

            Section(AppLocalization.string("credits.section.next_action", fallback: "Next action")) {
                Text(AppLocalization.phrase(store.creditSprintStatusLine))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CreditMetricBlock: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CreditSprintStepRow: View {
    let step: CreditSprintStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.systemImage)
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.title)
                        .font(.headline)
                    Spacer()
                    BadgeLabel(
                        text: step.isComplete
                            ? AppLocalization.string("common.done", fallback: "Done")
                            : AppLocalization.string("common.next", fallback: "Next"),
                        tintName: step.tintName
                    )
                }
                Text(step.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch step.tintName {
        case "green":
            return .green
        case "orange":
            return .orange
        case "blue":
            return .blue
        default:
            return .secondary
        }
    }
}

private struct BountyTaskRow: View {
    let task: EvoMapBountyTask
    let isSelected: Bool
    let isClaiming: Bool
    let isFollowed: Bool
    let isClaimed: Bool
    let submissionStatus: String?
    let requiredReputation: Int?
    let nodeReputation: Double?
    let isOpenForClaim: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                if let credits = task.displayCredits {
                    BountyTaskMiniBadge(
                        text: AppLocalization.string("credits.unit.count", fallback: "%d credits", credits),
                        tint: .green
                    )
                }

                if isClaimed {
                    BountyTaskMiniBadge(
                        text: AppLocalization.string("bounties.badge.claimed", fallback: "Claimed"),
                        tint: .green
                    )
                }

                if let shortEligibilityLine {
                    BountyTaskMiniBadge(text: shortEligibilityLine, tint: eligibilityColor)
                }

                Spacer(minLength: 8)

                if isFollowed {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if isClaiming {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(localizedTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if let summary = task.summary?.nonEmpty {
                Text(AppLocalization.bountyText(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let eligibilityLine {
                    Label(eligibilityLine, systemImage: eligibilityIcon)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(eligibilityColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let submissionStatus {
                    Text(submissionStatus)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let metaLine {
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
    }

    private var metaLine: String? {
        [
            AppLocalization.bountyTerm(task.domain),
            AppLocalization.bountyTerm(task.kind),
            AppLocalization.bountyTerm(task.status),
            task.deadline.map {
                AppLocalization.string("credits.bounty.deadline", fallback: "Deadline %@", $0)
            },
        ]
        .compactMap { $0?.nonEmpty }
        .joined(separator: " · ")
        .nonEmpty
    }

    private var localizedTitle: String {
        AppLocalization.bountyText(task.title)
    }

    private var eligibilityLine: String? {
        if isClaimed {
            if let submissionStatus {
                return AppLocalization.string("bounties.list.claimed_with_status", fallback: "Claimed · %@", submissionStatus)
            }
            return AppLocalization.string("bounties.badge.claimed", fallback: "Claimed")
        }

        guard isOpenForClaim else {
            return AppLocalization.string(
                "bounties.list.not_open_with_status",
                fallback: "Not open · %@",
                AppLocalization.bountyTerm(task.status) ?? task.status ?? AppLocalization.unknown
            )
        }

        guard let requiredReputation else {
            return nil
        }

        guard let nodeReputation else {
            return AppLocalization.string("bounties.list.rep_unknown_with_required", fallback: "Reputation unknown · needs %d", requiredReputation)
        }

        if nodeReputation >= Double(requiredReputation) {
            return AppLocalization.string("bounties.list.claimable_with_rep", fallback: "Claimable · rep %.0f/%d", nodeReputation, requiredReputation)
        }
        return AppLocalization.string("bounties.list.insufficient_rep_with_rep", fallback: "Rep too low · %.0f/%d", nodeReputation, requiredReputation)
    }

    private var eligibilityIcon: String {
        if isClaimed {
            return "checkmark.circle"
        }
        guard isOpenForClaim else {
            return "nosign"
        }
        guard let requiredReputation, let nodeReputation else {
            return "questionmark.circle"
        }
        return nodeReputation >= Double(requiredReputation) ? "checkmark.shield" : "exclamationmark.triangle"
    }

    private var eligibilityColor: Color {
        if isClaimed {
            return .green
        }
        guard isOpenForClaim else {
            return .secondary
        }
        guard let requiredReputation, let nodeReputation else {
            return .secondary
        }
        return nodeReputation >= Double(requiredReputation) ? .green : .orange
    }

    private var shortEligibilityLine: String? {
        if isClaimed {
            return nil
        }
        guard isOpenForClaim else {
            return AppLocalization.string("bounties.list.short_not_open", fallback: "Not open")
        }
        guard let requiredReputation else {
            return nil
        }
        guard let nodeReputation else {
            return AppLocalization.string("bounties.list.short_rep_required", fallback: "Rep >= %d", requiredReputation)
        }
        if nodeReputation >= Double(requiredReputation) {
            return AppLocalization.string("bounties.list.short_claimable", fallback: "Rep %.0f/%d", nodeReputation, requiredReputation)
        }
        return AppLocalization.string("bounties.list.short_insufficient_rep", fallback: "Rep %.0f/%d", nodeReputation, requiredReputation)
    }
}

private struct BountyTaskMiniBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}


private struct CreditServiceTemplate: Identifiable {
    let id = UUID()
    let title: String
    let price: String
    let detail: String
}

private struct SkillsListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(spacing: 0) {
            Picker(AppLocalization.phrase("Skill workspace"), selection: Binding(
                get: { store.skillWorkspaceMode },
                set: { store.setSkillWorkspaceMode($0) }
            )) {
                ForEach(SkillWorkspaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if store.skillWorkspaceMode == .local {
                List(store.filteredSkills, selection: $store.selectedSkillID) { skill in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(AppLocalization.phrase(skill.name))
                                .fontWeight(.semibold)
                            Spacer()
                            BadgeLabel(text: skill.readinessTitle, tintName: skill.readinessTintName)
                            BadgeLabel(text: skill.state.title, tintName: skill.state.tintName)
                        }
                        Text(AppLocalization.phrase(skill.summary))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            Text(skill.category.rawValue.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            if skill.errorCount > 0 || skill.warningCount > 0 {
                                Text("\(skill.errorCount)e · \(skill.warningCount)w")
                                    .font(.caption)
                                    .foregroundStyle(skill.errorCount > 0 ? .red : .orange)
                            }
                            Spacer()
                            Text("\(skill.localCharacterCount) chars · \(skill.bundledFileCount)/10 files")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(skill.id)
                }
            } else if store.skillWorkspaceMode == .store {
                RemoteSkillsListView(store: store)
            } else {
                RecycledSkillsListView(store: store)
            }
        }
        .navigationTitle(store.currentSectionTitle)
    }
}

private struct SkillsDetailView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if store.skillWorkspaceMode == .local {
            SkillDetailView(store: store)
        } else if store.skillWorkspaceMode == .store {
            RemoteSkillDetailView(store: store)
        } else {
            RecycledSkillDetailView(store: store)
        }
    }
}

private struct SkillsInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if store.skillWorkspaceMode == .local {
            SkillInspectorView(store: store)
        } else if store.skillWorkspaceMode == .store {
            RemoteSkillInspectorView(store: store)
        } else {
            RecycledSkillInspectorView(store: store)
        }
    }
}

private struct SkillDetailView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if let skill = store.selectedSkill {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(skill.name))
                        .font(.largeTitle.bold())
                    Text(AppLocalization.phrase(skill.summary))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailCard(AppLocalization.phrase("Metadata"), systemImage: "sparkles.rectangle.stack") {
                        LabeledContent(AppLocalization.phrase("Skill ID"), value: skill.skillID)
                        LabeledContent(AppLocalization.phrase("Category"), value: skill.category.title)
                        LabeledContent(AppLocalization.phrase("Status"), value: skill.state.title)
                        LabeledContent(AppLocalization.phrase("Local characters"), value: "\(skill.localCharacterCount)")
                        LabeledContent(AppLocalization.phrase("Bundled files"), value: AppLocalization.string("skill.bundle.included_excluded", fallback: "%d included, %d excluded", skill.bundledFileCount, skill.excludedBundledFileCount))
                        LabeledContent(AppLocalization.phrase("Bundled characters"), value: "\(skill.bundledCharacterCount)")
                        LabeledContent(AppLocalization.phrase("Target version"), value: skill.suggestedVersion)
                        LabeledContent(AppLocalization.phrase("Remote version"), value: skill.remoteVersion ?? AppLocalization.phrase("Not published"))
                        LabeledContent(AppLocalization.phrase("Remote status"), value: skill.remoteStatus ?? AppLocalization.phrase("Local only"))
                        LabeledContent(
                            AppLocalization.phrase("Last sync"),
                            value: skill.lastPublishedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.phrase("Never")
                        )
                        LabeledContent(AppLocalization.phrase("Last publisher"), value: skill.lastPublishedBySenderID ?? AppLocalization.phrase("Not yet published"))
                        LabeledContent(AppLocalization.phrase("Source"), value: skill.sourcePath ?? AppLocalization.phrase("Imported preview"))
                        if let storeSnapshotVersion = skill.storeSnapshotVersion {
                            LabeledContent(AppLocalization.phrase("Store snapshot"), value: storeSnapshotVersion)
                        }
                        if let downloadedFromStoreAt = skill.downloadedFromStoreAt {
                            LabeledContent(
                                AppLocalization.phrase("Downloaded"),
                                value: downloadedFromStoreAt.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                        if let downloadedFromStoreAuthorNodeID = skill.downloadedFromStoreAuthorNodeID {
                            LabeledContent(AppLocalization.phrase("Store author"), value: downloadedFromStoreAuthorNodeID)
                        }
                        if let downloadedStoreDirectoryPath = skill.downloadedStoreDirectoryPath {
                            LabeledContent(AppLocalization.phrase("Managed folder"), value: downloadedStoreDirectoryPath)
                        }
                        if let downloadedCreditCost = skill.downloadedCreditCost {
                            LabeledContent(AppLocalization.phrase("Download cost"), value: AppLocalization.string("credits.unit.count", fallback: "%d credits", downloadedCreditCost))
                        }
                    }

                    detailCard(AppLocalization.phrase("Publish target"), systemImage: "server.rack") {
                        LabeledContent(AppLocalization.phrase("Publisher node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                        LabeledContent(AppLocalization.phrase("Node auth"), value: store.selectedNode?.nodeSecretStored == true ? AppLocalization.keychainReady : AppLocalization.missingNodeSecret)
                        LabeledContent(
                            AppLocalization.phrase("Skill Store"),
                            value: skillStoreSummary(for: store.selectedNode)
                        )
                        if let hint = store.selectedNode?.skillStoreStatus?.hint {
                            Text(AppLocalization.phrase(hint))
                                .foregroundStyle(.secondary)
                        }
                    }

                    detailCard(AppLocalization.phrase("Skill Store action"), systemImage: "paperplane") {
                        Button {
                            Task {
                                await store.publishSelectedSkill()
                            }
                        } label: {
                            if store.isPublishingSelectedSkill {
                                Label(AppLocalization.phrase("Publishing to EvoMap"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                            } else {
                                Label(AppLocalization.phrase(store.skillPublishActionTitle), systemImage: "paperplane.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canPublishSelectedSkill)

                        if store.isPublishingSelectedSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedSkillPublishNote))
                            .foregroundStyle(.secondary)

                        if let message = skill.lastPublishMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = skill.lastPublishErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Tags"), systemImage: "tag") {
                        if skill.tags.isEmpty {
                            Text(AppLocalization.phrase("No tags inferred yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowTagsView(tags: skill.tags)
                        }
                    }

                    detailCard(AppLocalization.phrase("Validation"), systemImage: "checklist") {
                        ChecklistRow(
                            title: AppLocalization.phrase("Character budget"),
                            detail: AppLocalization.phrase(skill.localCharacterCount <= 50_000 ? "Within the published limit." : "Needs trimming before publish."),
                            isComplete: skill.localCharacterCount <= 50_000
                        )
                        ChecklistRow(
                            title: AppLocalization.phrase("Bundled files"),
                            detail: AppLocalization.phrase(skill.bundledFileCount <= 10 ? "Bundled file count is safe." : "Too many bundled files for the current limit."),
                            isComplete: skill.bundledFileCount <= 10
                        )
                        ChecklistRow(
                            title: AppLocalization.phrase("Required fixes"),
                            detail: skill.errorCount == 0 ? AppLocalization.phrase("No blocking validation errors.") : AppLocalization.string("skill.validation.blocking_issues", fallback: "%d blocking issue(s) still need changes.", skill.errorCount),
                            isComplete: skill.errorCount == 0
                        )
                        if skill.validationIssues.isEmpty {
                            Divider()
                            Text(AppLocalization.phrase("No validation findings yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            Divider()
                            ForEach(skill.validationIssues) { issue in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        BadgeLabel(text: issue.severity.title, tintName: issue.severity.tintName)
                                        Text(AppLocalization.phrase(issue.title))
                                            .font(.headline)
                                    }
                                    Text(AppLocalization.phrase(issue.detail))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Bundled files"), systemImage: "shippingbox") {
                        if skill.bundledFiles.isEmpty {
                            Text(AppLocalization.phrase("No companion files discovered from the local skill directory."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(skill.bundledFiles) { bundledFile in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(bundledFile.relativePath)
                                            .font(.body.monospaced())
                                        Spacer()
                                        BadgeLabel(
                                            text: bundledFile.isIncluded ? AppLocalization.phrase("Included") : AppLocalization.phrase("Excluded"),
                                            tintName: bundledFile.isIncluded ? "green" : "orange"
                                        )
                                    }
                                    Text(AppLocalization.string("skill.bundle.characters", fallback: "%d chars", bundledFile.characterCount))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    if let note = bundledFile.note {
                                        Text(AppLocalization.phrase(note))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                                if bundledFile.id != skill.bundledFiles.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Source preview"), systemImage: "doc.text") {
                        Text(verbatim: skill.content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(skill.name))
        } else {
            ContentUnavailableView(AppLocalization.phrase("Select a skill"), systemImage: "sparkles.rectangle.stack", description: Text(AppLocalization.phrase("Choose a skill to review metadata, limits, and publish readiness.")))
        }
    }

    private func skillStoreSummary(for node: NodeRecord?) -> String {
        guard let node else { return AppLocalization.phrase("No publisher selected") }
        guard let status = node.skillStoreStatus else {
            return node.nodeSecretStored ? AppLocalization.phrase("Awaiting live heartbeat data") : AppLocalization.phrase("Missing auth")
        }
        return status.eligible ? AppLocalization.string("skill_store.summary.eligible_count", fallback: "Eligible (%d published)", status.publishedSkillCount) : AppLocalization.phrase("Not eligible")
    }
}

private struct RemoteSkillsListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        listView
        .task(id: store.skillWorkspaceMode) {
            guard store.skillWorkspaceMode == .store else { return }
            await store.loadRemoteSkillsIfNeeded()
        }
    }

    private var listView: some View {
        List(store.filteredRemoteSkills, selection: selectionBinding) { skill in
            row(for: skill)
        }
        .overlay { overlayContent }
        .safeAreaInset(edge: .top, spacing: 0) { statusHeader }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { store.selectedRemoteSkillID },
            set: { store.selectRemoteSkill($0) }
        )
    }

    @ViewBuilder
    private var overlayContent: some View {
        if store.isLoadingRemoteSkills && store.remoteSkills.isEmpty {
            ProgressView(AppLocalization.phrase("Loading Skill Store"))
        } else if store.filteredRemoteSkills.isEmpty {
            ContentUnavailableView(
                AppLocalization.phrase("No remote skills"),
                systemImage: "shippingbox",
                description: Text(AppLocalization.phrase(store.remoteSkillCollectionStatus))
            )
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.phrase("Public Skill Store"))
                .font(.headline)
            Text(AppLocalization.phrase(store.remoteSkillCollectionStatus))
                .font(.footnote)
                .foregroundStyle(store.remoteSkillLoadErrorMessage == nil ? Color.secondary : Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
    }

    private func row(for skill: RemoteSkillSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.phrase(skill.name))
                        .fontWeight(.semibold)
                    Text(skill.skillId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if skill.featured {
                    BadgeLabel(text: AppLocalization.phrase("Featured"), tintName: "green")
                }
                Text(skill.version)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(AppLocalization.phrase(skill.description))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(AppLocalization.phrase(skill.category ?? "uncategorized").uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AppLocalization.string("skill.downloads.count", fallback: "%d downloads", skill.downloadCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(skill.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? AppLocalization.phrase("Unknown date"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .tag(skill.id)
    }
}

private struct RecycledSkillsListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        listView
            .task(id: store.skillWorkspaceMode) {
                guard store.skillWorkspaceMode == .recycleBin else { return }
                await store.loadRecycleBinIfNeeded()
            }
    }

    private var listView: some View {
        List(store.filteredRecycledSkills, selection: selectionBinding) { skill in
            row(for: skill)
        }
        .overlay { overlayContent }
        .safeAreaInset(edge: .top, spacing: 0) { statusHeader }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { store.selectedRecycledSkillID },
            set: { store.selectRecycledSkill($0) }
        )
    }

    @ViewBuilder
    private var overlayContent: some View {
        if store.isLoadingRecycledSkills && store.recycledSkills.isEmpty {
            ProgressView(AppLocalization.phrase("Loading Recycle Bin"))
        } else if store.filteredRecycledSkills.isEmpty {
            ContentUnavailableView(
                AppLocalization.phrase("No recycled skills"),
                systemImage: "trash",
                description: Text(AppLocalization.phrase(store.recycleBinCollectionStatus))
            )
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalization.phrase("Skill Store Recycle Bin"))
                .font(.headline)
            Text(AppLocalization.phrase(store.recycleBinCollectionStatus))
                .font(.footnote)
                .foregroundStyle(store.recycledSkillLoadErrorMessage == nil ? Color.secondary : Color.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
    }

    private func row(for skill: RecycledSkillSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.phrase(skill.name))
                        .fontWeight(.semibold)
                    Text(skill.skillId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(skill.version ?? AppLocalization.unknown)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(skill.description.map(AppLocalization.phrase) ?? AppLocalization.phrase("No description is available for this recycled Skill."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(AppLocalization.phrase(skill.category ?? "uncategorized").uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(skill.deletedAt?.formatted(date: .abbreviated, time: .omitted) ?? AppLocalization.phrase("Unknown delete date"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .tag(skill.id)
    }
}

private struct RemoteSkillDetailView: View {
    @ObservedObject var store: ConsoleStore
    @State private var isConfirmingDelete = false
    @State private var pendingVersionDeletion: RemoteSkillVersion?

    var body: some View {
        if let skill = store.selectedRemoteSkillSummary {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(store.remoteSkillDetail?.name ?? skill.name))
                        .font(.largeTitle.bold())
                    Text(store.remoteSkillDetail?.description ?? skill.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailCard(AppLocalization.phrase("Store metadata"), systemImage: "shippingbox") {
                        LabeledContent(AppLocalization.phrase("Skill ID"), value: skill.skillId)
                        LabeledContent(AppLocalization.phrase("Version"), value: store.remoteSkillDetail?.version ?? skill.version)
                        LabeledContent(AppLocalization.phrase("Category"), value: AppLocalization.phrase(store.remoteSkillDetail?.category ?? skill.category ?? "Uncategorized"))
                        LabeledContent(AppLocalization.phrase("Downloads"), value: "\(store.remoteSkillDetail?.downloadCount ?? skill.downloadCount)")
                        LabeledContent(AppLocalization.phrase("Review"), value: store.remoteSkillDetail?.reviewStatus ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Visibility"), value: AppLocalization.phrase(store.remoteSkillDetail?.visibility ?? "Public"))
                        LabeledContent(
                            AppLocalization.phrase("Published"),
                            value: (store.remoteSkillDetail?.createdAt ?? skill.createdAt)?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                        LabeledContent(
                            AppLocalization.phrase("Updated"),
                            value: store.remoteSkillDetail?.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                        LabeledContent(
                            AppLocalization.phrase("Author node"),
                            value: store.remoteSkillDetail?.author?.nodeId ?? skill.author?.nodeId ?? AppLocalization.unknown
                        )
                        if skill.featured {
                            BadgeLabel(text: AppLocalization.phrase("Featured skill"), tintName: "green")
                        }
                    }

                    detailCard(AppLocalization.phrase("Operator note"), systemImage: "text.magnifyingglass") {
                        if store.isLoadingRemoteSkillDetail {
                            ProgressView(AppLocalization.phrase("Loading version history and detail"))
                        } else if let error = store.remoteSkillDetailErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Text(AppLocalization.phrase("This view uses the public Skill Store list, detail, and versions endpoints from the live EvoMap hub."))
                                .foregroundStyle(.secondary)
                        }
                    }

                    detailCard(AppLocalization.phrase("Download to local library"), systemImage: "arrow.down.circle") {
                        Button {
                            Task {
                                await store.downloadSelectedRemoteSkill()
                            }
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isDownloadingSelectedRemoteSkill ? "Downloading from EvoMap" : "Download to Library"),
                                systemImage: store.isDownloadingSelectedRemoteSkill
                                    ? "arrow.down.circle.fill"
                                    : "arrow.down.circle"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canDownloadSelectedRemoteSkill)

                        if store.isDownloadingSelectedRemoteSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRemoteSkillDownloadNote))
                            .foregroundStyle(.secondary)

                        if let message = store.remoteSkillDownloadMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.remoteSkillDownloadErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Store management"), systemImage: "slider.horizontal.3") {
                        LabeledContent(AppLocalization.phrase("Author node"), value: store.selectedRemoteSkillAuthorNodeID ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Current visibility"), value: AppLocalization.phrase(store.selectedRemoteSkillVisibility.capitalized))

                        Button {
                            Task {
                                await store.toggleSelectedRemoteSkillVisibility()
                            }
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isUpdatingSelectedRemoteSkillVisibility ? "Updating Visibility" : store.selectedRemoteSkillVisibilityActionTitle),
                                systemImage: store.isUpdatingSelectedRemoteSkillVisibility
                                    ? "eye.circle.fill"
                                    : "eye.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canUpdateSelectedRemoteSkillVisibility)

                        if store.isUpdatingSelectedRemoteSkillVisibility {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRemoteSkillVisibilityNote))
                            .foregroundStyle(.secondary)

                        Divider()

                        if store.availableRemoteRollbackVersions.isEmpty {
                            Text(AppLocalization.phrase(store.isLoadingRemoteSkillDetail ? "Loading rollback targets..." : "No earlier versions are available for rollback."))
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(AppLocalization.phrase("Rollback target"), selection: $store.remoteSkillRollbackTargetVersion) {
                                ForEach(store.availableRemoteRollbackVersions) { version in
                                    Text(version.version).tag(Optional(version.version))
                                }
                            }
                            .pickerStyle(.menu)

                            Button {
                                Task {
                                    await store.rollbackSelectedRemoteSkill()
                                }
                            } label: {
                                Label(
                                    AppLocalization.phrase(store.isRollingBackSelectedRemoteSkill ? "Rolling Back" : "Rollback to Selected Version"),
                                    systemImage: store.isRollingBackSelectedRemoteSkill
                                        ? "arrow.uturn.backward.circle.fill"
                                        : "arrow.uturn.backward.circle"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(!store.canRollbackSelectedRemoteSkill)
                        }

                        if store.isRollingBackSelectedRemoteSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRemoteSkillRollbackNote))
                            .foregroundStyle(.secondary)

                        Text(AppLocalization.phrase("Official docs note that rollback sends the Skill back to `pending` review."))
                            .font(.footnote)
                            .foregroundStyle(.tertiary)

                        Divider()

                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isDeletingSelectedRemoteSkill ? "Deleting Skill" : "Move to Recycle Bin"),
                                systemImage: store.isDeletingSelectedRemoteSkill
                                    ? "trash.circle.fill"
                                    : "trash.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canDeleteSelectedRemoteSkill)

                        if store.isDeletingSelectedRemoteSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRemoteSkillDeleteNote))
                            .foregroundStyle(.secondary)

                        if let message = store.remoteSkillMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.remoteSkillMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Tags"), systemImage: "tag") {
                        let tags = store.remoteSkillDetail?.tags ?? skill.tags
                        if tags.isEmpty {
                            Text(AppLocalization.phrase("No tags were published for this skill."))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowTagsView(tags: tags)
                        }
                    }

                    detailCard(AppLocalization.phrase("Version history"), systemImage: "clock.arrow.circlepath") {
                        if store.remoteSkillVersions.isEmpty {
                            Text(AppLocalization.phrase(store.isLoadingRemoteSkillDetail ? "Loading versions..." : "No version history returned."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.remoteSkillVersions) { version in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Text(version.version)
                                                .font(.headline.monospaced())
                                            if store.isCurrentRemoteSkillVersion(version) {
                                                BadgeLabel(text: AppLocalization.phrase("Current"), tintName: "blue")
                                            }
                                        }
                                        Spacer()
                                        if store.isDeletingRemoteSkillVersion(version) {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else if !store.isCurrentRemoteSkillVersion(version) {
                                            Button(role: .destructive) {
                                                pendingVersionDeletion = version
                                            } label: {
                                                Label(AppLocalization.phrase("Delete Version"), systemImage: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(!store.canDeleteRemoteSkillVersion(version))
                                        }
                                        Text(version.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.phrase("Unknown date"))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(version.changelog?.nonEmpty.map(AppLocalization.phrase) ?? AppLocalization.phrase("No changelog provided."))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                                if version.id != store.remoteSkillVersions.last?.id {
                                    Divider()
                                }
                            }

                            Divider()

                            Text(AppLocalization.phrase("Official docs allow `/a2a/skill/store/delete-version` only for historical versions; the current live version and the last remaining version stay protected."))
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    detailCard(AppLocalization.phrase("Preview"), systemImage: "doc.text") {
                        Text(verbatim: store.remoteSkillDetail?.contentPreview ?? skill.contentPreview ?? AppLocalization.phrase("No preview text returned."))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(skill.name))
            .task(id: store.selectedRemoteSkillID) {
                guard store.skillWorkspaceMode == .store else { return }
                await store.loadSelectedRemoteSkillDetail()
            }
            .confirmationDialog(
                AppLocalization.phrase("Move this Skill to the recycle bin?"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.phrase("Move to Recycle Bin"), role: .destructive) {
                    Task {
                        await store.deleteSelectedRemoteSkill()
                    }
                }
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalization.phrase("The official docs say deleted Skills stay recoverable in the recycle bin for 30 days."))
            }
            .confirmationDialog(
                AppLocalization.phrase("Delete this historical version?"),
                isPresented: Binding(
                    get: { pendingVersionDeletion != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingVersionDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingVersionDeletion
            ) { version in
                Button(AppLocalization.phrase("Delete Version"), role: .destructive) {
                    Task {
                        await store.deleteRemoteSkillVersion(version)
                    }
                    pendingVersionDeletion = nil
                }
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel) {
                    pendingVersionDeletion = nil
                }
            } message: { version in
                Text(AppLocalization.string(
                    "skill.remote.delete_version.message",
                    fallback: "Delete %@ from the live Skill Store history. The current version remains untouched.",
                    version.version
                ))
            }
        } else {
            ContentUnavailableView(
                AppLocalization.phrase("Select a remote skill"),
                systemImage: "shippingbox",
                description: Text(AppLocalization.phrase("Browse the public Skill Store feed to inspect live metadata and version history."))
            )
        }
    }
}

private struct RecycledSkillDetailView: View {
    @ObservedObject var store: ConsoleStore
    @State private var isConfirmingPermanentDelete = false

    var body: some View {
        if let skill = store.selectedRecycledSkill {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(skill.name))
                        .font(.largeTitle.bold())
                    Text(skill.description.map(AppLocalization.phrase) ?? AppLocalization.phrase("This recycled Skill is no longer visible in the public Skill Store feed."))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailCard(AppLocalization.phrase("Recycle-bin metadata"), systemImage: "trash") {
                        LabeledContent(AppLocalization.phrase("Skill ID"), value: skill.skillId)
                        LabeledContent(AppLocalization.phrase("Version"), value: skill.version ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Category"), value: AppLocalization.phrase(skill.category ?? "Uncategorized"))
                        LabeledContent(AppLocalization.phrase("Original visibility"), value: skill.originalVisibility.map { AppLocalization.phrase($0.capitalized) } ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Review"), value: skill.reviewStatus ?? AppLocalization.unknown)
                        LabeledContent(
                            AppLocalization.phrase("Deleted"),
                            value: skill.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                        LabeledContent(
                            AppLocalization.phrase("Updated"),
                            value: skill.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                        LabeledContent(AppLocalization.phrase("Author node"), value: skill.author?.nodeId ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Versions"), value: skill.totalVersions.map(String.init) ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Downloads"), value: skill.downloadCount.map(String.init) ?? AppLocalization.unknown)
                    }

                    detailCard(AppLocalization.phrase("Restore"), systemImage: "arrow.uturn.backward.circle") {
                        Button {
                            Task {
                                await store.restoreSelectedRecycledSkill()
                            }
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isRestoringSelectedRecycledSkill ? "Restoring Skill" : "Restore from Recycle Bin"),
                                systemImage: store.isRestoringSelectedRecycledSkill
                                    ? "arrow.uturn.backward.circle.fill"
                                    : "arrow.uturn.backward.circle"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canRestoreSelectedRecycledSkill)

                        if store.isRestoringSelectedRecycledSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRecycledSkillRestoreNote))
                            .foregroundStyle(.secondary)
                    }

                    detailCard(AppLocalization.phrase("Permanent delete"), systemImage: "trash.slash") {
                        Button(role: .destructive) {
                            isConfirmingPermanentDelete = true
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isPermanentlyDeletingSelectedRecycledSkill ? "Deleting Forever" : "Permanently Delete"),
                                systemImage: store.isPermanentlyDeletingSelectedRecycledSkill
                                    ? "trash.slash.fill"
                                    : "trash.slash"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canPermanentlyDeleteSelectedRecycledSkill)

                        if store.isPermanentlyDeletingSelectedRecycledSkill {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedRecycledSkillPermanentDeleteNote))
                            .foregroundStyle(.secondary)
                        Text(AppLocalization.phrase("Permanent delete removes all versions, downloads, and metadata according to the official docs."))
                            .font(.footnote)
                            .foregroundStyle(.tertiary)

                        if let message = store.remoteSkillMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.remoteSkillMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Tags"), systemImage: "tag") {
                        if skill.tags.isEmpty {
                            Text(AppLocalization.phrase("No tags are available for this recycled Skill."))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowTagsView(tags: skill.tags)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(skill.name))
            .confirmationDialog(
                AppLocalization.phrase("Permanently delete this Skill?"),
                isPresented: $isConfirmingPermanentDelete,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.phrase("Delete Forever"), role: .destructive) {
                    Task {
                        await store.permanentlyDeleteSelectedRecycledSkill()
                    }
                }
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalization.phrase("This cannot be undone from the recycle bin. Restoring first is safer if you might need it again."))
            }
        } else {
            ContentUnavailableView(
                AppLocalization.phrase("Select a recycled skill"),
                systemImage: "trash",
                description: Text(AppLocalization.phrase("Use the recycle bin to restore deleted Skills or permanently remove them."))
            )
        }
    }
}

private struct ServicesListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedServiceID },
            set: { store.selectService($0) }
        )) {
            Section {
                Text(AppLocalization.phrase(store.serviceCollectionStatus))
                    .font(.footnote)
                    .foregroundStyle(store.serviceLoadErrorMessage == nil ? Color.secondary : Color.orange)
            }

            Section {
                ForEach(store.filteredServices) { service in
                    row(for: service)
                }
            }
        }
        .navigationTitle(store.currentSectionTitle)
        .task(id: store.selectedSection) {
            guard store.selectedSection == .services else { return }
            await store.loadServicesIfNeeded()
        }
    }

    private func row(for service: RemoteServiceSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.phrase(service.title))
                        .fontWeight(.semibold)
                    Text(service.listingID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let status = service.status {
                    BadgeLabel(
                        text: status.capitalized,
                        tintName: ServiceLifecycleStatus(rawValue: status.lowercased())?.tintName ?? "secondary"
                    )
                }
            }

            Text(AppLocalization.phrase(service.description))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(AppLocalization.string("credits.unit.short", fallback: "%d cr", service.pricePerTask ?? 0), systemImage: "creditcard")
                if let rating = service.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                }
                if let completionRate = service.completionRate {
                    Label(ServiceFormatting.percent(completionRate), systemImage: "checkmark.seal")
                }
                Spacer()
                Text(service.providerAlias ?? service.providerNodeID ?? AppLocalization.phrase("Unknown node"))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if service.capabilities.isEmpty == false {
                FlowTagsView(tags: Array(service.capabilities.prefix(4)))
            }
        }
        .padding(.vertical, 4)
        .tag(service.id)
    }
}

private struct ServiceDetailView: View {
    @ObservedObject var store: ConsoleStore
    @State private var isConfirmingArchive = false

    var body: some View {
        if let service = store.selectedServiceSummary {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(store.serviceDetail?.title ?? service.title))
                        .font(.largeTitle.bold())
                    Text(store.serviceDetail?.description ?? service.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailCard(AppLocalization.phrase("Marketplace metadata"), systemImage: "shippingbox") {
                        LabeledContent(AppLocalization.phrase("Listing ID"), value: service.listingID)
                        LabeledContent(AppLocalization.phrase("Status"), value: AppLocalization.phrase((store.serviceDetail?.status ?? service.status ?? AppLocalization.unknown).capitalized))
                        LabeledContent(AppLocalization.phrase("Price"), value: AppLocalization.string("service.price.per_task", fallback: "%d credits / task", store.serviceDetail?.pricePerTask ?? service.pricePerTask ?? 0))
                        LabeledContent(AppLocalization.phrase("Provider"), value: store.serviceDetail?.providerAlias ?? service.providerAlias ?? store.serviceDetail?.providerNodeID ?? service.providerNodeID ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Provider node"), value: store.serviceDetail?.providerNodeID ?? service.providerNodeID ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Recipe"), value: store.serviceDetail?.recipeID ?? service.recipeID ?? AppLocalization.none)
                        LabeledContent(
                            AppLocalization.phrase("Published"),
                            value: (store.serviceDetail?.createdAt ?? service.createdAt)?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                        LabeledContent(
                            AppLocalization.phrase("Updated"),
                            value: (store.serviceDetail?.updatedAt ?? service.updatedAt)?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
                        )
                    }

                    detailCard(AppLocalization.phrase("Live performance"), systemImage: "chart.line.uptrend.xyaxis") {
                        LabeledContent(AppLocalization.phrase("Rating"), value: ServiceFormatting.rating(store.serviceDetail?.rating ?? service.rating))
                        LabeledContent(AppLocalization.phrase("Completion"), value: ServiceFormatting.percent(store.serviceDetail?.completionRate ?? service.completionRate))
                        LabeledContent(AppLocalization.phrase("Avg response"), value: store.serviceDetail?.averageResponseTime ?? service.averageResponseTime ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Completed tasks"), value: ServiceFormatting.integer(store.serviceDetail?.tasksCompleted ?? service.tasksCompleted))
                        LabeledContent(AppLocalization.phrase("Active tasks"), value: ServiceFormatting.integer(store.serviceDetail?.activeTasks ?? service.activeTasks))
                        LabeledContent(AppLocalization.phrase("Max concurrency"), value: ServiceFormatting.integer(store.serviceDetail?.maxConcurrent ?? service.maxConcurrent))
                    }

                    detailCard(AppLocalization.phrase("Operator note"), systemImage: "text.magnifyingglass") {
                        if store.isLoadingServiceDetail {
                            ProgressView(AppLocalization.phrase("Loading marketplace detail"))
                        } else if let error = store.serviceDetailErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Text(AppLocalization.phrase("This panel uses the official EvoMap service list, search, detail, publish, update, and archive endpoints from the live marketplace."))
                                .foregroundStyle(.secondary)
                        }
                    }

                    detailCard(AppLocalization.phrase("Capabilities"), systemImage: "wand.and.rays") {
                        let capabilities = store.serviceDetail?.capabilities ?? service.capabilities
                        if capabilities.isEmpty {
                            Text(AppLocalization.phrase("No capabilities were returned for this service."))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowTagsView(tags: capabilities)
                        }
                    }

                    detailCard(AppLocalization.phrase("Use cases"), systemImage: "square.grid.2x2") {
                        let useCases = store.serviceDetail?.useCases ?? service.useCases
                        if useCases.isEmpty {
                            Text(AppLocalization.phrase("No use cases were published for this service."))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowTagsView(tags: useCases)
                        }
                    }

                    detailCard(AppLocalization.phrase("Public ratings"), systemImage: "star.bubble") {
                        if store.isLoadingServiceRatings {
                            ProgressView(AppLocalization.phrase("Loading public ratings"))
                        } else if let error = store.serviceRatingsErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else if store.serviceRatings.isEmpty {
                            Text(AppLocalization.phrase("No public ratings are visible for this service yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.serviceRatings) { rating in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Label(
                                            ServiceRatingFormatting.stars(rating.rating),
                                            systemImage: "star.fill"
                                        )
                                        .foregroundStyle(.orange)
                                        Spacer()
                                        Text(OrderFormatting.timestamp(rating.createdAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(rating.authorAlias ?? rating.authorNodeID ?? AppLocalization.phrase("Anonymous buyer"))
                                        .font(.subheadline.weight(.medium))
                                    if let comment = rating.comment {
                                        Text(AppLocalization.phrase(comment))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Order this service"), systemImage: "cart") {
                        LabeledContent(AppLocalization.phrase("Requester node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                        LabeledContent(AppLocalization.phrase("Provider node"), value: store.selectedServiceProviderNodeID ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Estimated credits"), value: "\(store.serviceDetail?.pricePerTask ?? service.pricePerTask ?? 0)")

                        Button {
                            store.prepareOrderComposerForSelectedService()
                        } label: {
                            Label(AppLocalization.phrase("Place Order"), systemImage: "paperplane.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canCreateOrderFromSelectedService)

                        Text(AppLocalization.phrase(store.selectedServiceOrderNote))
                            .foregroundStyle(.secondary)

                        if let message = store.orderMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.orderMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Service management"), systemImage: "slider.horizontal.3") {
                        LabeledContent(AppLocalization.phrase("Selected node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                        LabeledContent(AppLocalization.phrase("Author node"), value: store.selectedServiceProviderNodeID ?? AppLocalization.unknown)

                        Button {
                            store.prepareServiceComposerForSelectedServiceUpdate()
                        } label: {
                            Label(AppLocalization.phrase("Edit Service"), systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canEditSelectedService)

                        Button {
                            Task {
                                await store.toggleSelectedServiceStatus()
                            }
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isUpdatingSelectedServiceStatus ? "Updating Status" : store.selectedServiceStatusActionTitle),
                                systemImage: store.isUpdatingSelectedServiceStatus ? "pause.circle.fill" : "pause.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canToggleSelectedServiceStatus)

                        if store.isUpdatingSelectedServiceStatus {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedServiceStatusNote))
                            .foregroundStyle(.secondary)

                        Divider()

                        Button(role: .destructive) {
                            isConfirmingArchive = true
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isArchivingSelectedService ? "Archiving Service" : "Archive Service"),
                                systemImage: store.isArchivingSelectedService ? "archivebox.circle.fill" : "archivebox"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canArchiveSelectedService)

                        if store.isArchivingSelectedService {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(AppLocalization.phrase(store.selectedServiceArchiveNote))
                            .foregroundStyle(.secondary)

                        if let message = store.serviceMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.serviceMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(service.title))
            .task(id: store.selectedServiceID) {
                guard store.selectedSection == .services else { return }
                await store.loadSelectedServiceDetail()
                await store.loadSelectedServiceRatings()
            }
            .confirmationDialog(
                AppLocalization.phrase("Archive this service?"),
                isPresented: $isConfirmingArchive,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.phrase("Archive Service"), role: .destructive) {
                    Task {
                        await store.archiveSelectedService()
                    }
                }
                Button(AppLocalization.string("common.cancel", fallback: "Cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalization.phrase("Archived services leave the live marketplace feed and stop receiving new marketplace demand."))
            }
        } else {
            ContentUnavailableView(
                AppLocalization.phrase("Select a service"),
                systemImage: "shippingbox",
                description: Text(AppLocalization.phrase("Browse the EvoMap services marketplace to inspect live listings and manage your own offerings."))
            )
        }
    }
}

private struct ServiceInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.phrase("Marketplace")) {
                LabeledContent(AppLocalization.phrase("Visible listings"), value: "\(store.services.count)")
                LabeledContent(AppLocalization.phrase("Search query"), value: store.searchText.nonEmpty ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Recent ratings"), value: "\(store.serviceRatings.count)")
                Text(AppLocalization.phrase(store.serviceCollectionStatus))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Draft")) {
                LabeledContent(AppLocalization.phrase("Mode"), value: store.serviceDraft.mode.title)
                LabeledContent(AppLocalization.phrase("Capabilities"), value: "\(store.serviceDraftParsedCapabilities.count)")
                LabeledContent(AppLocalization.phrase("Use cases"), value: "\(store.serviceDraftParsedUseCases.count)")
                LabeledContent(AppLocalization.phrase("Price"), value: "\(store.serviceDraft.pricePerTask) credits")
                LabeledContent(AppLocalization.phrase("Concurrency"), value: "\(store.serviceDraft.maxConcurrent)")
                Text(AppLocalization.phrase(store.serviceDraftNote))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Selected listing")) {
                LabeledContent(AppLocalization.phrase("Listing ID"), value: store.selectedServiceSummary?.listingID ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Status"), value: store.selectedServiceStatus.capitalized)
                LabeledContent(AppLocalization.phrase("Provider node"), value: store.selectedServiceProviderNodeID ?? AppLocalization.unknown)
                Text(AppLocalization.phrase(store.serviceRatingsCollectionStatus))
                    .foregroundStyle(.secondary)
                if let error = store.serviceMutationErrorMessage {
                    Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if let message = store.serviceMutationMessage {
                    Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

private struct ServiceComposerSheet: View {
    @ObservedObject var store: ConsoleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.phrase("Listing")) {
                    TextField(AppLocalization.phrase("Title"), text: $store.serviceDraft.title)
                    TextField(AppLocalization.phrase("Description"), text: $store.serviceDraft.description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField(AppLocalization.phrase("Capabilities (comma or newline separated)"), text: $store.serviceDraft.capabilitiesText, axis: .vertical)
                        .lineLimit(2...5)
                    TextField(AppLocalization.phrase("Use cases (comma or newline separated)"), text: $store.serviceDraft.useCasesText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(AppLocalization.phrase("Recipe ID (optional)"), text: $store.serviceDraft.recipeID)
                }

                Section(AppLocalization.phrase("Commercials")) {
                    Stepper(value: $store.serviceDraft.pricePerTask, in: 1...500) {
                        LabeledContent(AppLocalization.phrase("Price per task"), value: "\(store.serviceDraft.pricePerTask) credits")
                    }
                    Stepper(value: $store.serviceDraft.maxConcurrent, in: 1...20) {
                        LabeledContent(AppLocalization.phrase("Max concurrency"), value: "\(store.serviceDraft.maxConcurrent)")
                    }
                    Picker(AppLocalization.phrase("Status"), selection: $store.serviceDraft.status) {
                        ForEach(ServiceLifecycleStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section(AppLocalization.phrase("Preview")) {
                    LabeledContent(AppLocalization.phrase("Publisher node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                    LabeledContent(AppLocalization.phrase("Node auth"), value: store.selectedNode?.nodeSecretStored == true ? AppLocalization.keychainReady : AppLocalization.missingNodeSecret)
                    LabeledContent(AppLocalization.phrase("Capabilities"), value: store.serviceDraftParsedCapabilities.joined(separator: ", ").nonEmpty ?? AppLocalization.none)
                    LabeledContent(AppLocalization.phrase("Use cases"), value: store.serviceDraftParsedUseCases.joined(separator: ", ").nonEmpty ?? AppLocalization.none)
                    Text(AppLocalization.phrase(store.serviceDraftNote))
                        .foregroundStyle(.secondary)

                    if let error = store.serviceMutationErrorMessage {
                        Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(store.serviceDraft.mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("common.cancel", fallback: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await store.submitServiceDraft()
                            if store.serviceMutationErrorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if store.isSubmittingServiceDraft {
                            ProgressView()
                        } else {
                            Text(store.serviceDraftSubmitTitle)
                        }
                    }
                    .disabled(!store.canSubmitServiceDraft)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
    }
}

private struct OrdersListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedOrderTaskID },
            set: { store.selectOrder($0) }
        )) {
            Section {
                Text(AppLocalization.phrase(store.orderCollectionStatus))
                    .font(.footnote)
                    .foregroundStyle(store.orderLoadErrorMessage == nil ? Color.secondary : Color.orange)
            }

            Section {
                ForEach(store.filteredTrackedOrders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppLocalization.phrase(order.serviceTitle))
                                    .fontWeight(.semibold)
                                Text(order.taskID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            BadgeLabel(
                                text: order.statusCategory.title,
                                tintName: order.statusCategory.tintName
                            )
                        }

                        Text(order.question)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            if let creditsSpent = order.creditsSpent {
                                Label(AppLocalization.string("credits.unit.short", fallback: "%d cr", creditsSpent), systemImage: "creditcard")
                            }
                            Label(order.providerAlias ?? order.providerNodeID ?? AppLocalization.phrase("Provider pending"), systemImage: "person.crop.square")
                            Spacer()
                            Text(OrderFormatting.timestamp(order.lastSyncedAt ?? order.updatedAt))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(order.id)
                }
            }
        }
        .navigationTitle(store.currentSectionTitle)
        .task(id: store.selectedSection) {
            guard store.selectedSection == .orders else { return }
            await store.loadOrdersIfNeeded()
        }
    }
}

private struct OrderDetailView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if let order = store.selectedTrackedOrder {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(store.orderDetail?.serviceTitle ?? order.serviceTitle))
                        .font(.largeTitle.bold())
                    Text(store.orderDetail?.question ?? order.question)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    detailCard(AppLocalization.phrase("Order metadata"), systemImage: "list.bullet.clipboard") {
                        HStack {
                            Text(AppLocalization.phrase("Status"))
                            Spacer()
                            BadgeLabel(
                                text: store.selectedOrderStatusCategory.title,
                                tintName: store.selectedOrderStatusCategory.tintName
                            )
                        }
                        LabeledContent(AppLocalization.phrase("Task ID"), value: order.taskID)
                        LabeledContent(AppLocalization.phrase("Listing ID"), value: store.orderDetail?.listingID ?? order.listingID ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Requester node"), value: store.orderDetail?.requesterNodeID ?? order.requesterNodeID)
                        LabeledContent(AppLocalization.phrase("Provider"), value: store.orderDetail?.providerAlias ?? order.providerAlias ?? store.orderDetail?.providerNodeID ?? order.providerNodeID ?? "Pending")
                        LabeledContent(AppLocalization.phrase("Credits"), value: OrderFormatting.credits(store.orderDetail?.creditsSpent ?? order.creditsSpent))
                        LabeledContent(AppLocalization.phrase("Organism"), value: store.orderDetail?.organismID ?? order.organismID ?? AppLocalization.none)
                        LabeledContent(AppLocalization.phrase("Created"), value: OrderFormatting.timestamp(store.orderDetail?.createdAt ?? order.createdAt))
                        LabeledContent(AppLocalization.phrase("Updated"), value: OrderFormatting.timestamp(store.orderDetail?.updatedAt ?? order.updatedAt))
                        LabeledContent(AppLocalization.phrase("Last sync"), value: OrderFormatting.timestamp(order.lastSyncedAt))
                    }

                    detailCard(AppLocalization.phrase("Execution timeline"), systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                        let timeline = store.orderDetail?.timeline ?? []
                        if store.isLoadingOrderDetail {
                            ProgressView(AppLocalization.phrase("Refreshing task detail"))
                        } else if timeline.isEmpty {
                            Text(AppLocalization.phrase("The hub has not exposed a detailed timeline for this order yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(timeline) { entry in
                                HStack(alignment: .top, spacing: 12) {
                                    BadgeLabel(text: entry.stage.title, tintName: entry.stage.tintName)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(OrderFormatting.timestamp(entry.timestamp))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let detail = entry.detail {
                                            Text(AppLocalization.phrase(detail))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Provider submissions"), systemImage: "shippingbox.and.arrow.backward") {
                        let submissions = store.orderDetail?.submissions ?? []
                        if submissions.isEmpty {
                            Text(AppLocalization.phrase("No submissions have been attached to this task yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(submissions) { submission in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(AppLocalization.phrase(submission.title))
                                                .fontWeight(.semibold)
                                            if let summary = submission.summary {
                                                Text(AppLocalization.phrase(summary))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if let status = submission.status {
                                            BadgeLabel(
                                                text: OrderStatusCategory(status: status).title,
                                                tintName: OrderStatusCategory(status: status).tintName
                                            )
                                        }
                                    }

                                    if let assetID = submission.assetID {
                                        LabeledContent(AppLocalization.phrase("Asset ID"), value: assetID)
                                    }
                                    if let submittedAt = submission.submittedAt {
                                        LabeledContent(AppLocalization.phrase("Submitted"), value: OrderFormatting.timestamp(submittedAt))
                                    }
                                    if let acceptedAt = submission.acceptedAt {
                                        LabeledContent(AppLocalization.phrase("Accepted"), value: OrderFormatting.timestamp(acceptedAt))
                                    }

                                    HStack {
                                        if let assetURL = submission.assetURL,
                                           let url = URL(string: assetURL) {
                                            Link(destination: url) {
                                                Label(AppLocalization.phrase("Open Asset"), systemImage: "arrow.up.right.square")
                                            }
                                            .buttonStyle(.link)
                                        }

                                        Spacer()

                                        Button {
                                            Task {
                                                await store.acceptSelectedOrderSubmission(submission)
                                            }
                                        } label: {
                                            if store.isAcceptingSelectedOrderSubmission(submission) {
                                                ProgressView()
                                            } else {
                                                Label(AppLocalization.phrase("Accept Submission"), systemImage: "checkmark.circle")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!store.canAcceptSelectedOrderSubmission(submission))
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Final result"), systemImage: "checkmark.seal") {
                        if let assetID = store.orderDetail?.finalAssetID ?? order.finalAssetID {
                            LabeledContent(AppLocalization.phrase("Asset ID"), value: assetID)
                        } else {
                            Text(AppLocalization.phrase("No accepted final asset has been recorded yet."))
                                .foregroundStyle(.secondary)
                        }

                        if let assetTitle = store.orderDetail?.finalAssetTitle {
                            LabeledContent(AppLocalization.phrase("Title"), value: assetTitle)
                        }

                        if let assetURLString = store.orderDetail?.finalAssetURL ?? order.finalAssetURL,
                           let assetURL = URL(string: assetURLString) {
                            Link(destination: assetURL) {
                                Label(AppLocalization.phrase("Open Final Asset"), systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.link)
                        }
                    }

                    detailCard(AppLocalization.phrase("Rate this service"), systemImage: "star") {
                        LabeledContent(AppLocalization.phrase("Service"), value: AppLocalization.phrase(order.serviceTitle))
                        LabeledContent(AppLocalization.phrase("Current order status"), value: store.selectedOrderStatusCategory.title)
                        LabeledContent(
                            AppLocalization.phrase("Local rating"),
                            value: order.lastRating.map(ServiceRatingFormatting.stars) ?? AppLocalization.phrase("Not rated yet")
                        )
                        LabeledContent(AppLocalization.phrase("Rated at"), value: OrderFormatting.timestamp(order.lastRatedAt))

                        Button {
                            store.prepareServiceRatingForSelectedOrder()
                        } label: {
                            Label(AppLocalization.phrase("Rate Service"), systemImage: "star.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canPrepareServiceRatingForSelectedOrder)

                        Text(AppLocalization.phrase(store.selectedOrderServiceRatingNote))
                            .foregroundStyle(.secondary)

                        if let message = store.serviceRatingMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.serviceRatingErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    detailCard(AppLocalization.phrase("Operator note"), systemImage: "text.magnifyingglass") {
                        Text(AppLocalization.phrase(store.selectedOrderRefreshNote))
                            .foregroundStyle(.secondary)

                        if let error = store.orderDetailErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }

                        if let message = store.orderMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.orderMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(order.serviceTitle))
            .task(id: store.selectedOrderTaskID) {
                guard store.selectedSection == .orders else { return }
                await store.loadSelectedOrderDetail()
            }
        } else {
            ContentUnavailableView(
                AppLocalization.phrase("Select a tracked order"),
                systemImage: "list.bullet.clipboard",
                description: Text(AppLocalization.phrase("Orders created from this app are tracked locally and refreshed from EvoMap task detail endpoints."))
            )
        }
    }
}

private struct OrderInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.phrase("Tracking")) {
                LabeledContent(AppLocalization.phrase("Tracked tasks"), value: "\(store.trackedOrders.count)")
                LabeledContent(AppLocalization.phrase("Search query"), value: store.searchText.nonEmpty ?? AppLocalization.none)
                Text(AppLocalization.phrase(store.orderCollectionStatus))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Draft")) {
                LabeledContent(AppLocalization.phrase("Listing"), value: store.orderDraft.listingID.nonEmpty ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Requester node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                LabeledContent(AppLocalization.phrase("Estimated credits"), value: OrderFormatting.credits(store.orderDraft.estimatedCredits))
                Text(AppLocalization.phrase(store.orderDraftNote))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Rating draft")) {
                LabeledContent(AppLocalization.phrase("Listing"), value: store.serviceRatingDraft.listingID.nonEmpty ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Task"), value: store.serviceRatingDraft.taskID ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Stars"), value: ServiceRatingFormatting.stars(store.serviceRatingDraft.rating))
                Text(AppLocalization.phrase(store.serviceRatingDraftNote))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Selected order")) {
                LabeledContent(AppLocalization.phrase("Task ID"), value: store.selectedTrackedOrder?.taskID ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Status"), value: store.selectedOrderStatusCategory.title)
                LabeledContent(AppLocalization.phrase("Requester node"), value: store.orderDetail?.requesterNodeID ?? store.selectedTrackedOrder?.requesterNodeID ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Provider node"), value: store.orderDetail?.providerNodeID ?? store.selectedTrackedOrder?.providerNodeID ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Submissions"), value: "\(store.orderDetail?.submissions.count ?? 0)")
                LabeledContent(AppLocalization.phrase("Rated"), value: store.selectedTrackedOrder?.lastRating.map(ServiceRatingFormatting.stars) ?? "No")
                if let error = store.orderMutationErrorMessage ?? store.orderDetailErrorMessage {
                    Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if let message = store.orderMutationMessage {
                    Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let message = store.serviceRatingMessage {
                    Label(AppLocalization.phrase(message), systemImage: "star.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct OrderComposerSheet: View {
    @ObservedObject var store: ConsoleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.phrase("Service")) {
                    LabeledContent(AppLocalization.phrase("Title"), value: store.orderDraft.serviceTitle.nonEmpty ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Listing ID"), value: store.orderDraft.listingID.nonEmpty ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Provider"), value: store.orderDraft.providerAlias ?? store.orderDraft.providerNodeID ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Estimated credits"), value: OrderFormatting.credits(store.orderDraft.estimatedCredits))
                    if let recipeID = store.orderDraft.recipeID?.nonEmpty {
                        LabeledContent(AppLocalization.phrase("Recipe"), value: recipeID)
                    }
                    Text(store.orderDraft.serviceDescription.nonEmpty.map(AppLocalization.phrase) ?? AppLocalization.phrase("No service description is available."))
                        .foregroundStyle(.secondary)
                }

                Section(AppLocalization.phrase("Request")) {
                    TextField(AppLocalization.phrase("What should this provider do?"), text: $store.orderDraft.question, axis: .vertical)
                        .lineLimit(5...10)
                }

                Section(AppLocalization.phrase("Preview")) {
                    LabeledContent(AppLocalization.phrase("Requester node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                    LabeledContent(AppLocalization.phrase("Node auth"), value: store.selectedNode?.nodeSecretStored == true ? AppLocalization.keychainReady : AppLocalization.missingNodeSecret)
                    Text(AppLocalization.phrase(store.orderDraftNote))
                        .foregroundStyle(.secondary)

                    if let error = store.orderMutationErrorMessage {
                        Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(AppLocalization.phrase("Place Order"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("common.cancel", fallback: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await store.submitOrderDraft()
                            if store.orderMutationErrorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if store.isSubmittingOrder {
                            ProgressView()
                        } else {
                            Text(AppLocalization.phrase("Place Order"))
                        }
                    }
                    .disabled(!store.canSubmitOrderDraft)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}

private struct ServiceRatingSheet: View {
    @ObservedObject var store: ConsoleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.phrase("Completed order")) {
                    LabeledContent(AppLocalization.phrase("Service"), value: store.serviceRatingDraft.serviceTitle.nonEmpty ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Listing ID"), value: store.serviceRatingDraft.listingID.nonEmpty ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Task ID"), value: store.serviceRatingDraft.taskID ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Requester node"), value: store.selectedNode?.senderID ?? AppLocalization.chooseConnectedNode)
                }

                Section(AppLocalization.phrase("Rating")) {
                    Stepper(value: $store.serviceRatingDraft.rating, in: 1...5) {
                        LabeledContent(AppLocalization.phrase("Stars"), value: ServiceRatingFormatting.stars(store.serviceRatingDraft.rating))
                    }
                    TextField(AppLocalization.phrase("Optional comment"), text: $store.serviceRatingDraft.comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(AppLocalization.phrase("Preview")) {
                    Text(AppLocalization.phrase(store.serviceRatingDraftNote))
                        .foregroundStyle(.secondary)

                    if let error = store.serviceRatingErrorMessage {
                        Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(AppLocalization.phrase("Rate Service"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.string("common.cancel", fallback: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await store.submitServiceRating()
                            if store.serviceRatingErrorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if store.isSubmittingServiceRating {
                            ProgressView()
                        } else {
                            Text(AppLocalization.phrase("Submit Rating"))
                        }
                    }
                    .disabled(!store.canSubmitServiceRating)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 420)
    }
}

private struct GraphWorkspaceListView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(spacing: 0) {
            Picker(AppLocalization.phrase("Graph workspace"), selection: Binding(
                get: { store.graphWorkspaceMode },
                set: { store.setGraphWorkspaceMode($0) }
            )) {
                ForEach(GraphWorkspaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            switch store.graphWorkspaceMode {
            case .myGraph:
                List(selection: Binding(
                    get: { store.selectedKnowledgeGraphNodeID },
                    set: { store.selectKnowledgeGraphNode($0) }
                )) {
                    Section {
                        Text(AppLocalization.phrase(store.knowledgeGraphSnapshotCollectionStatus))
                            .font(.footnote)
                            .foregroundStyle(store.knowledgeGraphSnapshotErrorMessage == nil ? Color.secondary : Color.orange)
                    }

                    Section {
                        ForEach(store.filteredKnowledgeGraphNodes) { node in
                            KnowledgeGraphNodeRow(node: node, edgeCount: edgeCount(for: node))
                                .tag(node.id)
                        }
                    }
                }
            case .search:
                List(selection: Binding(
                    get: { store.selectedKnowledgeGraphSearchNodeID },
                    set: { store.selectKnowledgeGraphSearchNode($0) }
                )) {
                    Section {
                        Text(AppLocalization.phrase(store.knowledgeGraphSearchCollectionStatus))
                            .font(.footnote)
                            .foregroundStyle(store.knowledgeGraphSearchErrorMessage == nil ? Color.secondary : Color.orange)
                    }

                    if let result = store.knowledgeGraphSearchResult, result.clusters.isEmpty == false {
                        Section(AppLocalization.phrase("Clusters")) {
                            ForEach(result.clusters) { cluster in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cluster.label ?? "Cluster \(cluster.clusterID)")
                                        .fontWeight(.semibold)
                                    Text("\(cluster.memberCount) member(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let summary = cluster.summary {
                                        Text(AppLocalization.phrase(summary))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section(AppLocalization.phrase("Matched nodes")) {
                        if store.filteredKnowledgeGraphSearchNodes.isEmpty {
                            Text(AppLocalization.phrase(store.knowledgeGraphQueryText.nonEmpty == nil ? "No query has been submitted yet." : "No nodes matched the latest query."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.filteredKnowledgeGraphSearchNodes) { node in
                                KnowledgeGraphNodeRow(node: node, edgeCount: searchEdgeCount(for: node))
                                    .tag(node.id)
                            }
                        }
                    }
                }
            case .manage:
                List {
                    Section(AppLocalization.phrase("Write status")) {
                        Text(AppLocalization.phrase(store.knowledgeGraphMutationNote))
                            .foregroundStyle(.secondary)

                        if let message = store.knowledgeGraphMutationMessage {
                            Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let error = store.knowledgeGraphMutationErrorMessage {
                            Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    Section(AppLocalization.phrase("Entity draft")) {
                        LabeledContent(AppLocalization.phrase("Name"), value: store.knowledgeGraphEntityDraft.name.nonEmpty ?? AppLocalization.none)
                        LabeledContent(AppLocalization.phrase("Type"), value: store.knowledgeGraphEntityDraft.type.title)
                        Text(store.knowledgeGraphEntityDraft.description.nonEmpty.map(AppLocalization.phrase) ?? AppLocalization.phrase("No entity description yet."))
                            .foregroundStyle(.secondary)
                    }

                    Section(AppLocalization.phrase("Relationship draft")) {
                        LabeledContent(AppLocalization.phrase("Source"), value: store.knowledgeGraphRelationshipDraft.sourceName.nonEmpty ?? AppLocalization.none)
                        LabeledContent(AppLocalization.phrase("Relation"), value: store.knowledgeGraphRelationshipDraft.relationType.title)
                        LabeledContent(AppLocalization.phrase("Target"), value: store.knowledgeGraphRelationshipDraft.targetName.nonEmpty ?? AppLocalization.none)
                    }
                }
            }
        }
        .navigationTitle(store.currentSectionTitle)
        .task(id: store.selectedSection) {
            guard store.selectedSection == .graph else { return }
            await store.loadKnowledgeGraphStatusIfNeeded()
            await store.loadKnowledgeGraphCurrentWorkspaceIfNeeded()
        }
    }

    private func edgeCount(for node: KnowledgeGraphNode) -> Int {
        (store.knowledgeGraphSnapshot?.edges ?? []).filter {
            $0.sourceID == node.nodeID || $0.targetID == node.nodeID
        }.count
    }

    private func searchEdgeCount(for node: KnowledgeGraphNode) -> Int {
        (store.knowledgeGraphSearchResult?.edges ?? []).filter {
            $0.sourceID == node.nodeID || $0.targetID == node.nodeID
        }.count
    }
}

private struct GraphWorkspaceDetailView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        switch store.graphWorkspaceMode {
        case .myGraph:
            graphDetail(selectedNode: store.selectedKnowledgeGraphNode, edges: store.selectedKnowledgeGraphEdges)
        case .search:
            graphSearchDetail
        case .manage:
            graphManageDetail
        }
    }

    @ViewBuilder
    private func graphDetail(selectedNode: KnowledgeGraphNode?, edges: [KnowledgeGraphEdge]) -> some View {
        if let blocker = store.knowledgeGraphAccessBlocker {
            ContentUnavailableView(
                AppLocalization.phrase("Save a KG API key"),
                systemImage: "key.horizontal",
                description: Text(AppLocalization.phrase(blocker))
            )
        } else if let node = selectedNode {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(AppLocalization.phrase(node.name))
                        .font(.largeTitle.bold())
                    Text(node.description.map(AppLocalization.phrase) ?? AppLocalization.phrase("No description was returned for this graph node."))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    knowledgeGraphStatusCard

                    detailCard(AppLocalization.phrase("Node metadata"), systemImage: "point.3.connected.trianglepath.dotted") {
                        LabeledContent(AppLocalization.phrase("Node ID"), value: node.nodeID)
                        LabeledContent(AppLocalization.phrase("Type"), value: node.type ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Group"), value: node.group ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Score"), value: node.score.map { String(format: "%.2f", $0) } ?? AppLocalization.unknown)
                        LabeledContent(AppLocalization.phrase("Related edges"), value: "\(edges.count)")
                    }

                    detailCard(AppLocalization.phrase("Relationships"), systemImage: "arrow.triangle.branch") {
                        if edges.isEmpty {
                            Text(AppLocalization.phrase("No relationships were returned for this node in the latest graph snapshot."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(edges) { edge in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(edge.relation.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.headline)
                                    Text("\(edge.sourceLabel ?? edge.sourceID) -> \(edge.targetLabel ?? edge.targetID)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if edge.properties.isEmpty == false {
                                        Text(edge.properties.prefix(3).map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Properties"), systemImage: "list.bullet.rectangle") {
                        if node.properties.isEmpty {
                            Text(AppLocalization.phrase("No additional properties were returned for this node."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(node.properties) { property in
                                LabeledContent(property.key, value: property.value)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle(AppLocalization.phrase(node.name))
            .task(id: store.graphWorkspaceMode) {
                guard store.selectedSection == .graph, store.graphWorkspaceMode == .myGraph else { return }
                await store.loadKnowledgeGraphStatusIfNeeded()
                await store.loadKnowledgeGraphMyGraphIfNeeded()
            }
        } else {
            ContentUnavailableView(
                AppLocalization.phrase("Select a graph node"),
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text(AppLocalization.phrase("Load `My Graph` to inspect the entities, assets, and relationships aggregated from your EvoMap activity."))
            )
        }
    }

    private var graphSearchDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppLocalization.phrase("Semantic Search"))
                    .font(.largeTitle.bold())
                Text(AppLocalization.phrase("Run natural-language queries against your personal EvoMap knowledge graph. Results can include matched entities, semantic clusters, and a recommended execution sequence."))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                knowledgeGraphStatusCard

                detailCard(AppLocalization.phrase("Query"), systemImage: "magnifyingglass") {
                    TextField(AppLocalization.phrase("Ask the graph a natural-language question"), text: $store.knowledgeGraphQueryText, axis: .vertical)
                        .lineLimit(2...4)

                    HStack {
                        Button {
                            Task {
                                await store.runKnowledgeGraphQuery()
                            }
                        } label: {
                            Label(
                                AppLocalization.phrase(store.isSearchingKnowledgeGraph ? "Searching" : "Run Query"),
                                systemImage: "magnifyingglass.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canRunKnowledgeGraphQuery)

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalization.phrase("Examples"))
                            .font(.headline)
                        ForEach(graphQueryExamples, id: \.self) { example in
                            Button(example) {
                                store.knowledgeGraphQueryText = example
                            }
                            .buttonStyle(.link)
                        }
                    }

                    Text(AppLocalization.phrase(store.knowledgeGraphSearchCollectionStatus))
                        .foregroundStyle(.secondary)
                }

                if let result = store.knowledgeGraphSearchResult {
                    detailCard(AppLocalization.phrase("Search summary"), systemImage: "square.grid.3x1.folder.fill.badge.plus") {
                        LabeledContent(AppLocalization.phrase("Matched nodes"), value: "\(result.nodes.count)")
                        LabeledContent(AppLocalization.phrase("Clusters"), value: "\(result.clusters.count)")
                        LabeledContent(AppLocalization.phrase("Recommended sequence"), value: "\(result.recommendedSequence.count)")
                        if result.properties.isEmpty == false {
                            ForEach(result.properties.prefix(6)) { property in
                                LabeledContent(property.key, value: property.value)
                            }
                        }
                    }

                    detailCard(AppLocalization.phrase("Recommended execution sequence"), systemImage: "list.number") {
                        if result.recommendedSequence.isEmpty {
                            Text(AppLocalization.phrase("The latest query did not return a recommended sequence."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(result.recommendedSequence.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sequenceLabel(for: item, in: result))
                                            .font(.body.weight(.semibold))
                                        Text(item)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if let node = store.selectedKnowledgeGraphSearchNode {
                        detailCard(AppLocalization.phrase("Selected node"), systemImage: "target") {
                            LabeledContent(AppLocalization.phrase("Node"), value: AppLocalization.phrase(node.name))
                            LabeledContent(AppLocalization.phrase("Type"), value: node.type ?? AppLocalization.unknown)
                            LabeledContent(AppLocalization.phrase("Group"), value: node.group ?? AppLocalization.unknown)
                            LabeledContent(AppLocalization.phrase("Score"), value: node.score.map { String(format: "%.2f", $0) } ?? AppLocalization.unknown)
                            if let description = node.description {
                                Text(AppLocalization.phrase(description))
                                    .foregroundStyle(.secondary)
                            }
                            if node.properties.isEmpty == false {
                                ForEach(node.properties.prefix(8)) { property in
                                    LabeledContent(property.key, value: property.value)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(AppLocalization.phrase("Graph Search"))
        .task(id: store.graphWorkspaceMode) {
            guard store.selectedSection == .graph else { return }
            await store.loadKnowledgeGraphStatusIfNeeded()
        }
    }

    private var graphManageDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppLocalization.phrase("Manage Graph"))
                    .font(.largeTitle.bold())
                Text(AppLocalization.phrase("Create manual entity and relationship drafts for your Neo4j-backed personal knowledge graph. The current payload shape is kept tolerant because the public docs confirm `/kg/ingest` but do not show a full schema example."))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                knowledgeGraphStatusCard

                detailCard(AppLocalization.phrase("Entity draft"), systemImage: "square.text.square") {
                    TextField(AppLocalization.phrase("Entity name"), text: $store.knowledgeGraphEntityDraft.name)
                    Picker(AppLocalization.phrase("Type"), selection: $store.knowledgeGraphEntityDraft.type) {
                        ForEach(KnowledgeGraphEntityType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField(AppLocalization.phrase("Description"), text: $store.knowledgeGraphEntityDraft.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                detailCard(AppLocalization.phrase("Relationship draft"), systemImage: "arrow.left.and.right.square") {
                    TextField(AppLocalization.phrase("Source entity name"), text: $store.knowledgeGraphRelationshipDraft.sourceName)
                    Picker(AppLocalization.phrase("Relation"), selection: $store.knowledgeGraphRelationshipDraft.relationType) {
                        ForEach(KnowledgeGraphRelationType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField(AppLocalization.phrase("Target entity name"), text: $store.knowledgeGraphRelationshipDraft.targetName)
                }

                detailCard(AppLocalization.phrase("Write preview"), systemImage: "shippingbox.circle") {
                    Text(AppLocalization.phrase(store.knowledgeGraphMutationNote))
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await store.submitKnowledgeGraphIngest()
                        }
                    } label: {
                        Label(
                            AppLocalization.phrase(store.isSubmittingKnowledgeGraphIngest ? "Writing Draft" : "Write Draft"),
                            systemImage: "square.and.arrow.down.on.square"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canSubmitKnowledgeGraphIngest)

                    if let message = store.knowledgeGraphMutationMessage {
                        Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if let error = store.knowledgeGraphMutationErrorMessage {
                        Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(AppLocalization.phrase("Graph Manage"))
        .task(id: store.graphWorkspaceMode) {
            guard store.selectedSection == .graph else { return }
            await store.loadKnowledgeGraphStatusIfNeeded()
        }
    }

    @ViewBuilder
    private var knowledgeGraphStatusCard: some View {
        detailCard(AppLocalization.phrase("Access & Pricing"), systemImage: "key.horizontal") {
            LabeledContent(AppLocalization.phrase("Hub"), value: ConsoleAppSettings.hubBaseURL)
            LabeledContent(AppLocalization.phrase("Key storage"), value: ConsoleAppSettings.kgAPIKey.isEmpty ? AppLocalization.missing : AppLocalization.keychainReady)
            LabeledContent(AppLocalization.phrase("Plan"), value: store.knowledgeGraphStatus?.planName ?? AppLocalization.unknown)
            LabeledContent(AppLocalization.phrase("Status"), value: store.knowledgeGraphStatus?.accessStatus ?? AppLocalization.unknown)
            LabeledContent(AppLocalization.phrase("Query price"), value: store.knowledgeGraphStatus?.queryPriceCredits.map(GraphFormatting.credits) ?? AppLocalization.unknown)
            LabeledContent(AppLocalization.phrase("Write price"), value: store.knowledgeGraphStatus?.ingestPriceCredits.map(GraphFormatting.credits) ?? AppLocalization.unknown)
            LabeledContent(AppLocalization.phrase("Query rate"), value: store.knowledgeGraphStatus?.queryRateLimitPerMinute.map { "\($0)/min" } ?? AppLocalization.unknown)
            LabeledContent(AppLocalization.phrase("Write rate"), value: store.knowledgeGraphStatus?.ingestRateLimitPerMinute.map { "\($0)/min" } ?? AppLocalization.unknown)
            Text(AppLocalization.phrase(store.knowledgeGraphStatusNote))
                .foregroundStyle(.secondary)
            if let error = store.knowledgeGraphStatusErrorMessage {
                Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private let graphQueryExamples = [
        "认证中间件是怎么工作的？",
        "查找本周推广的资产",
        "哪些代理的 GDI 最高？",
        "展示胶囊的知识血缘",
    ]

    private func sequenceLabel(for item: String, in result: KnowledgeGraphSearchResult) -> String {
        result.nodes.first(where: { $0.nodeID == item || $0.name == item })?.name ?? item
    }
}

private struct GraphInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.phrase("Access")) {
                LabeledContent(AppLocalization.phrase("Workspace"), value: store.graphWorkspaceMode.title)
                LabeledContent(AppLocalization.phrase("Hub"), value: ConsoleAppSettings.hubBaseURL)
                LabeledContent(AppLocalization.phrase("API key"), value: ConsoleAppSettings.kgAPIKey.isEmpty ? AppLocalization.missing : AppLocalization.keychainReady)
                LabeledContent(AppLocalization.phrase("Plan"), value: store.knowledgeGraphStatus?.planName ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Status"), value: store.knowledgeGraphStatus?.accessStatus ?? AppLocalization.unknown)
                Text(AppLocalization.phrase(store.knowledgeGraphStatusNote))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Usage")) {
                LabeledContent(AppLocalization.phrase("Queries"), value: store.knowledgeGraphStatus?.queryCount.map(String.init) ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Writes"), value: store.knowledgeGraphStatus?.ingestCount.map(String.init) ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Credits used"), value: store.knowledgeGraphStatus?.creditsUsed.map(GraphFormatting.credits) ?? AppLocalization.unknown)
                if let error = store.knowledgeGraphStatusErrorMessage ?? store.knowledgeGraphSearchErrorMessage ?? store.knowledgeGraphSnapshotErrorMessage {
                    Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section(AppLocalization.phrase("Search")) {
                LabeledContent(AppLocalization.phrase("Query"), value: store.knowledgeGraphQueryText.nonEmpty ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Results"), value: "\(store.knowledgeGraphSearchResult?.nodes.count ?? 0)")
                LabeledContent(AppLocalization.phrase("Clusters"), value: "\(store.knowledgeGraphSearchResult?.clusters.count ?? 0)")
                Text(AppLocalization.phrase(store.knowledgeGraphSearchCollectionStatus))
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalization.phrase("Selected node")) {
                LabeledContent(AppLocalization.phrase("Node"), value: store.selectedKnowledgeGraphDetailNode?.name ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("ID"), value: store.selectedKnowledgeGraphDetailNode?.nodeID ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Type"), value: store.selectedKnowledgeGraphDetailNode?.type ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Group"), value: store.selectedKnowledgeGraphDetailNode?.group ?? AppLocalization.unknown)
                LabeledContent(AppLocalization.phrase("Edges"), value: "\(store.selectedKnowledgeGraphEdges.count)")
            }

            Section(AppLocalization.phrase("Drafts")) {
                LabeledContent(AppLocalization.phrase("Entity"), value: store.knowledgeGraphEntityDraft.name.nonEmpty ?? AppLocalization.none)
                LabeledContent(AppLocalization.phrase("Relationship"), value: store.knowledgeGraphRelationshipDraft.sourceName.nonEmpty ?? AppLocalization.none)
                Text(AppLocalization.phrase(store.knowledgeGraphMutationNote))
                    .foregroundStyle(.secondary)
                if let message = store.knowledgeGraphMutationMessage {
                    Label(AppLocalization.phrase(message), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let error = store.knowledgeGraphMutationErrorMessage {
                    Label(AppLocalization.phrase(error), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct KnowledgeGraphNodeRow: View {
    let node: KnowledgeGraphNode
    let edgeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.phrase(node.name))
                        .fontWeight(.semibold)
                    Text(node.nodeID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let group = node.group {
                    BadgeLabel(text: group.capitalized, tintName: GraphFormatting.groupTint(group))
                }
            }

            if let description = node.description {
                Text(AppLocalization.phrase(description))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Text(node.type.map { AppLocalization.phrase($0.capitalized) } ?? AppLocalization.phrase("Unknown type"))
                Text(AppLocalization.string("graph.edge.count", fallback: "%d edge(s)", edgeCount))
                if let score = node.score {
                    Text(AppLocalization.string("graph.score", fallback: "Score %.2f", score))
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private enum ServiceFormatting {
    static func percent(_ value: Double?) -> String {
        guard let value else { return AppLocalization.unknown }
        let percent = value <= 1 ? value * 100 : value
        return String(format: "%.0f%%", percent)
    }

    static func rating(_ value: Double?) -> String {
        guard let value else { return AppLocalization.unknown }
        return String(format: "%.1f", value)
    }

    static func integer(_ value: Int?) -> String {
        value.map(String.init) ?? AppLocalization.unknown
    }
}

private enum ServiceRatingFormatting {
    static func stars(_ value: Int) -> String {
        let normalized = min(max(value, 1), 5)
        return String(repeating: "★", count: normalized) + String(repeating: "☆", count: 5 - normalized)
    }
}

private enum OrderFormatting {
    static func timestamp(_ value: Date?) -> String {
        value?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown
    }

    static func credits(_ value: Int?) -> String {
        value.map { AppLocalization.string("credits.unit.count", fallback: "%d credits", $0) } ?? AppLocalization.unknown
    }
}

private enum GraphFormatting {
    static func credits(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return AppLocalization.string("credits.unit.count", fallback: "%d credits", Int(value))
        }
        return AppLocalization.string("credits.unit.double", fallback: "%.2f credits", value)
    }

    static func groupTint(_ value: String) -> String {
        switch normalized(value) {
        case "knowledgeentity", "entity", "concept", "tool", "technique", "pattern":
            return "purple"
        case "platformasset", "asset", "gene", "capsule":
            return "blue"
        case "agent", "agentnode", "node":
            return "orange"
        default:
            return "secondary"
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct ComingSoonCollectionView: View {
    let section: ConsoleSection

    var body: some View {
        List {
            Label(section.title, systemImage: section.systemImage)
                .font(.headline)
            Text(AppLocalization.phrase("This module stays deferred while the v1 node, skill, service, and order flows are being proven."))
                .foregroundStyle(.secondary)
        }
        .navigationTitle(section.title)
    }
}

private struct ComingSoonDetailView: View {
    let section: ConsoleSection

    var body: some View {
        ContentUnavailableView(
            AppLocalization.string("placeholder.arrives_later", fallback: "%@ arrives later", section.title),
            systemImage: section.systemImage,
            description: Text(AppLocalization.phrase("Keep the first release focused. This area stays intentionally deferred while the main console shell is being proven."))
        )
    }
}

private struct OverviewInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        List {
            Section(AppLocalization.string("overview.inspector.snapshot", fallback: "Snapshot")) {
                LabeledContent(
                    AppLocalization.string("overview.inspector.last_refresh", fallback: "Last refresh"),
                    value: store.lastRefreshAt.formatted(date: .abbreviated, time: .shortened)
                )
                LabeledContent(AppLocalization.string("overview.inspector.selected_module", fallback: "Selected module"), value: store.currentSectionTitle)
            }
            Section(AppLocalization.string("overview.inspector.next_build_focus", fallback: "Next build focus")) {
                Text(AppLocalization.string(
                    "overview.inspector.next_build_focus.body",
                    fallback: "Live node handshake, authenticated heartbeat polling, local SKILL.md import, official Skill Store publish/update, public remote browsing, authenticated download-to-library, visibility control, rollback, delete-version, recycle-bin management, official Services marketplace browsing/publish/update/archive, local-first tracked service ordering, and direct `/kg/*` graph access are wired. Activity remains the main placeholder."
                ))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NodeInspectorView: View {
    let node: NodeRecord?

    var body: some View {
        if let node {
            List {
                Section(AppLocalization.phrase("Identifiers")) {
                    LabeledContent(AppLocalization.phrase("Node ID"), value: node.id.uuidString)
                    LabeledContent(AppLocalization.phrase("Sender ID"), value: node.senderID)
                    LabeledContent(AppLocalization.phrase("Referral"), value: node.referralCode ?? AppLocalization.none)
                }

                Section(AppLocalization.phrase("Connection")) {
                    LabeledContent(AppLocalization.phrase("Base URL"), value: node.apiBaseURL)
                    LabeledContent(AppLocalization.phrase("Environment"), value: node.environment.title)
                    LabeledContent(AppLocalization.phrase("Model"), value: node.modelName)
                    LabeledContent(AppLocalization.phrase("Genes"), value: "\(node.geneCount)")
                    LabeledContent(AppLocalization.phrase("Capsules"), value: "\(node.capsuleCount)")
                    LabeledContent(AppLocalization.phrase("Heartbeat"), value: node.heartbeat.title)
                    LabeledContent(AppLocalization.phrase("Cadence"), value: node.recommendedHeartbeatIntervalMS.map(heartbeatCadenceLabel(milliseconds:)) ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Claim URL"), value: node.claimURL ?? AppLocalization.none)
                    LabeledContent(AppLocalization.phrase("Node secret"), value: node.nodeSecretStored ? AppLocalization.stored : AppLocalization.missing)
                }

                Section(AppLocalization.phrase("Heartbeat snapshot")) {
                    LabeledContent(AppLocalization.phrase("Dispatch"), value: "\(node.dispatchCount)")
                    LabeledContent(AppLocalization.phrase("Pending events"), value: "\(node.pendingEventCount)")
                    LabeledContent(AppLocalization.phrase("Peers"), value: "\(node.peerCount)")
                    LabeledContent(AppLocalization.phrase("Overdue"), value: "\(node.overdueTaskCount)")
                    LabeledContent(
                        AppLocalization.phrase("Next heartbeat"),
                        value: node.heartbeatSnapshot?.nextHeartbeatAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.phrase("Not scheduled")
                    )
                }

                if let accountability = node.heartbeatSnapshot?.accountability {
                    Section(AppLocalization.phrase("Accountability")) {
                        LabeledContent(AppLocalization.phrase("Penalty"), value: "\(accountability.reputationPenalty)")
                        LabeledContent(AppLocalization.phrase("Quarantine"), value: "\(accountability.quarantineStrikes)")
                        LabeledContent(
                            AppLocalization.phrase("Cooldown"),
                            value: accountability.publishCooldownUntil?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.none
                        )
                        if let recommendation = accountability.recommendation {
                            Text(AppLocalization.phrase(recommendation))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let skillStore = node.skillStoreStatus {
                    Section(AppLocalization.phrase("Skill Store")) {
                        LabeledContent(AppLocalization.phrase("Eligible"), value: skillStore.eligible ? AppLocalization.yes : AppLocalization.no)
                        LabeledContent(AppLocalization.phrase("Published skills"), value: "\(skillStore.publishedSkillCount)")
                        LabeledContent(AppLocalization.phrase("Publish endpoint"), value: skillStore.publishEndpoint ?? AppLocalization.unknown)
                        if let hint = skillStore.hint {
                            Text(AppLocalization.phrase(hint))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(AppLocalization.phrase("Raw payload preview")) {
                    Text(verbatim: payloadPreview(for: node))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        } else {
            Text(AppLocalization.phrase("No node selected"))
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func payloadPreview(for node: NodeRecord) -> String {
        let nextHeartbeat = node.heartbeatSnapshot?.nextHeartbeatAt?.formatted(date: .abbreviated, time: .shortened)
        return """
        {
          "sender_id": "\(node.senderID)",
          "base_url": "\(node.apiBaseURL)",
          "environment": "\(node.environment.rawValue)",
          "model": "\(node.modelName)",
          "gene_count": \(node.geneCount),
          "capsule_count": \(node.capsuleCount),
          "dispatch": \(node.dispatchCount),
          "pending_events": \(node.pendingEventCount),
          "peers": \(node.peerCount),
          "next_heartbeat": \(nextHeartbeat.map { "\"\($0)\"" } ?? "null"),
          "claim_code": \(node.claimCode.map { "\"\($0)\"" } ?? "null"),
          "survival_status": \(node.survivalStatus.map { "\"\($0)\"" } ?? "null")
        }
        """
    }

    private func heartbeatCadenceLabel(milliseconds: Int) -> String {
        let seconds = max(milliseconds / 1000, 1)
        if seconds < 60 {
            return "Every \(seconds)s"
        }
        return "Every \(max(seconds / 60, 1))m"
    }
}

private struct SkillInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if let skill = store.selectedSkill {
            List {
                Section(AppLocalization.phrase("Limits")) {
                    LabeledContent(AppLocalization.phrase("Characters"), value: "\(skill.localCharacterCount)/50000")
                    LabeledContent(AppLocalization.phrase("Bundled files"), value: "\(skill.bundledFileCount)/10")
                    LabeledContent(AppLocalization.phrase("Included bundle chars"), value: "\(skill.bundledCharacterCount)")
                    LabeledContent(AppLocalization.phrase("Errors"), value: "\(skill.errorCount)")
                    LabeledContent(AppLocalization.phrase("Warnings"), value: "\(skill.warningCount)")
                }

                Section(AppLocalization.phrase("Publisher")) {
                    LabeledContent(AppLocalization.phrase("Sender ID"), value: store.selectedNode?.senderID ?? "node_preview")
                    LabeledContent(AppLocalization.phrase("Node secret"), value: store.selectedNode?.nodeSecretStored == true ? AppLocalization.stored : AppLocalization.missing)
                    LabeledContent(AppLocalization.phrase("Skill Store"), value: skillStoreLabel(for: store.selectedNode))
                    LabeledContent(AppLocalization.phrase("Action"), value: store.skillPublishActionTitle)
                    LabeledContent(AppLocalization.phrase("Remote status"), value: skill.remoteStatus ?? AppLocalization.phrase("Local only"))
                    LabeledContent(
                        AppLocalization.phrase("Last sync"),
                        value: skill.lastPublishedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.phrase("Never")
                    )
                    LabeledContent(AppLocalization.phrase("Store snapshot"), value: skill.storeSnapshotVersion ?? AppLocalization.none)
                    LabeledContent(
                        AppLocalization.phrase("Downloaded"),
                        value: skill.downloadedFromStoreAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.phrase("Not yet")
                    )
                    LabeledContent(AppLocalization.phrase("Managed folder"), value: skill.downloadedStoreDirectoryPath ?? AppLocalization.phrase("External file"))
                    LabeledContent(
                        AppLocalization.phrase("Download cost"),
                        value: skill.downloadedCreditCost.map { AppLocalization.string("credits.unit.count", fallback: "%d credits", $0) } ?? AppLocalization.unknown
                    )
                }

                Section(AppLocalization.phrase("Publish")) {
                    Button {
                        Task {
                            await store.publishSelectedSkill()
                        }
                    } label: {
                        Label(
                            AppLocalization.phrase(store.isPublishingSelectedSkill ? "Publishing" : store.skillPublishActionTitle),
                            systemImage: store.isPublishingSelectedSkill
                                ? "arrow.trianglehead.2.clockwise.rotate.90"
                                : "paperplane.fill"
                        )
                    }
                    .disabled(!store.canPublishSelectedSkill)

                    Text(AppLocalization.phrase(store.selectedSkillPublishNote))
                        .foregroundStyle(.secondary)
                }

                Section(AppLocalization.phrase("Tags")) {
                    ForEach(skill.tags, id: \.self) { tag in
                        Text(tag)
                    }
                }

                Section(AppLocalization.phrase("Live request preview")) {
                    Text(verbatim: payloadPreview(for: skill))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        } else {
            Text(AppLocalization.phrase("No skill selected"))
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func payloadPreview(for skill: SkillRecord) -> String {
        skill.publishPayloadPreview(
            senderID: store.selectedNode?.senderID,
            changelog: skill.remoteVersion == nil ? nil : ConsoleStore.defaultSkillUpdateChangelog
        )
    }

    private func skillStoreLabel(for node: NodeRecord?) -> String {
        guard let node else { return AppLocalization.phrase("No publisher selected") }
        guard let status = node.skillStoreStatus else {
            return node.nodeSecretStored ? AppLocalization.phrase("Awaiting heartbeat data") : AppLocalization.phrase("Missing auth")
        }
        return status.eligible ? AppLocalization.phrase("Eligible") : AppLocalization.phrase("Not eligible")
    }
}

private struct RemoteSkillInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if let skill = store.selectedRemoteSkillSummary {
            List {
                Section(AppLocalization.phrase("Feed")) {
                    LabeledContent(AppLocalization.phrase("Remote skills"), value: "\(store.filteredRemoteSkills.count)")
                    LabeledContent(AppLocalization.phrase("Total published"), value: "\(store.remoteSkillTotalCount)")
                    LabeledContent(AppLocalization.phrase("Store enabled"), value: store.remoteSkillStoreEnabled ? AppLocalization.yes : AppLocalization.no)
                    LabeledContent(AppLocalization.phrase("Loading"), value: store.isLoadingRemoteSkills || store.isLoadingRemoteSkillDetail ? AppLocalization.yes : AppLocalization.no)
                }

                Section(AppLocalization.phrase("Selected skill")) {
                    LabeledContent(AppLocalization.phrase("Skill ID"), value: skill.skillId)
                    LabeledContent(AppLocalization.phrase("Version"), value: store.remoteSkillDetail?.version ?? skill.version)
                    LabeledContent(AppLocalization.phrase("Downloads"), value: "\(store.remoteSkillDetail?.downloadCount ?? skill.downloadCount)")
                    LabeledContent(AppLocalization.phrase("Review"), value: store.remoteSkillDetail?.reviewStatus ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Versions"), value: "\(store.remoteSkillVersions.count)")
                }

                Section(AppLocalization.phrase("Download")) {
                    LabeledContent(AppLocalization.phrase("Node"), value: store.selectedNode?.senderID ?? "No node selected")
                    LabeledContent(AppLocalization.phrase("Ready"), value: store.canDownloadSelectedRemoteSkill ? AppLocalization.yes : AppLocalization.no)
                    if let message = store.remoteSkillDownloadMessage {
                        Text(AppLocalization.phrase(message))
                            .foregroundStyle(.secondary)
                    } else if let error = store.remoteSkillDownloadErrorMessage {
                        Text(AppLocalization.phrase(error))
                            .foregroundStyle(.orange)
                    } else {
                        Text(AppLocalization.phrase(store.selectedRemoteSkillDownloadNote))
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppLocalization.phrase("Management")) {
                    LabeledContent(AppLocalization.phrase("Author"), value: store.selectedRemoteSkillAuthorNodeID ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Visibility"), value: store.selectedRemoteSkillVisibility.capitalized)
                    LabeledContent(AppLocalization.phrase("Visibility ready"), value: store.canUpdateSelectedRemoteSkillVisibility ? AppLocalization.yes : AppLocalization.no)
                    LabeledContent(AppLocalization.phrase("Rollback ready"), value: store.canRollbackSelectedRemoteSkill ? AppLocalization.yes : AppLocalization.no)
                    LabeledContent(AppLocalization.phrase("Delete ready"), value: store.canDeleteSelectedRemoteSkill ? AppLocalization.yes : AppLocalization.no)
                    LabeledContent(AppLocalization.phrase("Rollback target"), value: store.remoteSkillRollbackTargetVersion ?? AppLocalization.none)
                    if let message = store.remoteSkillMutationMessage {
                        Text(AppLocalization.phrase(message))
                            .foregroundStyle(.secondary)
                    } else if let error = store.remoteSkillMutationErrorMessage {
                        Text(AppLocalization.phrase(error))
                            .foregroundStyle(.orange)
                    } else {
                        Text(AppLocalization.phrase(store.selectedRemoteSkillRollbackNote))
                            .foregroundStyle(.secondary)
                    }
                }

                if let strategy = store.remoteSkillDetail?.strategy ?? skill.strategy, strategy.isEmpty == false {
                    Section(AppLocalization.phrase("Strategy")) {
                        ForEach(Array(strategy.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                        }
                    }
                }

                Section(AppLocalization.phrase("Preview")) {
                    Text(verbatim: store.remoteSkillDetail?.contentPreview ?? skill.contentPreview ?? AppLocalization.phrase("No preview text returned."))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        } else {
            Text(AppLocalization.phrase("No remote skill selected"))
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

private struct RecycledSkillInspectorView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        if let skill = store.selectedRecycledSkill {
            List {
                Section(AppLocalization.phrase("Recycle bin")) {
                    LabeledContent(AppLocalization.phrase("Entries"), value: "\(store.filteredRecycledSkills.count)")
                    LabeledContent(AppLocalization.phrase("Total"), value: "\(store.recycledSkillTotalCount)")
                    LabeledContent(AppLocalization.phrase("Loading"), value: store.isLoadingRecycledSkills ? AppLocalization.yes : AppLocalization.no)
                }

                Section(AppLocalization.phrase("Selected skill")) {
                    LabeledContent(AppLocalization.phrase("Skill ID"), value: skill.skillId)
                    LabeledContent(AppLocalization.phrase("Version"), value: skill.version ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Deleted"), value: skill.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Original visibility"), value: skill.originalVisibility.map { AppLocalization.phrase($0.capitalized) } ?? AppLocalization.unknown)
                    LabeledContent(AppLocalization.phrase("Author"), value: skill.author?.nodeId ?? AppLocalization.unknown)
                }

                Section(AppLocalization.phrase("Actions")) {
                    LabeledContent(AppLocalization.phrase("Restore ready"), value: store.canRestoreSelectedRecycledSkill ? AppLocalization.yes : AppLocalization.no)
                    LabeledContent(AppLocalization.phrase("Permanent delete ready"), value: store.canPermanentlyDeleteSelectedRecycledSkill ? AppLocalization.yes : AppLocalization.no)
                    if let message = store.remoteSkillMutationMessage {
                        Text(AppLocalization.phrase(message))
                            .foregroundStyle(.secondary)
                    } else if let error = store.remoteSkillMutationErrorMessage {
                        Text(AppLocalization.phrase(error))
                            .foregroundStyle(.orange)
                    } else {
                        Text(AppLocalization.phrase(store.selectedRecycledSkillRestoreNote))
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppLocalization.phrase("Tags")) {
                    if skill.tags.isEmpty {
                        Text(AppLocalization.phrase("No tags"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(skill.tags, id: \.self) { tag in
                            Text(tag)
                        }
                    }
                }
            }
        } else {
            Text(AppLocalization.phrase("No recycled skill selected"))
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

private struct PlaceholderInspectorView: View {
    let section: ConsoleSection

    var body: some View {
        List {
            Section(AppLocalization.phrase("Later module")) {
                Text(AppLocalization.string("placeholder.out_of_scope", fallback: "%@ is intentionally out of scope for the first slice.", section.title))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BadgeLabel: View {
    let text: String
    let tintName: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundTint, in: Capsule())
            .foregroundStyle(foregroundTint)
    }

    private var backgroundTint: Color {
        switch tintName {
        case "blue":
            return .blue.opacity(0.16)
        case "green":
            return .green.opacity(0.16)
        case "orange":
            return .orange.opacity(0.16)
        case "purple":
            return .purple.opacity(0.16)
        case "red":
            return .red.opacity(0.16)
        default:
            return .secondary.opacity(0.14)
        }
    }

    private var foregroundTint: Color {
        switch tintName {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "red":
            return .red
        default:
            return .secondary
        }
    }
}

private struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

private struct ChecklistRow: View {
    let title: String
    let detail: String
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(AppLocalization.phrase(detail))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private func detailCard<Content: View>(
    _ title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Label(title, systemImage: systemImage)
            .font(.headline)
        content()
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
}

#Preview {
    ContentView(store: ConsoleStore())
        .frame(width: 1380, height: 880)
}
