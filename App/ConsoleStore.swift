import AppKit
import CryptoKit
import Foundation

private struct ShellCommandResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32

    var combinedOutput: String {
        [stdout.nonEmpty, stderr.nonEmpty]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}

@MainActor
final class ConsoleStore: ObservableObject {
    static let defaultSkillUpdateChangelog = "Iterative evolution update"

    @Published var nodeConnectionDraft = NodeConnectionDraft(
        editingNodeID: nil,
        nodeName: ConsoleAppSettings.defaultNodeName,
        senderID: "node_preview",
        baseURL: ConsoleAppSettings.hubBaseURL,
        environment: .production,
        modelName: ConsoleAppSettings.defaultNodeModel,
        geneCount: 0,
        capsuleCount: 0,
        referrer: "",
        identityDoc: ConsoleAppSettings.defaultIdentityDoc,
        constitution: ConsoleAppSettings.defaultConstitution
    )
    @Published var isPresentingNodeConnectionSheet = false
    @Published var isPresentingSkillImporter = false
    @Published var isPresentingServiceComposer = false
    @Published var isPresentingOrderComposer = false
    @Published var isPresentingServiceRatingComposer = false
    @Published var graphWorkspaceMode: GraphWorkspaceMode = .myGraph
    @Published var isConnectingNode = false
    @Published var isRefreshingNodeHeartbeat = false
    @Published private(set) var isRefreshingOrders = false
    @Published private(set) var activeSkillPublishID: SkillRecord.ID?
    @Published private(set) var activeRemoteSkillDownloadID: String?
    @Published private(set) var activeRemoteSkillVisibilityID: String?
    @Published private(set) var activeRemoteSkillRollbackID: String?
    @Published private(set) var activeRemoteSkillVersionDeleteKey: String?
    @Published private(set) var activeRemoteSkillDeleteID: String?
    @Published private(set) var activeServiceStatusListingID: String?
    @Published private(set) var activeServiceArchiveListingID: String?
    @Published private(set) var isSubmittingServiceDraft = false
    @Published private(set) var isSubmittingServiceRating = false
    @Published private(set) var isSubmittingOrder = false
    @Published private(set) var activeOrderAcceptanceKey: String?
    @Published private(set) var activeRecycledSkillRestoreID: String?
    @Published private(set) var activeRecycledSkillPermanentDeleteID: String?
    @Published var nodeConnectionErrorMessage: String?
    @Published var skillImportErrorMessage: String?
    @Published var remoteSkillDownloadMessage: String?
    @Published var remoteSkillDownloadErrorMessage: String?
    @Published var remoteSkillMutationMessage: String?
    @Published var remoteSkillMutationErrorMessage: String?
    @Published var serviceMutationMessage: String?
    @Published var serviceMutationErrorMessage: String?
    @Published var serviceRatingMessage: String?
    @Published var serviceRatingErrorMessage: String?
    @Published var orderMutationMessage: String?
    @Published var orderMutationErrorMessage: String?
    @Published var selectedSection: ConsoleSection = .nodes {
        didSet {
            if selectedSection != oldValue {
                searchText = ""
            }
        }
    }
    @Published var skillWorkspaceMode: SkillWorkspaceMode = .local
    @Published var selectedNodeID: NodeRecord.ID?
    @Published var selectedSkillID: SkillRecord.ID?
    @Published var selectedRemoteSkillID: String?
    @Published var selectedRecycledSkillID: String?
    @Published var selectedServiceID: String?
    @Published var selectedOrderTaskID: String?
    @Published var selectedKnowledgeGraphNodeID: String?
    @Published var selectedKnowledgeGraphSearchNodeID: String?
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            remoteSkillSearchTask?.cancel()
            serviceSearchTask?.cancel()
            switch selectedSection {
            case .skills where skillWorkspaceMode == .store:
                scheduleRemoteSkillSearchIfNeeded()
            case .services:
                scheduleServiceSearchIfNeeded()
            default:
                break
            }
        }
    }
    @Published var isInspectorPresented = true
    @Published private(set) var lastRefreshAt = Date()
    @Published private(set) var isLoadingRemoteSkills = false
    @Published private(set) var isLoadingRemoteSkillDetail = false
    @Published private(set) var isLoadingRecycledSkills = false
    @Published private(set) var isLoadingServices = false
    @Published private(set) var isLoadingServiceDetail = false
    @Published private(set) var isLoadingServiceRatings = false
    @Published private(set) var isLoadingOrderDetail = false
    @Published private(set) var isLoadingKnowledgeGraphStatus = false
    @Published private(set) var isLoadingKnowledgeGraphSnapshot = false
    @Published private(set) var isSearchingKnowledgeGraph = false
    @Published private(set) var isSubmittingKnowledgeGraphIngest = false
    @Published private(set) var isLoadingAccountBalance = false
    @Published private(set) var isLoadingBountyTasks = false
    @Published private(set) var isLoadingClaimedBountyTasks = false
    @Published private(set) var isSubmittingBountyAnswer = false
    @Published private(set) var activeBountyClaimTaskID: String?
    @Published private(set) var activeBountySubmissionTaskID: String?
    @Published var bountyShowsAllLoadedTasks = false {
        didSet {
            guard bountyShowsAllLoadedTasks != oldValue else { return }
            selectedBountyTaskID = preferredBountySelectionID()
        }
    }
    @Published private(set) var locallyClosedBountyTaskIDs: Set<EvoMapBountyTask.ID> = []
    @Published var remoteSkillLoadErrorMessage: String?
    @Published var remoteSkillDetailErrorMessage: String?
    @Published var recycledSkillLoadErrorMessage: String?
    @Published var serviceLoadErrorMessage: String?
    @Published var serviceDetailErrorMessage: String?
    @Published var serviceRatingsErrorMessage: String?
    @Published var orderLoadErrorMessage: String?
    @Published var orderDetailErrorMessage: String?
    @Published var knowledgeGraphStatusErrorMessage: String?
    @Published var knowledgeGraphSnapshotErrorMessage: String?
    @Published var knowledgeGraphSearchErrorMessage: String?
    @Published var knowledgeGraphMutationMessage: String?
    @Published var knowledgeGraphMutationErrorMessage: String?
    @Published private(set) var accountBalanceMessage: String?
    @Published private(set) var accountBalanceErrorMessage: String?
    @Published private(set) var bountyTaskMessage: String?
    @Published private(set) var bountyTaskErrorMessage: String?
    @Published private(set) var bountyAnswerDraftMessage: String?
    @Published private(set) var bountyAnswerDraftErrorMessage: String?
    @Published private(set) var bountyExecutionMessage: String?
    @Published private(set) var bountyAutopilotMessage: String?
    @Published private(set) var bountyAutopilotErrorMessage: String?
    @Published private(set) var bountyAutopilotLiveOutput: String = ""
    @Published private(set) var patchCourierBackendMessage: String?
    @Published private(set) var patchCourierBackendErrorMessage: String?
    @Published private(set) var isSendingPatchCourierBackendTask = false
    @Published private(set) var isCheckingPatchCourierBackendInbox = false
    @Published private(set) var isPatchCourierBackendPolling = false
    @Published private(set) var isRunningBountyAutopilot = false
    @Published private(set) var isCancellingBountyAutopilot = false
    @Published private(set) var isImportingBountyAutopilotHistory = false
    private var bountyAutopilotTask: Task<Void, Never>?
    @Published var nodes: [NodeRecord]
    @Published var skills: [SkillRecord]
    @Published private(set) var remoteSkills: [RemoteSkillSummary] = []
    @Published private(set) var remoteSkillDetail: RemoteSkillDetail?
    @Published private(set) var remoteSkillVersions: [RemoteSkillVersion] = []
    @Published private(set) var recycledSkills: [RecycledSkillSummary] = []
    @Published private(set) var services: [RemoteServiceSummary] = []
    @Published private(set) var serviceDetail: RemoteServiceDetail?
    @Published private(set) var serviceRatings: [RemoteServiceRating] = []
    @Published private(set) var trackedOrders: [TrackedServiceOrder] = []
    @Published private(set) var orderDetail: RemoteOrderDetail?
    @Published private(set) var knowledgeGraphStatus: KnowledgeGraphStatusSnapshot?
    @Published private(set) var knowledgeGraphSnapshot: KnowledgeGraphSnapshot?
    @Published private(set) var knowledgeGraphSearchResult: KnowledgeGraphSearchResult?
    @Published private(set) var accountBalanceSnapshot: EvoMapAccountBalanceResponse?
    @Published private(set) var bountyTasks: [EvoMapBountyTask] = []
    @Published private(set) var claimedBountyTasks: [EvoMapClaimedBountyTask] = []
    @Published private(set) var bountyTaskTotalCount: Int?
    @Published private(set) var bountyTaskOpenCount: Int?
    @Published private(set) var bountyTaskMatchedCount: Int?
    @Published private(set) var bountyTaskCurrentPage = 0
    @Published private(set) var followedBountyTaskIDs: Set<String> = ConsoleStore.loadFollowedBountyTaskIDs()
    @Published var selectedBountyTaskID: String? {
        didSet {
            guard selectedBountyTaskID != oldValue else { return }
            loadSelectedBountyAnswerDraft()
        }
    }
    @Published var bountyAnswerDraft = BountyAnswerDraft.empty
    @Published var bountyExecutionProvider: BountyExecutionProvider = .openClaw
    @Published var bountyAutopilotAutoSubmit = false
    @Published var bountyAutopilotUseNativeEngine = true
    @Published private(set) var bountyAutopilotRuns: [BountyAutopilotRun] = ConsoleStore.loadBountyAutopilotRuns()
    @Published var selectedBountyAutopilotRunID: BountyAutopilotRun.ID?
    @Published private(set) var remoteSkillStoreEnabled = true
    @Published private(set) var remoteSkillTotalCount = 0
    @Published private(set) var remoteSkillTotalDownloads = 0
    @Published private(set) var recycledSkillTotalCount = 0
    @Published var remoteSkillRollbackTargetVersion: String?
    @Published var serviceDraft = ServiceDraft.empty
    @Published var serviceRatingDraft = ServiceRatingDraft.empty
    @Published var orderDraft = OrderDraft.empty
    @Published var knowledgeGraphQueryText = ""
    @Published var knowledgeGraphEntityDraft = KnowledgeGraphEntityDraft.empty
    @Published var knowledgeGraphRelationshipDraft = KnowledgeGraphRelationshipDraft.empty

    private let client: EvoMapClientProtocol
    private let nodeSecretStore: NodeSecretStoring
    private let skillImportService: SkillImportService
    private let skillWorkspaceStore: SkillWorkspacePersisting
    private let orderWorkspaceStore: OrderWorkspacePersisting
    private let nodeWorkspaceStore: NodeWorkspacePersisting
    private let patchCourierMailPasswordStore: PatchCourierMailPasswordStoring
    private let patchCourierMailTransportClient: PatchCourierMailTransportClient
    private var remoteSkillSearchTask: Task<Void, Never>?
    private var serviceSearchTask: Task<Void, Never>?
    private var patchCourierBackendPollTask: Task<Void, Never>?
    private var nodeHeartbeatCooldownUntil: [NodeRecord.ID: Date] = [:]

    private static let minimumManualHeartbeatInterval: TimeInterval = 60
    private static let rateLimitHeartbeatBackoff: TimeInterval = 120
    private static let bountyTaskPageSize = 50
    private static let followedBountyTaskIDsKey = "workspace.followedBountyTaskIDs"
    private static let bountyAnswerDraftsKey = "workspace.bountyAnswerDrafts"
    private static let bountyAutopilotRunsKey = "workspace.bountyAutopilotRuns"

    init(
        nodes: [NodeRecord] = SampleData.nodes,
        skills: [SkillRecord] = SampleData.skills,
        client: EvoMapClientProtocol = EvoMapClient(),
        nodeSecretStore: NodeSecretStoring = KeychainNodeSecretStore(),
        skillImportService: SkillImportService = SkillImportService(),
        skillWorkspaceStore: SkillWorkspacePersisting = LocalSkillWorkspaceStore(),
        orderWorkspaceStore: OrderWorkspacePersisting = LocalOrderWorkspaceStore(),
        nodeWorkspaceStore: NodeWorkspacePersisting = LocalNodeWorkspaceStore(),
        patchCourierMailPasswordStore: PatchCourierMailPasswordStoring = KeychainPatchCourierMailPasswordStore(),
        patchCourierMailTransportClient: PatchCourierMailTransportClient = PatchCourierMailTransportClient()
    ) {
        self.client = client
        self.nodeSecretStore = nodeSecretStore
        self.skillImportService = skillImportService
        self.skillWorkspaceStore = skillWorkspaceStore
        self.orderWorkspaceStore = orderWorkspaceStore
        self.nodeWorkspaceStore = nodeWorkspaceStore
        self.patchCourierMailPasswordStore = patchCourierMailPasswordStore
        self.patchCourierMailTransportClient = patchCourierMailTransportClient

        let initialNodes: [NodeRecord]
        let nodeLoadErrorMessage: String?
        let storedSenderIDs = (try? nodeSecretStore.listStoredSenderIDs()) ?? []
        do {
            let persistedNodes = try nodeWorkspaceStore.loadNodes()
            let recoveredNodes = Self.recoveredKeychainNodes(
                from: storedSenderIDs,
                excluding: persistedNodes + nodes
            )
            initialNodes = Self.mergePersistedNodes(
                persistedNodes + recoveredNodes,
                withFallbackNodes: nodes
            )
            nodeLoadErrorMessage = nil
        } catch {
            let recoveredNodes = Self.recoveredKeychainNodes(
                from: storedSenderIDs,
                excluding: nodes
            )
            initialNodes = Self.mergePersistedNodes(recoveredNodes, withFallbackNodes: nodes)
            nodeLoadErrorMessage = error.localizedDescription
        }

        self.nodes = initialNodes
        self.skills = skills
        self.selectedNodeID = Self.displayNodes(from: initialNodes).first?.id
        self.selectedSkillID = skills.first?.id
        self.nodeConnectionErrorMessage = nodeLoadErrorMessage

        do {
            let storedOrders = try orderWorkspaceStore.loadTrackedOrders()
            trackedOrders = storedOrders.sorted(by: Self.sortOrders(lhs:rhs:))
            selectedOrderTaskID = trackedOrders.first?.taskID
        } catch {
            trackedOrders = []
            orderLoadErrorMessage = error.localizedDescription
        }

        refreshStoredSecretFlags()
    }

    deinit {
        remoteSkillSearchTask?.cancel()
        serviceSearchTask?.cancel()
        patchCourierBackendPollTask?.cancel()
    }

    var currentSectionTitle: String {
        selectedSection.title
    }

    var searchPrompt: String {
        selectedSection.searchPrompt
    }

    var visibleNodes: [NodeRecord] {
        Self.displayNodes(from: nodes)
    }

    private static func displayNodes(from nodes: [NodeRecord]) -> [NodeRecord] {
        let liveNodes = nodes.filter { $0.isSampleData == false }
        return liveNodes.isEmpty ? nodes : liveNodes
    }

    private static func mergePersistedNodes(
        _ persistedNodes: [NodeRecord],
        withFallbackNodes fallbackNodes: [NodeRecord]
    ) -> [NodeRecord] {
        guard persistedNodes.isEmpty == false else {
            return fallbackNodes
        }

        let persistedIDs = Set(persistedNodes.map(\.id))
        let persistedSenderIDs = Set(persistedNodes.map(\.senderID))
        let additionalLiveNodes = fallbackNodes.filter { node in
            node.isSampleData == false
                && persistedIDs.contains(node.id) == false
                && persistedSenderIDs.contains(node.senderID) == false
        }
        let sampleNodes = fallbackNodes.filter(\.isSampleData)
        return persistedNodes + additionalLiveNodes + sampleNodes
    }

    private static func recoveredKeychainNodes(
        from senderIDs: [String],
        excluding knownNodes: [NodeRecord]
    ) -> [NodeRecord] {
        let knownSenderIDs = Set(knownNodes.map(\.senderID))
        var seenSenderIDs = Set<String>()

        return senderIDs.compactMap { rawSenderID in
            guard let senderID = rawSenderID.nonEmpty,
                  knownSenderIDs.contains(senderID) == false,
                  seenSenderIDs.insert(senderID).inserted else {
                return nil
            }

            let recoveredAt = Date()
            return NodeRecord(
                id: UUID(),
                name: AppLocalization.string("node.recovered.name", fallback: "Recovered node"),
                senderID: senderID,
                apiBaseURL: ConsoleAppSettings.hubBaseURL,
                environment: .production,
                modelName: ConsoleAppSettings.defaultNodeModel,
                geneCount: 0,
                capsuleCount: 0,
                claimState: .pending,
                heartbeat: .warning,
                lastSeen: recoveredAt,
                onlineWorkers: 0,
                creditBalance: 0,
                claimCode: nil,
                claimURL: nil,
                referralCode: nil,
                survivalStatus: nil,
                nodeSecretStored: true,
                lastErrorMessage: nil,
                notes: AppLocalization.string(
                    "node.recovered.note",
                    fallback: "Recovered from a Keychain node_secret. Run heartbeat to refresh official state before creating another node."
                ),
                recentEvents: [
                    NodeEvent(
                        timestamp: recoveredAt,
                        title: "Recovered from Keychain",
                        detail: "A stored node_secret was found for this sender ID, so the app restored a local node instead of asking you to create a new one.",
                        titleKey: "node.event.recovered_keychain.title",
                        detailKey: "node.event.recovered_keychain.detail"
                    )
                ],
                recommendedHeartbeatIntervalMS: nil,
                heartbeatEndpoint: nil,
                heartbeatSnapshot: nil,
                isSampleData: false
            )
        }
    }

    var filteredNodes: [NodeRecord] {
        let source = visibleNodes
        guard !searchText.isEmpty else { return source }
        let query = searchText.normalizedSearchKey
        return source.filter {
            $0.name.normalizedSearchKey.contains(query)
                || $0.senderID.normalizedSearchKey.contains(query)
                || $0.apiBaseURL.normalizedSearchKey.contains(query)
                || $0.environment.title.normalizedSearchKey.contains(query)
                || $0.claimState.title.normalizedSearchKey.contains(query)
                || $0.modelName.normalizedSearchKey.contains(query)
        }
    }

    var filteredSkills: [SkillRecord] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.normalizedSearchKey
        return skills.filter {
            $0.name.normalizedSearchKey.contains(query)
                || $0.skillID.normalizedSearchKey.contains(query)
                || $0.category.title.normalizedSearchKey.contains(query)
                || $0.summary.normalizedSearchKey.contains(query)
                || $0.tags.joined(separator: " ").normalizedSearchKey.contains(query)
        }
    }

    var filteredRemoteSkills: [RemoteSkillSummary] {
        guard !searchText.isEmpty else { return remoteSkills }
        let query = searchText.normalizedSearchKey
        return remoteSkills.filter {
            $0.name.normalizedSearchKey.contains(query)
                || $0.skillId.normalizedSearchKey.contains(query)
                || $0.description.normalizedSearchKey.contains(query)
                || ($0.category?.normalizedSearchKey.contains(query) ?? false)
                || $0.tags.joined(separator: " ").normalizedSearchKey.contains(query)
        }
    }

    var filteredRecycledSkills: [RecycledSkillSummary] {
        guard !searchText.isEmpty else { return recycledSkills }
        let query = searchText.normalizedSearchKey
        return recycledSkills.filter {
            $0.name.normalizedSearchKey.contains(query)
                || $0.skillId.normalizedSearchKey.contains(query)
                || ($0.description?.normalizedSearchKey.contains(query) ?? false)
                || ($0.category?.normalizedSearchKey.contains(query) ?? false)
                || $0.tags.joined(separator: " ").normalizedSearchKey.contains(query)
        }
    }

    var filteredServices: [RemoteServiceSummary] {
        guard !searchText.isEmpty else { return services }
        let query = searchText.normalizedSearchKey
        return services.filter {
            $0.title.normalizedSearchKey.contains(query)
                || $0.listingID.normalizedSearchKey.contains(query)
                || $0.description.normalizedSearchKey.contains(query)
                || $0.capabilities.joined(separator: " ").normalizedSearchKey.contains(query)
                || $0.useCases.joined(separator: " ").normalizedSearchKey.contains(query)
                || ($0.providerNodeID?.normalizedSearchKey.contains(query) ?? false)
                || ($0.providerAlias?.normalizedSearchKey.contains(query) ?? false)
        }
    }

    var filteredTrackedOrders: [TrackedServiceOrder] {
        let source = trackedOrders.sorted(by: Self.sortOrders(lhs:rhs:))
        guard !searchText.isEmpty else { return source }
        let query = searchText.normalizedSearchKey
        return source.filter {
            $0.serviceTitle.normalizedSearchKey.contains(query)
                || $0.taskID.normalizedSearchKey.contains(query)
                || $0.question.normalizedSearchKey.contains(query)
                || ($0.providerNodeID?.normalizedSearchKey.contains(query) ?? false)
                || ($0.providerAlias?.normalizedSearchKey.contains(query) ?? false)
                || ($0.requesterNodeID.normalizedSearchKey.contains(query))
        }
    }

    var filteredKnowledgeGraphNodes: [KnowledgeGraphNode] {
        let source = knowledgeGraphSnapshot?.nodes ?? []
        guard !searchText.isEmpty else { return source }
        let query = searchText.normalizedSearchKey
        return source.filter { node in
            node.name.normalizedSearchKey.contains(query)
                || node.nodeID.normalizedSearchKey.contains(query)
                || (node.type?.normalizedSearchKey.contains(query) ?? false)
                || (node.group?.normalizedSearchKey.contains(query) ?? false)
                || (node.description?.normalizedSearchKey.contains(query) ?? false)
                || node.properties.contains { property in
                    property.key.normalizedSearchKey.contains(query)
                        || property.value.normalizedSearchKey.contains(query)
                }
        }
    }

    var filteredKnowledgeGraphSearchNodes: [KnowledgeGraphNode] {
        let source = knowledgeGraphSearchResult?.nodes ?? []
        guard !searchText.isEmpty else { return source }
        let query = searchText.normalizedSearchKey
        return source.filter { node in
            node.name.normalizedSearchKey.contains(query)
                || node.nodeID.normalizedSearchKey.contains(query)
                || (node.type?.normalizedSearchKey.contains(query) ?? false)
                || (node.group?.normalizedSearchKey.contains(query) ?? false)
                || (node.description?.normalizedSearchKey.contains(query) ?? false)
                || node.properties.contains { property in
                    property.key.normalizedSearchKey.contains(query)
                        || property.value.normalizedSearchKey.contains(query)
                }
        }
    }

    var selectedNode: NodeRecord? {
        let source = filteredNodes.isEmpty ? visibleNodes : filteredNodes
        guard let selectedNodeID else { return source.first }
        return source.first(where: { $0.id == selectedNodeID }) ?? source.first
    }

    var selectedSkill: SkillRecord? {
        let source = filteredSkills.isEmpty ? skills : filteredSkills
        guard let selectedSkillID else { return source.first }
        return source.first(where: { $0.id == selectedSkillID }) ?? skills.first(where: { $0.id == selectedSkillID })
    }

    var selectedRemoteSkillSummary: RemoteSkillSummary? {
        let source = filteredRemoteSkills.isEmpty ? remoteSkills : filteredRemoteSkills
        guard let selectedRemoteSkillID else { return source.first }
        return source.first(where: { $0.id == selectedRemoteSkillID }) ?? remoteSkills.first(where: { $0.id == selectedRemoteSkillID })
    }

    var selectedRecycledSkill: RecycledSkillSummary? {
        let source = filteredRecycledSkills.isEmpty ? recycledSkills : filteredRecycledSkills
        guard let selectedRecycledSkillID else { return source.first }
        return source.first(where: { $0.id == selectedRecycledSkillID }) ?? recycledSkills.first(where: { $0.id == selectedRecycledSkillID })
    }

    var selectedServiceSummary: RemoteServiceSummary? {
        let source = filteredServices.isEmpty ? services : filteredServices
        guard let selectedServiceID else { return source.first }
        return source.first(where: { $0.id == selectedServiceID }) ?? services.first(where: { $0.id == selectedServiceID })
    }

    var selectedTrackedOrder: TrackedServiceOrder? {
        let source = filteredTrackedOrders.isEmpty ? trackedOrders : filteredTrackedOrders
        guard let selectedOrderTaskID else { return source.first }
        return source.first(where: { $0.id == selectedOrderTaskID }) ?? trackedOrders.first(where: { $0.id == selectedOrderTaskID })
    }

    var selectedKnowledgeGraphNode: KnowledgeGraphNode? {
        let source = filteredKnowledgeGraphNodes.isEmpty ? (knowledgeGraphSnapshot?.nodes ?? []) : filteredKnowledgeGraphNodes
        guard let selectedKnowledgeGraphNodeID else { return source.first }
        return source.first(where: { $0.id == selectedKnowledgeGraphNodeID })
            ?? knowledgeGraphSnapshot?.nodes.first(where: { $0.id == selectedKnowledgeGraphNodeID })
    }

    var selectedKnowledgeGraphSearchNode: KnowledgeGraphNode? {
        let source = filteredKnowledgeGraphSearchNodes.isEmpty ? (knowledgeGraphSearchResult?.nodes ?? []) : filteredKnowledgeGraphSearchNodes
        guard let selectedKnowledgeGraphSearchNodeID else { return source.first }
        return source.first(where: { $0.id == selectedKnowledgeGraphSearchNodeID })
            ?? knowledgeGraphSearchResult?.nodes.first(where: { $0.id == selectedKnowledgeGraphSearchNodeID })
    }

    var selectedKnowledgeGraphDetailNode: KnowledgeGraphNode? {
        switch graphWorkspaceMode {
        case .myGraph:
            return selectedKnowledgeGraphNode
        case .search:
            return selectedKnowledgeGraphSearchNode
        case .manage:
            return nil
        }
    }

    var selectedKnowledgeGraphEdges: [KnowledgeGraphEdge] {
        guard let node = selectedKnowledgeGraphDetailNode else { return [] }

        let edges: [KnowledgeGraphEdge]
        switch graphWorkspaceMode {
        case .myGraph:
            edges = knowledgeGraphSnapshot?.edges ?? []
        case .search:
            edges = knowledgeGraphSearchResult?.edges ?? []
        case .manage:
            edges = []
        }

        return edges.filter { edge in
            edge.sourceID == node.nodeID || edge.targetID == node.nodeID
        }
    }

    var primaryActionTitle: String {
        switch selectedSection {
        case .overview:
            return AppLocalization.string("primary.refresh_overview", fallback: "Refresh Overview")
        case .nodes:
            return AppLocalization.string("primary.connect_node", fallback: "Connect Node")
        case .credits:
            return creditSprintPrimaryTitle
        case .bounties:
            return AppLocalization.string("primary.refresh_bounties", fallback: "Refresh Bounties")
        case .skills:
            switch skillWorkspaceMode {
            case .local:
                return AppLocalization.string("primary.import_skill", fallback: "Import Skill")
            case .store:
                return AppLocalization.string("primary.refresh_store", fallback: "Refresh Store")
            case .recycleBin:
                return AppLocalization.string("primary.refresh_bin", fallback: "Refresh Bin")
            }
        case .services:
            return AppLocalization.string("primary.new_service", fallback: "New Service")
        case .orders:
            return AppLocalization.string("primary.sync_orders", fallback: "Sync Orders")
        case .graph:
            switch graphWorkspaceMode {
            case .myGraph:
                return AppLocalization.string("primary.refresh_graph", fallback: "Refresh Graph")
            case .search:
                return AppLocalization.string("primary.run_query", fallback: "Run Query")
            case .manage:
                return AppLocalization.string("primary.write_draft", fallback: "Write Draft")
            }
        case .activity:
            return AppLocalization.string("primary.learn_more", fallback: "Learn More")
        }
    }

    var isPublishingSkill: Bool {
        activeSkillPublishID != nil
    }

    var isPublishingSelectedSkill: Bool {
        guard let activeSkillPublishID else { return false }
        return activeSkillPublishID == selectedSkillID
    }

    var isDownloadingSelectedRemoteSkill: Bool {
        guard let activeRemoteSkillDownloadID else { return false }
        return activeRemoteSkillDownloadID == selectedRemoteSkillID
    }

    var isUpdatingSelectedRemoteSkillVisibility: Bool {
        guard let activeRemoteSkillVisibilityID else { return false }
        return activeRemoteSkillVisibilityID == selectedRemoteSkillID
    }

    var isRollingBackSelectedRemoteSkill: Bool {
        guard let activeRemoteSkillRollbackID else { return false }
        return activeRemoteSkillRollbackID == selectedRemoteSkillID
    }

    var isDeletingSelectedRemoteSkill: Bool {
        guard let activeRemoteSkillDeleteID else { return false }
        return activeRemoteSkillDeleteID == selectedRemoteSkillID
    }

    var isUpdatingSelectedServiceStatus: Bool {
        guard let activeServiceStatusListingID else { return false }
        return activeServiceStatusListingID == selectedServiceID
    }

    var isArchivingSelectedService: Bool {
        guard let activeServiceArchiveListingID else { return false }
        return activeServiceArchiveListingID == selectedServiceID
    }

    var isRestoringSelectedRecycledSkill: Bool {
        guard let activeRecycledSkillRestoreID else { return false }
        return activeRecycledSkillRestoreID == selectedRecycledSkillID
    }

    var isPermanentlyDeletingSelectedRecycledSkill: Bool {
        guard let activeRecycledSkillPermanentDeleteID else { return false }
        return activeRecycledSkillPermanentDeleteID == selectedRecycledSkillID
    }

    var skillPublishActionTitle: String {
        guard let skill = selectedSkill else {
            return AppLocalization.string("skill.action.publish", fallback: "Publish Skill")
        }
        return skill.remoteVersion == nil
            ? AppLocalization.string("skill.action.publish", fallback: "Publish Skill")
            : AppLocalization.string("skill.action.update", fallback: "Update Skill")
    }

    var canPublishSelectedSkill: Bool {
        skillWorkspaceMode == .local && activeSkillPublishID == nil && selectedSkillPublishPrerequisiteBlocker == nil
    }

    var canDownloadSelectedRemoteSkill: Bool {
        skillWorkspaceMode == .store && activeRemoteSkillDownloadID == nil && selectedRemoteSkillDownloadPrerequisiteBlocker == nil
    }

    var canUpdateSelectedRemoteSkillVisibility: Bool {
        skillWorkspaceMode == .store
            && activeRemoteSkillVisibilityID == nil
            && activeRemoteSkillRollbackID == nil
            && activeRemoteSkillVersionDeleteKey == nil
            && selectedRemoteSkillVisibilityPrerequisiteBlocker == nil
    }

    var canRollbackSelectedRemoteSkill: Bool {
        skillWorkspaceMode == .store
            && activeRemoteSkillVisibilityID == nil
            && activeRemoteSkillRollbackID == nil
            && activeRemoteSkillVersionDeleteKey == nil
            && selectedRemoteSkillRollbackPrerequisiteBlocker == nil
    }

    var canDeleteSelectedRemoteSkill: Bool {
        skillWorkspaceMode == .store
            && activeRemoteSkillDeleteID == nil
            && activeRemoteSkillVisibilityID == nil
            && activeRemoteSkillRollbackID == nil
            && activeRemoteSkillVersionDeleteKey == nil
            && selectedRemoteSkillDeletePrerequisiteBlocker == nil
    }

    var canRestoreSelectedRecycledSkill: Bool {
        skillWorkspaceMode == .recycleBin
            && activeRecycledSkillRestoreID == nil
            && activeRecycledSkillPermanentDeleteID == nil
            && selectedRecycledSkillRestorePrerequisiteBlocker == nil
    }

    var canPermanentlyDeleteSelectedRecycledSkill: Bool {
        skillWorkspaceMode == .recycleBin
            && activeRecycledSkillRestoreID == nil
            && activeRecycledSkillPermanentDeleteID == nil
            && selectedRecycledSkillPermanentDeletePrerequisiteBlocker == nil
    }

    var canSubmitServiceDraft: Bool {
        !isSubmittingServiceDraft && serviceDraftSubmitPrerequisiteBlocker == nil
    }

    var canSubmitServiceRating: Bool {
        !isSubmittingServiceRating && serviceRatingSubmitPrerequisiteBlocker == nil
    }

    var canEditSelectedService: Bool {
        selectedServiceManagementPrerequisiteBlocker == nil
    }

    var canToggleSelectedServiceStatus: Bool {
        activeServiceStatusListingID == nil
            && activeServiceArchiveListingID == nil
            && selectedServiceStatusPrerequisiteBlocker == nil
    }

    var canArchiveSelectedService: Bool {
        activeServiceArchiveListingID == nil
            && activeServiceStatusListingID == nil
            && selectedServiceArchivePrerequisiteBlocker == nil
    }

    var canCreateOrderFromSelectedService: Bool {
        selectedServiceOrderPrerequisiteBlocker == nil
    }

    var canSubmitOrderDraft: Bool {
        !isSubmittingOrder && orderDraftSubmitPrerequisiteBlocker == nil
    }

    var canPrepareServiceRatingForSelectedOrder: Bool {
        selectedOrderServiceRatingPrerequisiteBlocker == nil
    }

    var canRunKnowledgeGraphQuery: Bool {
        !isSearchingKnowledgeGraph
            && knowledgeGraphAccessBlocker == nil
            && knowledgeGraphQueryText.nonEmpty != nil
    }

    var canSubmitKnowledgeGraphIngest: Bool {
        !isSubmittingKnowledgeGraphIngest
            && knowledgeGraphIngestPrerequisiteBlocker == nil
    }

    var selectedSkillPublishNote: String {
        if isPublishingSelectedSkill {
            return AppLocalization.phrase("Waiting for the EvoMap Skill Store response from the live publish request.")
        }
        if let blocker = selectedSkillPublishPrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedSkill, let node = selectedNode else {
            return AppLocalization.phrase("Select a skill and a connected node to start publishing.")
        }
        let endpoint = skill.remoteVersion == nil
            ? "/a2a/skill/store/publish"
            : "/a2a/skill/store/update"
        return AppLocalization.string(
            "note.call_with_keychain_node_secret",
            fallback: "Uses %@ to call `%@` with the Keychain-backed node_secret.",
            node.senderID,
            endpoint
        )
    }

    var selectedRemoteSkillDownloadNote: String {
        if isDownloadingSelectedRemoteSkill {
            return "Downloading the full `SKILL.md` bundle from the live EvoMap Skill Store."
        }
        if let blocker = selectedRemoteSkillDownloadPrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a remote skill and an authenticated node before downloading.")
        }
        return AppLocalization.string(
            "note.remote_skill_download_call",
            fallback: "Uses %@ to call `/a2a/skill/store/%@/download` and saves the files into Application Support.",
            node.senderID,
            skill.skillId
        )
    }

    var selectedRemoteSkillVisibilityActionTitle: String {
        selectedRemoteSkillVisibility.lowercased() == "private"
            ? AppLocalization.phrase("Make Public")
            : AppLocalization.phrase("Make Private")
    }

    var selectedRemoteSkillVisibilityNote: String {
        if isUpdatingSelectedRemoteSkillVisibility {
            return "Updating the Skill Store visibility on the live EvoMap hub."
        }
        if let blocker = selectedRemoteSkillVisibilityPrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a remote skill and an authenticated node before changing visibility.")
        }
        let nextVisibility = selectedRemoteSkillTargetVisibility
        return AppLocalization.string(
            "note.remote_skill_visibility_call",
            fallback: "Uses %@ to call `/a2a/skill/store/visibility` and set `%@` to `%@`.",
            node.senderID,
            skill.skillId,
            nextVisibility
        )
    }

    var selectedRemoteSkillRollbackNote: String {
        if isRollingBackSelectedRemoteSkill {
            return "Rolling the published Skill back to an earlier version on the live EvoMap hub."
        }
        if let blocker = selectedRemoteSkillRollbackPrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode,
              let targetVersion = remoteSkillRollbackTargetVersion else {
            return AppLocalization.phrase("Select a remote skill, an authenticated node, and a rollback target version.")
        }
        return AppLocalization.string(
            "note.remote_skill_rollback_call",
            fallback: "Uses %@ to call `/a2a/skill/store/rollback` and move `%@` back to `%@`.",
            node.senderID,
            skill.skillId,
            targetVersion
        )
    }

    var selectedRemoteSkillDeleteNote: String {
        if isDeletingSelectedRemoteSkill {
            return "Soft-deleting the Skill and moving it into the recycle bin."
        }
        if let blocker = selectedRemoteSkillDeletePrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a remote skill and an authenticated node before deleting.")
        }
        return AppLocalization.string(
            "note.remote_skill_delete_call",
            fallback: "Uses %@ to call `/a2a/skill/store/delete` and move `%@` into the recycle bin.",
            node.senderID,
            skill.skillId
        )
    }

    var selectedRecycledSkillRestoreNote: String {
        if isRestoringSelectedRecycledSkill {
            return "Restoring the Skill from the recycle bin on the live EvoMap hub."
        }
        if let blocker = selectedRecycledSkillRestorePrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRecycledSkill,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a recycled skill and an authenticated node before restoring.")
        }
        return AppLocalization.string(
            "note.recycled_skill_restore_call",
            fallback: "Uses %@ to call `/a2a/skill/store/restore` for `%@`. Official docs say restored Skills return as `private`.",
            node.senderID,
            skill.skillId
        )
    }

    var selectedRecycledSkillPermanentDeleteNote: String {
        if isPermanentlyDeletingSelectedRecycledSkill {
            return "Permanently deleting the Skill and all recycle-bin metadata on the live EvoMap hub."
        }
        if let blocker = selectedRecycledSkillPermanentDeletePrerequisiteBlocker {
            return blocker
        }
        guard let skill = selectedRecycledSkill,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a recycled skill and an authenticated node before permanently deleting.")
        }
        return AppLocalization.string(
            "note.recycled_skill_permanent_delete_call",
            fallback: "Uses %@ to call `/a2a/skill/store/permanent-delete` for `%@`.",
            node.senderID,
            skill.skillId
        )
    }

    var serviceDraftSubmitTitle: String {
        serviceDraft.mode.submitTitle
    }

    var serviceDraftParsedCapabilities: [String] {
        parseServiceList(from: serviceDraft.capabilitiesText)
    }

    var serviceDraftParsedUseCases: [String] {
        parseServiceList(from: serviceDraft.useCasesText)
    }

    var serviceDraftNote: String {
        if isSubmittingServiceDraft {
            return serviceDraft.mode == .publish
                ? AppLocalization.phrase("Publishing the service listing to the live EvoMap marketplace.")
                : AppLocalization.phrase("Saving the service update to the live EvoMap marketplace.")
        }
        if let blocker = serviceDraftSubmitPrerequisiteBlocker {
            return blocker
        }
        guard let node = selectedNode else {
            return AppLocalization.phrase("Select a connected node before publishing or updating a service.")
        }
        let endpoint = serviceDraft.mode == .publish ? "/a2a/service/publish" : "/a2a/service/update"
        return AppLocalization.string(
            "note.call_with_keychain_node_secret",
            fallback: "Uses %@ to call `%@` with the Keychain-backed node_secret.",
            node.senderID,
            endpoint
        )
    }

    var serviceRatingsCollectionStatus: String {
        if isLoadingServiceRatings {
            return "Loading recent public ratings from the live EvoMap marketplace."
        }
        if let error = serviceRatingsErrorMessage {
            return error
        }
        if selectedServiceSummary == nil {
            return "Select a service to inspect recent public ratings."
        }
        if serviceRatings.isEmpty {
            return AppLocalization.phrase("No public ratings are visible for this service yet.")
        }
        return AppLocalization.string(
            "status.service_ratings.showing",
            fallback: "Showing %d recent rating(s) for the selected service.",
            serviceRatings.count
        )
    }

    var serviceRatingDraftNote: String {
        if isSubmittingServiceRating {
            return "Submitting the rating to `/a2a/service/rate` for this completed service order."
        }
        if let blocker = serviceRatingSubmitPrerequisiteBlocker {
            return blocker
        }
        guard let node = selectedNode else {
            return AppLocalization.phrase("Select the requester node before submitting a service rating.")
        }
        return AppLocalization.string(
            "note.service_rating_call",
            fallback: "Uses %@ to call `/a2a/service/rate` after a completed order on this listing.",
            node.senderID
        )
    }

    var selectedServiceProviderNodeID: String? {
        serviceDetail?.providerNodeID ?? selectedServiceSummary?.providerNodeID
    }

    var selectedServiceStatus: String {
        serviceDetail?.status?.nonEmpty
            ?? selectedServiceSummary?.status?.nonEmpty
            ?? ServiceLifecycleStatus.active.rawValue
    }

    var selectedServiceStatusActionTitle: String {
        selectedServiceStatus.lowercased() == ServiceLifecycleStatus.paused.rawValue
            ? AppLocalization.phrase("Resume Service")
            : AppLocalization.phrase("Pause Service")
    }

    var selectedServiceTargetStatus: ServiceLifecycleStatus {
        selectedServiceStatus.lowercased() == ServiceLifecycleStatus.paused.rawValue ? .active : .paused
    }

    var selectedServiceStatusNote: String {
        if isUpdatingSelectedServiceStatus {
            return "Updating the service listing status on the live EvoMap marketplace."
        }
        if let blocker = selectedServiceStatusPrerequisiteBlocker {
            return blocker
        }
        guard let service = selectedServiceSummary,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a service and an authenticated node before changing status.")
        }
        return AppLocalization.string(
            "note.service_status_call",
            fallback: "Uses %@ to call `/a2a/service/update` and set `%@` to `%@`.",
            node.senderID,
            service.listingID,
            selectedServiceTargetStatus.rawValue
        )
    }

    var selectedServiceArchiveNote: String {
        if isArchivingSelectedService {
            return "Archiving the service listing on the live EvoMap marketplace."
        }
        if let blocker = selectedServiceArchivePrerequisiteBlocker {
            return blocker
        }
        guard let service = selectedServiceSummary,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a service and an authenticated node before archiving it.")
        }
        return AppLocalization.string(
            "note.service_archive_call",
            fallback: "Uses %@ to call `/a2a/service/archive` for `%@`.",
            node.senderID,
            service.listingID
        )
    }

    var selectedServiceOrderNote: String {
        if let blocker = selectedServiceOrderPrerequisiteBlocker {
            return blocker
        }
        guard selectedServiceSummary != nil,
              let node = selectedNode else {
            return AppLocalization.phrase("Select a service and an authenticated node before placing an order.")
        }
        return AppLocalization.string(
            "note.service_order_call",
            fallback: "Uses %@ to call `/a2a/service/order` and stores the returned task locally for refresh through `/task/:id`.",
            node.senderID
        )
    }

    var orderDraftNote: String {
        if isSubmittingOrder {
            return AppLocalization.phrase("Placing the live order on EvoMap and storing the returned task locally in Application Support.")
        }
        if let blocker = orderDraftSubmitPrerequisiteBlocker {
            return blocker
        }
        guard let node = selectedNode else {
            return AppLocalization.phrase("Select a connected node before placing an order.")
        }
        return AppLocalization.string(
            "note.order_draft_call",
            fallback: "Uses %@ to call `/a2a/service/order` with the Keychain-backed node_secret, then tracks the task locally.",
            node.senderID
        )
    }

    var knowledgeGraphAccessBlocker: String? {
        ConsoleAppSettings.kgAPIKey.nonEmpty == nil
            ? AppLocalization.phrase("Save a paid Knowledge Graph API key in Settings before using `/kg/*` endpoints.")
            : nil
    }

    var knowledgeGraphStatusNote: String {
        if isLoadingKnowledgeGraphStatus {
            return AppLocalization.phrase("Loading entitlement, pricing, and usage from `/kg/status`.")
        }
        if let blocker = knowledgeGraphAccessBlocker {
            return blocker
        }
        return AppLocalization.phrase("Uses the Keychain-backed Knowledge Graph API key to call `/kg/status` directly from this Mac app.")
    }

    var knowledgeGraphSnapshotCollectionStatus: String {
        if isLoadingKnowledgeGraphSnapshot {
            return AppLocalization.phrase("Loading your aggregated EvoMap knowledge graph from `/kg/my-graph`.")
        }
        if let error = knowledgeGraphSnapshotErrorMessage {
            return error
        }
        if let blocker = knowledgeGraphAccessBlocker {
            return blocker
        }
        guard let snapshot = knowledgeGraphSnapshot else {
            return AppLocalization.phrase("Load `My Graph` to inspect entities, assets, and relationships.")
        }
        return AppLocalization.string(
            "status.graph_snapshot.showing",
            fallback: "Showing %d node(s) from %d total graph nodes.",
            filteredKnowledgeGraphNodes.count,
            snapshot.totalNodes
        )
    }

    var knowledgeGraphSearchCollectionStatus: String {
        if isSearchingKnowledgeGraph {
            return AppLocalization.phrase("Running a semantic query through `/kg/query`.")
        }
        if let error = knowledgeGraphSearchErrorMessage {
            return error
        }
        if let blocker = knowledgeGraphAccessBlocker {
            return blocker
        }
        guard knowledgeGraphQueryText.nonEmpty != nil else {
            return AppLocalization.phrase("Enter a natural-language query to search your EvoMap knowledge graph.")
        }
        guard let result = knowledgeGraphSearchResult else {
            return AppLocalization.phrase("Run a query to load graph search results.")
        }
        return AppLocalization.string(
            "status.graph_search.showing",
            fallback: "Showing %d node(s), %d cluster(s), and %d recommended step(s).",
            filteredKnowledgeGraphSearchNodes.count,
            result.clusters.count,
            result.recommendedSequence.count
        )
    }

    var knowledgeGraphMutationNote: String {
        if isSubmittingKnowledgeGraphIngest {
            return AppLocalization.phrase("Writing entity and relationship drafts through `/kg/ingest`.")
        }
        if let blocker = knowledgeGraphIngestPrerequisiteBlocker {
            return blocker
        }
        return AppLocalization.phrase("This sends entity drafts as `entities[]` and relationship drafts as both `relationships[]` and `relations[]` for compatibility with the current public docs.")
    }

    var selectedOrderStatusText: String {
        orderDetail?.status?.nonEmpty
            ?? selectedTrackedOrder?.status.nonEmpty
            ?? "unknown"
    }

    var selectedOrderStatusCategory: OrderStatusCategory {
        OrderStatusCategory(status: selectedOrderStatusText)
    }

    var orderCollectionStatus: String {
        if isRefreshingOrders {
            return AppLocalization.phrase("Refreshing locally tracked orders from `/task/:id`.")
        }
        if let error = orderLoadErrorMessage {
            return error
        }
        if trackedOrders.isEmpty {
            return AppLocalization.phrase("No locally tracked orders yet. Place an order from the Services module to start.")
        }
        let shownCount = filteredTrackedOrders.count
        return AppLocalization.string(
            "status.orders.showing",
            fallback: "Showing %d tracked order(s) from %d locally saved task(s).",
            shownCount,
            trackedOrders.count
        )
    }

    var selectedOrderRefreshNote: String {
        if let blocker = selectedOrderRefreshPrerequisiteBlocker {
            return blocker
        }
        guard let order = selectedTrackedOrder else {
            return AppLocalization.phrase("Select a tracked order before refreshing task detail.")
        }
        return AppLocalization.string(
            "note.order_refresh_call",
            fallback: "Refreshes `%@` from `/task/:id` using the stored node_secret for `%@`.",
            order.taskID,
            order.requesterNodeID
        )
    }

    var selectedOrderServiceRatingNote: String {
        if let blocker = selectedOrderServiceRatingPrerequisiteBlocker {
            return blocker
        }
        guard let order = selectedTrackedOrder else {
            return AppLocalization.phrase("Select a completed tracked order before rating the provider.")
        }
        return AppLocalization.string(
            "note.order_rating_call",
            fallback: "Rates `%@` through `/a2a/service/rate` using requester node `%@`.",
            order.serviceTitle,
            order.requesterNodeID
        )
    }

    var selectedRemoteSkillAuthorNodeID: String? {
        remoteSkillDetail?.author?.nodeId ?? selectedRemoteSkillSummary?.author?.nodeId
    }

    var selectedRemoteSkillCurrentVersion: String? {
        remoteSkillDetail?.version ?? selectedRemoteSkillSummary?.version
    }

    var selectedRemoteSkillVisibility: String {
        remoteSkillDetail?.visibility?.nonEmpty ?? "public"
    }

    var selectedRemoteSkillTargetVisibility: String {
        selectedRemoteSkillVisibility.lowercased() == "private" ? "public" : "private"
    }

    var availableRemoteRollbackVersions: [RemoteSkillVersion] {
        let currentVersion = selectedRemoteSkillCurrentVersion?.nonEmpty
        return remoteSkillVersions.filter { version in
            guard let currentVersion else { return true }
            return version.version != currentVersion
        }
    }

    var recycleBinCollectionStatus: String {
        if isLoadingRecycledSkills {
            return AppLocalization.phrase("Loading recycled Skill Store entries for the selected node.")
        }
        if let error = recycledSkillLoadErrorMessage {
            return error
        }
        if let blocker = recycleBinAccessBlocker {
            return blocker
        }
        if recycledSkills.isEmpty {
            return searchText.nonEmpty == nil
                ? AppLocalization.phrase("The recycle bin is empty for the selected node.")
                : AppLocalization.phrase("No recycled skills match the current query.")
        }
        let shownCount = filteredRecycledSkills.count
        let totalCount = recycledSkillTotalCount == 0 ? recycledSkills.count : recycledSkillTotalCount
        return AppLocalization.string(
            "status.recycle_bin.showing",
            fallback: "Showing %d recycled skill(s) from %d recycle-bin entries.",
            shownCount,
            totalCount
        )
    }

    var remoteSkillCollectionStatus: String {
        if isLoadingRemoteSkills {
            return AppLocalization.phrase("Loading the public EvoMap Skill Store feed.")
        }
        if let error = remoteSkillLoadErrorMessage {
            return error
        }
        if remoteSkillStoreEnabled == false {
            return AppLocalization.phrase("The public Skill Store endpoint is disabled on this hub.")
        }
        if remoteSkills.isEmpty {
            return searchText.nonEmpty == nil
                ? AppLocalization.phrase("No remote skills are available yet.")
                : AppLocalization.phrase("No remote skills match the current query.")
        }
        let shownCount = filteredRemoteSkills.count
        return AppLocalization.string(
            "status.remote_skills.showing",
            fallback: "Showing %d remote skill(s) from %d published entries.",
            shownCount,
            remoteSkillTotalCount
        )
    }

    var serviceCollectionStatus: String {
        if isLoadingServices {
            return AppLocalization.phrase("Loading the live EvoMap services marketplace.")
        }
        if let error = serviceLoadErrorMessage {
            return error
        }
        if services.isEmpty {
            return searchText.nonEmpty == nil
                ? AppLocalization.phrase("No services are visible yet.")
                : AppLocalization.phrase("No services match the current query.")
        }
        let shownCount = filteredServices.count
        return AppLocalization.string(
            "status.services.showing",
            fallback: "Showing %d service(s) from %d visible listings.",
            shownCount,
            services.count
        )
    }

    var creditReportingNodes: [NodeRecord] {
        nodes.filter { $0.isSampleData == false }
    }

    var liveNodeCount: Int {
        creditReportingNodes.count
    }

    var sampleNodeCount: Int {
        nodes.filter(\.isSampleData).count
    }

    var liveSkills: [SkillRecord] {
        skills.filter { $0.isSampleData == false }
    }

    var liveSkillCount: Int {
        liveSkills.count
    }

    var sampleSkillCount: Int {
        skills.filter(\.isSampleData).count
    }

    var hasSampleSeedData: Bool {
        sampleNodeCount > 0 || sampleSkillCount > 0
    }

    var hasLiveOperationalData: Bool {
        liveNodeCount > 0 || liveSkillCount > 0
    }

    var hasLiveCreditData: Bool {
        creditReportingNodes.isEmpty == false
    }

    var selectedBountyTask: EvoMapBountyTask? {
        guard let selectedBountyTaskID else {
            return bountyTasks.first(where: { bountyTaskIsDefaultVisible($0) }) ?? bountyTasks.first
        }
        return bountyTasks.first(where: { $0.id == selectedBountyTaskID })
            ?? bountyTasks.first(where: { bountyTaskIsDefaultVisible($0) })
            ?? bountyTasks.first
    }

    var selectedClaimedBountyTask: EvoMapClaimedBountyTask? {
        guard let task = selectedBountyTask else { return claimedBountyTasks.first }
        return claimedBountyTask(for: task)
    }

    func bountyBody(for task: EvoMapBountyTask) -> String? {
        claimedBountyTask(for: task)?.body?.nonEmpty ?? task.summary?.nonEmpty
    }

    var selectedBountyTaskIsClaimed: Bool {
        selectedClaimedBountyTask != nil
    }

    var filteredBountyTasks: [EvoMapBountyTask] {
        let tasks: [EvoMapBountyTask]
        if searchText.isEmpty {
            tasks = bountyTasks
        } else {
            let query = searchText.normalizedSearchKey
            tasks = bountyTasks.filter { task in
                bountyTaskMatchesSearch(task, query: query)
            }
        }

        return tasks.sorted { lhs, rhs in
            let lhsClaimable = canSelectedNodeClaimBounty(lhs)
            let rhsClaimable = canSelectedNodeClaimBounty(rhs)
            if lhsClaimable != rhsClaimable {
                return bountyClaimableRank(lhsClaimable) > bountyClaimableRank(rhsClaimable)
            }

            let lhsCredits = lhs.displayCredits ?? 0
            let rhsCredits = rhs.displayCredits ?? 0
            if lhsCredits != rhsCredits {
                return lhsCredits > rhsCredits
            }

            let lhsClaimed = isClaimedBountyTask(lhs)
            let rhsClaimed = isClaimedBountyTask(rhs)
            if lhsClaimed != rhsClaimed {
                return lhsClaimed
            }

            return AppLocalization.bountyText(lhs.title).localizedStandardCompare(AppLocalization.bountyText(rhs.title)) == .orderedAscending
        }
    }

    var visibleBountyTasks: [EvoMapBountyTask] {
        let baseTasks = bountyShowsAllLoadedTasks ? filteredBountyTasks : defaultClaimableBountyTasks
        return baseTasks.filter { task in
            isClaimedBountyTask(task) == false && followedBountyTaskIDs.contains(task.id) == false
        }
    }

    var bountyAutopilotCandidates: [BountyAutopilotCandidate] {
        filteredBountyTasks
            .filter { isClaimedBountyTask($0) == false }
            .filter { bountyTaskCanAttemptClaim($0) && canSelectedNodeClaimBounty($0) != false }
            .map { bountyAutopilotCandidate(for: $0) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return (lhs.task.displayCredits ?? 0) > (rhs.task.displayCredits ?? 0)
            }
            .prefix(5)
            .map { $0 }
    }

    var selectedBountyAutopilotRun: BountyAutopilotRun? {
        if let selectedBountyAutopilotRunID,
           let run = bountyAutopilotRuns.first(where: { $0.id == selectedBountyAutopilotRunID }) {
            return run
        }
        return bountyAutopilotRuns.first
    }

    var latestBountyAutopilotRun: BountyAutopilotRun? {
        bountyAutopilotRuns.first
    }

    var bountyAutopilotStatusLine: String {
        if let run = latestBountyAutopilotRun {
            return AppLocalization.string(
                "bounties.autopilot.status_line.latest",
                fallback: "Latest run: %@ · %@ · %@",
                run.title,
                run.status.title,
                run.updatedAt.formatted(.relative(presentation: .named))
            )
        }
        return AppLocalization.string(
            "bounties.autopilot.status_line.empty",
            fallback: "No Console-owned autopilot runs yet. Start one here to keep a visible audit trail."
        )
    }

    var hiddenBountyTaskCount: Int {
        guard bountyShowsAllLoadedTasks == false else { return 0 }
        return max(0, filteredBountyTasks.count - defaultClaimableBountyTasks.count)
    }

    private var defaultClaimableBountyTasks: [EvoMapBountyTask] {
        filteredBountyTasks.filter { bountyTaskIsDefaultVisible($0) }
    }

    private func bountyTaskIsDefaultVisible(_ task: EvoMapBountyTask) -> Bool {
        isClaimedBountyTask(task) || bountyTaskIsClaimableCandidate(task)
    }

    private func bountyTaskIsClaimableCandidate(_ task: EvoMapBountyTask) -> Bool {
        guard bountyTaskCanAttemptClaim(task) else { return false }
        guard canSelectedNodeClaimBounty(task) == true else {
            return false
        }
        return true
    }

    func bountyTaskCanAttemptClaim(_ task: EvoMapBountyTask) -> Bool {
        (task.claimableTaskID != nil || task.bountyID?.nonEmpty != nil)
            && locallyClosedBountyTaskIDs.contains(task.id) == false
            && bountyTaskStatusAllowsNewClaim(task.status)
    }

    private func bountyAutopilotCandidate(for task: EvoMapBountyTask) -> BountyAutopilotCandidate {
        var score = 0
        var reasons: [String] = []
        var risks: [String] = []

        let credits = task.displayCredits ?? 0
        if credits > 0 {
            score += min(credits * 12, 120)
            reasons.append(AppLocalization.string("bounties.autopilot.reason.reward", fallback: "%d credits", credits))
        }

        if bountyTaskCanAttemptClaim(task) {
            score += 35
            reasons.append(AppLocalization.string("bounties.autopilot.reason.open", fallback: "claimable/open"))
        } else {
            score -= 80
            risks.append(AppLocalization.string("bounties.autopilot.risk.not_open", fallback: "not currently claimable"))
        }

        switch canSelectedNodeClaimBounty(task) {
        case .some(true):
            score += 35
            reasons.append(AppLocalization.string("bounties.autopilot.reason.reputation_ok", fallback: "node reputation OK"))
        case .some(false):
            score -= 120
            risks.append(AppLocalization.string("bounties.autopilot.risk.reputation", fallback: "node reputation too low"))
        case .none:
            score -= 8
            risks.append(AppLocalization.string("bounties.autopilot.risk.reputation_unknown", fallback: "reputation requirement unknown"))
        }

        let body = bountyBody(for: task)?.nonEmpty
        if let body {
            score += body.count > 120 ? 35 : 18
            reasons.append(AppLocalization.string("bounties.autopilot.reason.body", fallback: "task body available"))
        } else {
            score -= 35
            risks.append(AppLocalization.string("bounties.autopilot.risk.no_body", fallback: "missing task body"))
        }

        let searchableText = "\(task.title) \(body ?? "")".lowercased()
        let heavySignals = ["implement", "code", "bug", "api", "swift", "python", "typescript", "product", "fix", "error"]
        if heavySignals.contains(where: { searchableText.contains($0) }) {
            score += 18
            reasons.append(AppLocalization.string("bounties.autopilot.reason.agent_fit", fallback: "agent-friendly"))
        }

        if let submissionCount = task.submissionCount, submissionCount > 0 {
            score -= min(submissionCount * 8, 32)
            risks.append(AppLocalization.string("bounties.autopilot.risk.competition", fallback: "%d existing submission(s)", submissionCount))
        }

        if task.title.count < 8 {
            score -= 12
            risks.append(AppLocalization.string("bounties.autopilot.risk.short_title", fallback: "very short title"))
        }

        return BountyAutopilotCandidate(
            task: task,
            score: score,
            reasons: Array(reasons.prefix(4)),
            risks: Array(risks.prefix(3))
        )
    }

    private func bountyTaskStatusAllowsNewClaim(_ status: String?) -> Bool {
        guard let status = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              status.isEmpty == false else {
            return true
        }
        let openStatuses: Set<String> = [
            "available",
            "claimable",
            "created",
            "new",
            "open",
            "unclaimed",
        ]
        return openStatuses.contains(status)
    }

    private func bountyClaimableRank(_ value: Bool?) -> Int {
        switch value {
        case true:
            return 2
        case nil:
            return 1
        case false:
            return 0
        }
    }

    private func bountyTaskMatchesSearch(_ task: EvoMapBountyTask, query: String) -> Bool {
        [
            task.title,
            AppLocalization.bountyText(task.title),
            task.summary,
            bountyBody(for: task),
            task.domain,
            task.kind,
            task.status,
            task.bountyID,
            task.questionID,
            task.claimableTaskID,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .normalizedSearchKey
        .contains(query)
    }

    var followedBountyTasks: [EvoMapBountyTask] {
        filteredBountyTasks.filter { followedBountyTaskIDs.contains($0.id) && isClaimedBountyTask($0) == false }
    }

    var claimedBountyDisplayTasks: [EvoMapBountyTask] {
        claimedBountyTasks.map { claimed in
            bountyTasks.first(where: { bountyTaskMatchesClaimedTask($0, claimed: claimed) })
                ?? EvoMapBountyTask(claimedTask: claimed)
        }
    }

    var hasMoreBountyTasks: Bool {
        if let bountyTaskTotalCount {
            return bountyTasks.count < bountyTaskTotalCount
        }
        return bountyTaskCurrentPage > 0 && bountyTasks.count >= Self.bountyTaskPageSize
    }

    var bountyTaskLoadedCountLine: String {
        if let total = bountyTaskTotalCount {
            return AppLocalization.string(
                "bounties.loaded_count",
                fallback: "Loaded %d / %@",
                bountyTasks.count,
                total.formatted(.number)
            )
        }
        return AppLocalization.string(
            "bounties.loaded_count_unknown",
            fallback: "Loaded %d",
            bountyTasks.count
        )
    }

    var claimedBountyTaskCountLine: String {
        AppLocalization.string(
            "bounties.claimed_count",
            fallback: "Claimed %d",
            claimedBountyTasks.count
        )
    }

    var selectedBountyTaskIsFollowed: Bool {
        guard let selectedBountyTask else { return false }
        return followedBountyTaskIDs.contains(selectedBountyTask.id)
    }

    var selectedBountyClaimedStatusLine: String {
        guard let claimed = selectedClaimedBountyTask else {
            return AppLocalization.string(
                "bounties.delivery.claim_required",
                fallback: "Claim this task before preparing the final EvoMap submission."
            )
        }

        let status = AppLocalization.bountyTerm(claimed.mySubmissionStatus ?? claimed.status)
            ?? claimed.mySubmissionStatus
            ?? claimed.status
            ?? AppLocalization.unknown
        let submission = claimed.mySubmissionID?.nonEmpty ?? AppLocalization.unknown
        return AppLocalization.string(
            "bounties.delivery.claimed_status",
            fallback: "Claimed task %@. Submission %@ is %@.",
            claimed.taskID,
            submission,
            status
        )
    }

    var selectedBountySubmissionPreview: String {
        guard let task = selectedBountyTask else { return "" }
        let taskID = selectedClaimedBountyTask?.taskID
            ?? task.claimableTaskID
            ?? AppLocalization.string("bounties.value.resolve_before_claim", fallback: "Resolve before claim")
        let nodeID = selectedOrFirstCreditNode?.senderID ?? AppLocalization.chooseConnectedNode
        let bundle = try? makeBountyPublishBundle(task: task, taskID: taskID, node: selectedOrFirstCreditNode, draft: bountyAnswerDraft)
        let assetID = bundle?.capsuleAssetID ?? "sha256:..."

        return """
        POST /a2a/publish
        {
          "message_type": "publish",
          "sender_id": "\(nodeID)",
          "payload": {
            "assets": ["Gene", "Capsule"],
            "capsule_asset_id": "\(assetID)"
          }
        }

        POST /a2a/task/complete
        {
          "task_id": "\(taskID)",
          "asset_id": "\(assetID)",
          "node_id": "\(nodeID)"
        }
        """
    }

    var canSubmitSelectedBountyAnswer: Bool {
        guard selectedBountyTask != nil,
              selectedClaimedBountyTask != nil,
              bountyAnswerDraft.answerText.nonEmpty != nil else {
            return false
        }
        return isSubmittingBountyAnswer == false
            && bountyTaskPrerequisiteBlocker == nil
            && loadStoredSecret(for: selectedOrFirstCreditNode?.senderID ?? "")?.nonEmpty != nil
    }

    var selectedBountyExecutionBrief: String {
        guard let task = selectedBountyTask else { return "" }
        let claimed = selectedClaimedBountyTask
        let title = AppLocalization.bountyText(task.title)
        let body = bountyBody(for: task).map { AppLocalization.bountyText($0) }?.nonEmpty ?? AppLocalization.string(
            "bounties.no_summary",
            fallback: "No summary returned by the public bounty API."
        )
        let taskID = claimed?.taskID ?? task.claimableTaskID ?? AppLocalization.unknown
        let bountyID = task.bountyID ?? AppLocalization.unknown
        let reward = task.displayCredits.map { "\($0)" } ?? AppLocalization.unknown
        let currentDraft = bountyAnswerDraft.answerText.nonEmpty ?? AppLocalization.none

        return """
        You are executing an EvoMap bounty task for a local macOS operator.

        Hard rules:
        - Do not call EvoMap submit/complete endpoints.
        - Do not expose API keys, node_secret values, private paths, or credentials.
        - Produce a final answer in Markdown that can be pasted into the app's Final answer field.
        - Keep the answer concrete enough for the bounty owner to accept or reject.
        - If assumptions are required, label them clearly.

        Task metadata:
        - task_id: \(taskID)
        - bounty_id: \(bountyID)
        - reward_credits: \(reward)
        - title: \(title)
        - body: \(body)

        Current local draft:
        \(currentDraft)

        Required output:
        1. Final answer only, no process log.
        2. Include implementation plan, concrete deliverable structure, validation approach, and risks if the task asks for product/code planning.
        3. If the task is in Chinese, answer in Chinese unless the task explicitly asks for another language.
        """
    }

    var selectedBountyExecutionCommand: String {
        let brief = selectedBountyExecutionBrief
        guard brief.nonEmpty != nil else { return "" }
        let cwd = "$HOME/Library/Application Support/EvomapConsole/TaskRuns"
        switch bountyExecutionProvider {
        case .openClaw:
            return """
            mkdir -p "\(cwd)" && cat <<'EOF' > "\(cwd)/evomap-bounty-brief.md"
            \(brief)
            EOF
            openclaw agent --local --agent main --message "$(< "\(cwd)/evomap-bounty-brief.md")"
            """
        case .codexCLI:
            return """
            mkdir -p "\(cwd)" && cat <<'EOF' | /Applications/Codex.app/Contents/Resources/codex exec --cd "\(cwd)" --sandbox workspace-write -
            \(brief)
            EOF
            """
        case .claudeCode:
            return """
            mkdir -p "\(cwd)" && cd "\(cwd)" && cat <<'EOF' | /opt/homebrew/bin/claude -p --permission-mode plan --output-format text
            \(brief)
            EOF
            """
        case .directModel:
            return AppLocalization.string(
                "bounties.executor.direct_model.placeholder",
                fallback: "Direct model execution is intentionally not wired yet. Use the brief with your model/Skill runtime, then paste the result into Final answer."
            )
        case .manual:
            return AppLocalization.string(
                "bounties.executor.manual.placeholder",
                fallback: "No command. Use the execution brief as your checklist."
            )
        }
    }

    var patchCourierRelayEmailIsConfigured: Bool {
        ConsoleAppSettings.patchCourierRelayEmail.nonEmpty != nil
    }

    var patchCourierBackendIsEnabled: Bool {
        ConsoleAppSettings.patchCourierBackendEnabled
    }

    var patchCourierBackendIsConfigured: Bool {
        ConsoleAppSettings.patchCourierBackendAccount != nil
            && patchCourierRelayEmailIsConfigured
            && patchCourierBackendPassword()?.nonEmpty != nil
    }

    var selectedBountyPatchCourierBackendStatusLine: String {
        if let status = bountyAnswerDraft.patchCourierStatus?.nonEmpty {
            var parts = [AppLocalization.string("bounties.patch_courier.backend.status_prefix", fallback: "Backend: %@", status)]
            if let confidence = bountyAnswerDraft.patchCourierConfidence?.nonEmpty {
                parts.append(AppLocalization.string("bounties.patch_courier.backend.confidence", fallback: "confidence %@", confidence))
            }
            if let receivedAt = bountyAnswerDraft.patchCourierReceivedAt {
                parts.append(AppLocalization.string("bounties.patch_courier.backend.received_at", fallback: "received %@", receivedAt.formatted(date: .abbreviated, time: .shortened)))
            } else if let sentAt = bountyAnswerDraft.patchCourierSentAt {
                parts.append(AppLocalization.string("bounties.patch_courier.backend.sent_at", fallback: "sent %@", sentAt.formatted(date: .abbreviated, time: .shortened)))
            }
            return parts.joined(separator: " · ")
        }

        guard patchCourierBackendIsEnabled else {
            return AppLocalization.string("bounties.patch_courier.backend.disabled", fallback: "Backend mail is off. Enable it in Settings to send and check automatically.")
        }
        guard patchCourierBackendIsConfigured else {
            return AppLocalization.string("bounties.patch_courier.backend.not_configured", fallback: "Backend mail is not fully configured in Settings.")
        }
        return AppLocalization.string("bounties.patch_courier.backend.ready", fallback: "Backend mail is ready.")
    }

    var selectedBountyPatchCourierExecuteEmailSubject: String {
        guard let task = selectedBountyTask else { return "" }
        return "[EvoMap][EXECUTE][\(selectedBountyPatchCourierTaskID(for: task))] \(AppLocalization.bountyText(task.title))"
    }

    var selectedBountyPatchCourierStatusEmailSubject: String {
        guard let task = selectedBountyTask else { return "" }
        return "[EvoMap][STATUS][\(selectedBountyPatchCourierTaskID(for: task))] \(AppLocalization.bountyText(task.title))"
    }

    var selectedBountyPatchCourierExecuteEmailBody: String {
        guard let task = selectedBountyTask else { return "" }
        let claimed = selectedClaimedBountyTask
        let taskID = selectedBountyPatchCourierTaskID(for: task)
        let requestID = selectedBountyPatchCourierRequestID(for: task)
        let payload = selectedBountyPatchCourierPayload(task: task, claimed: claimed, taskID: taskID)
        return """
        PATCH_COURIER_COMMAND: EVOMAP_EXECUTE
        PATCH_COURIER_PROTOCOL: 1
        REQUEST_ID: \(requestID)
        TASK_ID: \(taskID)
        PROJECT: \(ConsoleAppSettings.patchCourierProjectSlug)
        MODE: draft
        AUTO_SUBMIT_ALLOWED: false
        LANGUAGE: \(ConsoleAppSettings.appLanguage.localeIdentifier)

        Action: Execute this claimed EvoMap bounty task and return a structured draft answer for EvomapConsole. Do not submit to EvoMap.

        ```json
        \(payload)
        ```
        """
    }

    var selectedBountyPatchCourierStatusEmailBody: String {
        guard let task = selectedBountyTask else { return "" }
        let taskID = selectedBountyPatchCourierTaskID(for: task)
        return """
        PATCH_COURIER_COMMAND: EVOMAP_STATUS
        PATCH_COURIER_PROTOCOL: 1
        REQUEST_ID: evomap:\(taskID)
        TASK_ID: \(taskID)
        PROJECT: \(ConsoleAppSettings.patchCourierProjectSlug)
        LANGUAGE: \(ConsoleAppSettings.appLanguage.localeIdentifier)
        """
    }

    var selectedNodeReputationScore: Double? {
        selectedOrFirstCreditNode?.reputationScore
    }

    func bountyRequiredReputation(for task: EvoMapBountyTask?) -> Int? {
        guard let task else { return nil }
        if let minReputation = task.minReputation {
            return minReputation
        }
        guard let credits = task.displayCredits else {
            return nil
        }
        if credits >= 10 {
            return 65
        }
        if credits >= 5 {
            return 40
        }
        if credits >= 1 {
            return 20
        }
        return 0
    }

    func canSelectedNodeClaimBounty(_ task: EvoMapBountyTask?) -> Bool? {
        guard let required = bountyRequiredReputation(for: task) else {
            return nil
        }
        guard let reputation = selectedNodeReputationScore else {
            return nil
        }
        return reputation >= Double(required)
    }

    var selectedBountyEligibilityLine: String? {
        guard let task = selectedBountyTask,
              let required = bountyRequiredReputation(for: task) else {
            return nil
        }
        guard let reputation = selectedNodeReputationScore else {
            return AppLocalization.string(
                "bounties.eligibility.unknown",
                fallback: "Docs default: this bounty requires reputation >= %d. Refresh bounties to read the selected node's reputation.",
                required
            )
        }
        if reputation >= Double(required) {
            return AppLocalization.string(
                "bounties.eligibility.ready",
                fallback: "Current node reputation %.0f meets the documented requirement >= %d.",
                reputation,
                required
            )
        }
        return AppLocalization.string(
            "bounties.eligibility.insufficient",
            fallback: "Current node reputation %.0f is below the documented requirement >= %d. Follow this task for later or pick a lower-threshold bounty.",
            reputation,
            required
        )
    }

    var selectedBountyClaimContextLine: String? {
        guard let task = selectedBountyTask else { return nil }
        let nodeID = selectedOrFirstCreditNode?.senderID ?? AppLocalization.unknown
        if let taskID = task.claimableTaskID {
            return AppLocalization.string(
                "credits.bounty.claim_context.ready",
                fallback: "Claim will send node_id=%@ and task_id=%@.",
                nodeID,
                taskID
            )
        }
        if let bountyID = task.bountyID?.nonEmpty {
            return AppLocalization.string(
                "credits.bounty.claim_context.resolve",
                fallback: "Claim will resolve task_id from bounty_id=%@, then send node_id=%@.",
                bountyID,
                nodeID
            )
        }
        return AppLocalization.string(
            "credits.bounty.claim_context.missing",
            fallback: "This row has no task_id or bounty_id, so it cannot be claimed from the app yet."
        )
    }

    var officialAccountBalanceDisplayValue: String {
        guard let value = accountBalanceSnapshot?.bestBalance else {
            return AppLocalization.string("credits.value.official_account_page", fallback: "Check EvoMap account page")
        }
        return AppLocalization.string("credits.unit.count", fallback: "%d credits", value)
    }

    var officialAccountBalanceDetailLine: String {
        if let snapshot = accountBalanceSnapshot {
            return [
                snapshot.planName.map {
                    AppLocalization.string("credits.balance.plan", fallback: "Plan: %@", $0)
                },
                snapshot.pendingCredits.map {
                    AppLocalization.string("credits.balance.pending", fallback: "Pending: %d credits", $0)
                },
                snapshot.updatedAt.map {
                    AppLocalization.string("credits.balance.updated", fallback: "Updated: %@", $0)
                },
                snapshot.message,
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nonEmpty ?? AppLocalization.string("credits.balance.synced", fallback: "Official balance synced.")
        }

        return AppLocalization.string(
            "credits.balance.official_hint",
            fallback: "Use Refresh after saving an API key in Settings; if EvoMap requires web login, open the official account page."
        )
    }

    var bountyTaskPrerequisiteBlocker: String? {
        guard let node = selectedOrFirstCreditNode else {
            return AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
        }
        guard node.claimState == .claimed else {
            return AppLocalization.string(
                "credits.bounty.blocker.node_not_claimed",
                fallback: "Finish node claim in Nodes first, then return here to claim bounty tasks."
            )
        }
        guard loadStoredSecret(for: node.senderID)?.nonEmpty != nil else {
            return AppLocalization.string("credits.bounty.blocker.no_secret", fallback: "Run /a2a/hello first so the node_secret is stored in Keychain.")
        }
        return nil
    }

    var totalNodeCreditBalance: Int {
        creditReportingNodes.reduce(0) { $0 + $1.creditBalance }
    }

    var claimedNodeCount: Int {
        creditReportingNodes.filter { $0.claimState == .claimed }.count
    }

    var storedNodeSecretCount: Int {
        creditReportingNodes.filter(\.nodeSecretStored).count
    }

    var selectedOrFirstCreditNode: NodeRecord? {
        if let selectedNode, selectedNode.isSampleData == false {
            return selectedNode
        }
        return creditReportingNodes.first
    }

    var premiumCreditTarget: Int {
        2_000
    }

    var freeDailyEarningCap: Int {
        200
    }

    var premiumCreditGap: Int {
        max(premiumCreditTarget - totalNodeCreditBalance, 0)
    }

    var premiumCreditGapDisplayValue: String {
        guard hasLiveCreditData else {
            return AppLocalization.string("credits.value.pending_node_balance", fallback: "Waiting for node balance")
        }
        return AppLocalization.string("credits.unit.count", fallback: "%d credits", premiumCreditGap)
    }

    var creditProgressFraction: Double {
        guard hasLiveCreditData, premiumCreditTarget > 0 else { return 0 }
        return min(Double(totalNodeCreditBalance) / Double(premiumCreditTarget), 1.0)
    }

    var creditSprintPrimaryTitle: String {
        return AppLocalization.string("primary.open_bounty_tracker", fallback: "Open Bounty Tracker")
    }

    var creditSprintStatusLine: String {
        if creditReportingNodes.isEmpty {
            return AppLocalization.string(
                "credits.status.no_nodes",
                fallback: "Connect one real local node first. Built-in sample nodes are not counted as account credits."
            )
        }
        if storedNodeSecretCount == 0 {
            return AppLocalization.string(
                "credits.status.no_secret",
                fallback: "Run `/a2a/hello` from Nodes so this Mac stores a node_secret in Keychain."
            )
        }
        if claimedNodeCount == 0 {
            return AppLocalization.string(
                "credits.status.no_claim",
                fallback: "Open the claim URL and bind the node to your EvoMap account before chasing bounties."
            )
        }
        if premiumCreditGap == 0 {
            return AppLocalization.string(
                "credits.status.premium_ready",
                fallback: "The live node-reported balance is at or above the public Premium target. Save a KG API key in Settings when the account is upgraded."
            )
        }
        return AppLocalization.string(
            "credits.status.gap",
            fallback: "You are %d credits short of the public Premium target. Bounties and services are the fastest path from here.",
            premiumCreditGap
        )
    }

    var creditSprintSteps: [CreditSprintStep] {
        [
            CreditSprintStep(
                id: "find_bounties",
                title: AppLocalization.string("credits.step.bounties.title", fallback: "Work bounty questions"),
                detail: AppLocalization.string(
                    "credits.step.bounties.detail",
                    fallback: "Refresh bounty-backed questions, then start with language, education, and content-structure tasks."
                ),
                systemImage: "target",
                tintName: bountyTasks.isEmpty ? "blue" : "green",
                isComplete: bountyTasks.isEmpty == false
            ),
            CreditSprintStep(
                id: "claim_task",
                title: AppLocalization.string("credits.step.claim_task.title", fallback: "Claim one task"),
                detail: AppLocalization.string(
                    "credits.step.claim_task.detail",
                    fallback: "Pick only tasks you can solve cleanly, then claim the selected bounty."
                ),
                systemImage: "hand.raised",
                tintName: selectedBountyTaskIsClaimed ? "green" : (activeBountyClaimTaskID == nil ? "blue" : "orange"),
                isComplete: selectedBountyTaskIsClaimed
            ),
            CreditSprintStep(
                id: "submit_answer",
                title: AppLocalization.string("credits.step.submit_answer.title", fallback: "Submit and settle"),
                detail: AppLocalization.string(
                    "credits.step.submit_answer.detail",
                    fallback: "Publish a verifiable answer Capsule, complete the task, then wait for EvoMap settlement."
                ),
                systemImage: "paperplane",
                tintName: bountyAnswerDraft.publishedAssetID == nil ? "blue" : "green",
                isComplete: bountyAnswerDraft.publishedAssetID != nil
            ),
            CreditSprintStep(
                id: "service",
                title: AppLocalization.string("credits.step.service.title", fallback: "Publish a Japanese learning service"),
                detail: AppLocalization.string(
                    "credits.step.service.detail",
                    fallback: "After the data cleanup, expose JLPT vocabulary, grammar correction, examples, and quiz generation as callable services."
                ),
                systemImage: "shippingbox",
                tintName: "blue",
                isComplete: services.contains { service in
                    let text = "\(service.title) \(service.description) \(service.capabilities.joined(separator: " "))".normalizedSearchKey
                    return text.contains("japanese") || text.contains("jlpt") || text.contains("日本語")
                }
            ),
            CreditSprintStep(
                id: "premium",
                title: AppLocalization.string("credits.step.premium.title", fallback: "Upgrade and add KG API key"),
                detail: AppLocalization.string(
                    "credits.step.premium.detail",
                    fallback: "API keys are for paid Knowledge Graph endpoints. Treat them as the step after credits are enough."
                ),
                systemImage: "key",
                tintName: ConsoleAppSettings.kgAPIKey.nonEmpty == nil ? "secondary" : "green",
                isComplete: ConsoleAppSettings.kgAPIKey.nonEmpty != nil
            ),
        ]
    }

    var evoMapBountiesURL: URL {
        URL(string: "https://evomap.ai/bounties")!
    }

    var evoMapPricingURL: URL {
        URL(string: "https://evomap.ai/pricing")!
    }

    var evoMapAPIKeysURL: URL {
        URL(string: "\(ConsoleAppSettings.hubBaseURL)/account/api-keys")!
    }

    var evoMapReputationDocsURL: URL {
        URL(string: "\(ConsoleAppSettings.hubBaseURL)/wiki/06-billing-reputation")!
    }

    var overviewMetrics: [OverviewMetric] {
        let healthyCount = creditReportingNodes.filter { $0.heartbeat == .healthy }.count
        let claimedCount = creditReportingNodes.filter { $0.claimState == .claimed }.count
        let publishedCount = liveSkills.filter { $0.state == .published }.count
        let changedCount = liveSkills.filter { $0.state == .changed }.count
        return [
            OverviewMetric(
                title: AppLocalization.string("overview.metric.healthy_nodes.title", fallback: "Healthy Nodes"),
                value: "\(healthyCount)/\(liveNodeCount)",
                detail: AppLocalization.string(
                    "overview.metric.healthy_nodes.detail",
                    fallback: "Real connected nodes with recent heartbeats and working auth. Demo nodes are excluded."
                ),
                systemImage: "heart.text.square"
            ),
            OverviewMetric(
                title: AppLocalization.string("overview.metric.claimed_nodes.title", fallback: "Claimed Nodes"),
                value: "\(claimedCount)",
                detail: AppLocalization.string(
                    "overview.metric.claimed_nodes.detail",
                    fallback: "Real nodes already bound to your EvoMap account. Demo nodes are excluded."
                ),
                systemImage: "checkmark.shield"
            ),
            OverviewMetric(
                title: AppLocalization.string("overview.metric.published_skills.title", fallback: "Published Skills"),
                value: "\(publishedCount)",
                detail: AppLocalization.string(
                    "overview.metric.published_skills.detail",
                    fallback: "Real local skills that match a remote published version. Demo skills are excluded."
                ),
                systemImage: "sparkles"
            ),
            OverviewMetric(
                title: AppLocalization.string("overview.metric.needs_review.title", fallback: "Needs Review"),
                value: "\(changedCount)",
                detail: AppLocalization.string(
                    "overview.metric.needs_review.detail",
                    fallback: "Real local skills with changes before the next publish. Demo skills are excluded."
                ),
                systemImage: "exclamationmark.triangle"
            ),
        ]
    }

    var recentOverviewEvents: [NodeEvent] {
        let liveEvents = creditReportingNodes.flatMap(\.recentEvents)
        let sourceEvents = liveEvents.isEmpty ? nodes.flatMap(\.recentEvents) : liveEvents

        return sourceEvents
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(5)
            .map { $0 }
    }

    func setSection(_ section: ConsoleSection) {
        selectedSection = section
        switch section {
        case .nodes:
            selectedNodeID = selectedNodeID ?? visibleNodes.first?.id
        case .credits, .bounties:
            selectedNodeID = selectedNodeID ?? selectedOrFirstCreditNode?.id ?? visibleNodes.first?.id
            selectedBountyTaskID = selectedBountyTaskID ?? bountyTasks.first?.id
            if section == .bounties, bountyTasks.isEmpty {
                Task {
                    await refreshBountyTasks()
                }
            } else if section == .bounties, claimedBountyTasks.isEmpty {
                Task {
                    await refreshClaimedBountyTasks()
                }
            }
        case .skills:
            switch skillWorkspaceMode {
            case .local:
                selectedSkillID = selectedSkillID ?? skills.first?.id
            case .store:
                selectedRemoteSkillID = selectedRemoteSkillID ?? remoteSkills.first?.id
                Task {
                    await loadRemoteSkillsIfNeeded()
                }
            case .recycleBin:
                selectedRecycledSkillID = selectedRecycledSkillID ?? recycledSkills.first?.id
                Task {
                    await loadRecycleBinIfNeeded()
                }
            }
        case .services:
            selectedServiceID = selectedServiceID ?? services.first?.id
            Task {
                await loadServicesIfNeeded()
            }
        case .orders:
            selectedOrderTaskID = selectedOrderTaskID ?? trackedOrders.first?.taskID
            Task {
                await loadOrdersIfNeeded()
            }
        case .graph:
            Task {
                await loadKnowledgeGraphStatusIfNeeded()
                await loadKnowledgeGraphCurrentWorkspaceIfNeeded()
            }
        case .overview, .activity:
            break
        }
    }

    func refreshCurrentSection() {
        switch selectedSection {
        case .nodes:
            Task {
                await refreshSelectedNodeHeartbeat()
            }
        case .credits:
            lastRefreshAt = Date()
            refreshStoredSecretFlags()
        case .bounties:
            Task {
                await refreshBountyTasks()
            }
        case .skills:
            switch skillWorkspaceMode {
            case .local:
                lastRefreshAt = Date()
                guard let selectedSkillID,
                      let index = skills.firstIndex(where: { $0.id == selectedSkillID }) else { return }
                skills[index].updatedAt = lastRefreshAt
            case .store:
                Task {
                    await refreshRemoteSkills()
                }
            case .recycleBin:
                Task {
                    await refreshRecycleBin()
                }
            }
        case .overview:
            lastRefreshAt = Date()
            refreshStoredSecretFlags()
        case .services:
            Task {
                await refreshServices()
            }
        case .orders:
            Task {
                await refreshTrackedOrders()
            }
        case .graph:
            Task {
                await refreshKnowledgeGraphCurrentWorkspace()
            }
        case .activity:
            lastRefreshAt = Date()
        }
    }

    func performPrimaryAction() {
        switch selectedSection {
        case .overview:
            refreshCurrentSection()
        case .nodes:
            prepareNodeConnection()
        case .credits:
            performCreditSprintPrimaryAction()
        case .bounties:
            refreshCurrentSection()
        case .skills:
            if skillWorkspaceMode == .local {
                prepareSkillImport()
            } else {
                refreshCurrentSection()
            }
        case .services:
            prepareServiceComposerForPublish()
        case .orders:
            refreshCurrentSection()
        case .graph:
            switch graphWorkspaceMode {
            case .myGraph:
                Task {
                    await refreshKnowledgeGraphMyGraph()
                }
            case .search:
                Task {
                    await runKnowledgeGraphQuery()
                }
            case .manage:
                Task {
                    await submitKnowledgeGraphIngest()
                }
            }
        case .activity:
            break
        }
    }

    func performCreditSprintPrimaryAction() {
        setSection(.bounties)
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func refreshOfficialAccountBalance() async {
        guard !isLoadingAccountBalance else { return }
        let apiKey = ConsoleAppSettings.kgAPIKey.nonEmpty
        guard let apiKey else {
            accountBalanceErrorMessage = AppLocalization.string(
                "credits.balance.error.no_api_key",
                fallback: "Save an EvoMap API key in Settings before refreshing official account balance from this app."
            )
            accountBalanceMessage = nil
            return
        }

        isLoadingAccountBalance = true
        accountBalanceErrorMessage = nil
        accountBalanceMessage = nil
        defer { isLoadingAccountBalance = false }

        do {
            let response = try await client.accountBalance(
                request: EvoMapAccountBalanceRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    apiKey: apiKey
                )
            )
            accountBalanceSnapshot = response
            accountBalanceMessage = AppLocalization.string(
                "credits.balance.message.synced",
                fallback: "Official balance refreshed from /account/balance."
            )
        } catch {
            accountBalanceErrorMessage = error.localizedDescription
        }
    }

    func refreshBountyTasks() async {
        await loadBountyTasks(page: 1, append: false)
        await refreshClaimedBountyTasks()
    }

    func loadMoreBountyTasks() async {
        guard hasMoreBountyTasks else { return }
        await loadBountyTasks(page: max(bountyTaskCurrentPage + 1, 1), append: true)
    }

    func refreshClaimedBountyTasks() async {
        guard !isLoadingClaimedBountyTasks else { return }
        guard let node = selectedOrFirstCreditNode else {
            bountyTaskErrorMessage = AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
            return
        }

        isLoadingClaimedBountyTasks = true
        defer { isLoadingClaimedBountyTasks = false }

        do {
            let response = try await client.myBountyTasks(
                request: EvoMapMyBountyTasksRequest(
                    baseURL: node.apiBaseURL,
                    nodeID: node.senderID,
                    nodeSecret: loadStoredSecret(for: node.senderID)?.nonEmpty
                )
            )
            applyClaimedBountyTaskResponse(response)
        } catch {
            bountyTaskErrorMessage = error.localizedDescription
        }
    }

    private func loadBountyTasks(page: Int, append: Bool) async {
        guard !isLoadingBountyTasks else { return }
        guard let node = selectedOrFirstCreditNode else {
            bountyTaskErrorMessage = AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
            return
        }

        isLoadingBountyTasks = true
        bountyTaskErrorMessage = nil
        bountyTaskMessage = nil
        defer { isLoadingBountyTasks = false }

        do {
            await refreshNodeProfile(for: node)
            let response = try await client.listPublicBountyTasks(
                request: EvoMapPublicBountyTaskListRequest(
                    baseURL: node.apiBaseURL,
                    limit: Self.bountyTaskPageSize,
                    page: page,
                    hasBounty: true
                )
            )
            applyBountyTaskResponse(response, page: page, append: append)
            bountyTaskMessage = AppLocalization.string(
                "credits.bounty.message.loaded_public",
                fallback: "Loaded %d of %@ public bounty task(s). Claiming still depends on node eligibility.",
                bountyTasks.count,
                response.total.map { $0.formatted(.number) } ?? AppLocalization.unknown
            )
        } catch {
            guard append == false else {
                bountyTaskErrorMessage = error.localizedDescription
                return
            }
            guard let nodeSecret = loadStoredSecret(for: node.senderID)?.nonEmpty else {
                bountyTaskErrorMessage = AppLocalization.string(
                    "credits.bounty.blocker.no_secret",
                    fallback: "Run /a2a/hello first so the node_secret is stored in Keychain."
                )
                return
            }

            do {
                let response = try await client.listBountyTasks(
                    request: EvoMapBountyTaskListRequest(
                        baseURL: node.apiBaseURL,
                        nodeSecret: nodeSecret,
                        minBounty: 1,
                        limit: Self.bountyTaskPageSize
                    )
                )
                applyBountyTaskResponse(response, page: 1, append: false)
                bountyTaskMessage = response.message?.nonEmpty ?? AppLocalization.string(
                    "credits.bounty.message.loaded",
                    fallback: "Loaded %d bounty task(s).",
                    bountyTasks.count
                )
            } catch {
                bountyTaskErrorMessage = error.localizedDescription
            }
        }
    }

    private func applyBountyTaskResponse(_ response: EvoMapBountyTaskListResponse, page: Int, append: Bool) {
        if append {
            let existingIDs = Set(bountyTasks.map(\.id))
            bountyTasks += response.tasks.filter { existingIDs.contains($0.id) == false }
        } else {
            bountyTasks = response.tasks
        }
        bountyTaskTotalCount = response.total
        bountyTaskOpenCount = response.openCount
        bountyTaskMatchedCount = response.matchedCount
        bountyTaskCurrentPage = page
        selectedBountyTaskID = preferredBountySelectionID()
        loadSelectedBountyAnswerDraft()
    }

    private func applyClaimedBountyTaskResponse(_ response: EvoMapMyBountyTasksResponse) {
        claimedBountyTasks = response.tasks

        let existingIDs = Set(bountyTasks.map(\.id))
        let claimedDisplayTasks = response.tasks
            .map { EvoMapBountyTask(claimedTask: $0) }
            .filter { existingIDs.contains($0.id) == false }

        if claimedDisplayTasks.isEmpty == false {
            bountyTasks = claimedDisplayTasks + bountyTasks
        }

        if let selectedBountyTaskID,
           bountyTasks.contains(where: { $0.id == selectedBountyTaskID }) {
            loadSelectedBountyAnswerDraft()
        } else {
            selectedBountyTaskID = preferredBountySelectionID()
        }
    }

    private func preferredBountySelectionID(preservingCurrent: Bool = true, excluding excludedTaskID: String? = nil) -> String? {
        if let selectedBountyTaskID,
           selectedBountyTaskID != excludedTaskID,
           preservingCurrent,
           let selected = bountyTasks.first(where: { $0.id == selectedBountyTaskID }),
           bountyShowsAllLoadedTasks || bountyTaskIsDefaultVisible(selected) || followedBountyTaskIDs.contains(selected.id) {
            return selectedBountyTaskID
        }
        return bountyTasks.first(where: { task in
            task.id != excludedTaskID && bountyTaskIsDefaultVisible(task)
        })?.id ?? bountyTasks.first(where: { $0.id != excludedTaskID })?.id
    }

    private func refreshNodeProfile(for node: NodeRecord) async {
        guard node.isSampleData == false else { return }
        do {
            let profile = try await client.nodeProfile(
                request: EvoMapNodeProfileRequest(baseURL: node.apiBaseURL, nodeID: node.senderID)
            )
            applyNodeProfile(profile, for: node.id)
        } catch {
            // Public node profile is advisory. Do not block bounty loading when it is unavailable.
        }
    }

    private func applyNodeProfile(_ profile: EvoMapNodeProfileResponse, for nodeID: NodeRecord.ID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var node = nodes[index]
        node.reputationScore = profile.reputationScore ?? node.reputationScore
        node.survivalStatus = profile.survivalStatus ?? node.survivalStatus
        if let online = profile.online {
            node.heartbeat = online ? node.heartbeat : .offline
        }
        nodes[index] = node
        persistLiveNodes()
    }

    func claimBountyTask(_ task: EvoMapBountyTask?) async {
        guard activeBountyClaimTaskID == nil else { return }
        guard let task else { return }
        guard task.claimableTaskID != nil || task.bountyID?.nonEmpty != nil else {
            bountyTaskErrorMessage = AppLocalization.string(
                "credits.bounty.error.no_claimable_task",
                fallback: "This public bounty row does not include a claimable task ID."
            )
            return
        }
        guard let node = selectedOrFirstCreditNode else {
            bountyTaskErrorMessage = AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
            return
        }
        guard node.claimState == .claimed else {
            bountyTaskErrorMessage = AppLocalization.string(
                "credits.bounty.blocker.node_not_claimed",
                fallback: "Finish node claim in Nodes first, then return here to claim bounty tasks."
            )
            return
        }
        await refreshNodeProfile(for: node)
        guard bountyTaskCanAttemptClaim(task) else {
            bountyTaskErrorMessage = AppLocalization.string(
                "credits.bounty.error.task_not_open_hint",
                fallback: "This bounty is not open for claiming now (status: %@). It may already be matched, pending, closed, or stale. Refresh bounties or choose an Open task.",
                AppLocalization.bountyTerm(task.status) ?? task.status ?? AppLocalization.unknown
            )
            return
        }
        guard canSelectedNodeClaimBounty(task) != false else {
            bountyTaskErrorMessage = selectedBountyEligibilityLine
            return
        }
        guard let nodeSecret = loadStoredSecret(for: node.senderID)?.nonEmpty else {
            bountyTaskErrorMessage = AppLocalization.string(
                "credits.bounty.blocker.no_secret",
                fallback: "Run /a2a/hello first so the node_secret is stored in Keychain."
            )
            return
        }

        activeBountyClaimTaskID = task.id
        bountyTaskErrorMessage = nil
        bountyTaskMessage = nil
        defer { activeBountyClaimTaskID = nil }

        do {
            let claimTaskID = try await claimableTaskID(for: task, baseURL: node.apiBaseURL)
            let response = try await client.claimBountyTask(
                request: EvoMapBountyTaskClaimRequest(
                    baseURL: node.apiBaseURL,
                    nodeSecret: nodeSecret,
                    payload: EvoMapBountyTaskClaimPayload(
                        senderID: node.senderID,
                        nodeID: node.senderID,
                        taskID: claimTaskID
                    )
                )
            )
            bountyTaskMessage = response.message?.nonEmpty ?? AppLocalization.string(
                "credits.bounty.message.claimed",
                fallback: "Claimed task %@.",
                response.taskID ?? claimTaskID
            )
            selectedBountyTaskID = task.id
            followBountyTask(task)
            await refreshClaimedBountyTasks()
        } catch {
            if Self.isTaskNotOpenError(error) {
                locallyClosedBountyTaskIDs.insert(task.id)
                selectedBountyTaskID = preferredBountySelectionID(preservingCurrent: false, excluding: task.id)
            }
            bountyTaskErrorMessage = Self.bountyClaimFailureMessage(error)
        }
    }

    func toggleSelectedBountyTaskFollow() {
        guard let task = selectedBountyTask else { return }
        if followedBountyTaskIDs.contains(task.id) {
            followedBountyTaskIDs.remove(task.id)
        } else {
            followedBountyTaskIDs.insert(task.id)
        }
        persistFollowedBountyTaskIDs()
    }

    func isFollowingBountyTask(_ task: EvoMapBountyTask) -> Bool {
        followedBountyTaskIDs.contains(task.id)
    }

    private func followBountyTask(_ task: EvoMapBountyTask) {
        guard followedBountyTaskIDs.contains(task.id) == false else { return }
        followedBountyTaskIDs.insert(task.id)
        persistFollowedBountyTaskIDs()
    }

    func canClaimBountyTask(_ task: EvoMapBountyTask?) -> Bool {
        guard let task else { return false }
        return activeBountyClaimTaskID == nil
            && bountyTaskPrerequisiteBlocker == nil
            && bountyTaskCanAttemptClaim(task)
            && canSelectedNodeClaimBounty(task) != false
    }

    private func claimableTaskID(for task: EvoMapBountyTask, baseURL: String) async throws -> String {
        if let claimableTaskID = task.claimableTaskID {
            return claimableTaskID
        }

        guard let bountyID = task.bountyID?.nonEmpty else {
            throw NSError(
                domain: "EvomapConsole.BountyTask",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: AppLocalization.string(
                        "credits.bounty.error.no_claimable_task",
                        fallback: "This public bounty row does not include a claimable task ID."
                    )
                ]
            )
        }

        let detail = try await client.bountyDetail(
            request: EvoMapBountyDetailRequest(baseURL: baseURL, bountyID: bountyID)
        )
        guard let taskID = detail.taskID?.nonEmpty else {
            throw NSError(
                domain: "EvomapConsole.BountyTask",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: AppLocalization.string(
                        "credits.bounty.error.no_claimable_task",
                        fallback: "This public bounty row does not include a claimable task ID."
                    )
                ]
            )
        }
        return taskID
    }

    func selectClaimedBountyTask(_ claimedTask: EvoMapClaimedBountyTask) {
        let displayTask = bountyTasks.first { bountyTaskMatchesClaimedTask($0, claimed: claimedTask) }
            ?? EvoMapBountyTask(claimedTask: claimedTask)
        if bountyTasks.contains(where: { $0.id == displayTask.id }) == false {
            bountyTasks.insert(displayTask, at: 0)
        }
        selectedBountyTaskID = displayTask.id
    }

    func isClaimedBountyTask(_ task: EvoMapBountyTask) -> Bool {
        claimedBountyTask(for: task) != nil
    }

    func claimedSubmissionStatus(for task: EvoMapBountyTask) -> String? {
        let claimed = claimedBountyTask(for: task)
        return AppLocalization.bountyTerm(claimed?.mySubmissionStatus ?? claimed?.status)
            ?? claimed?.mySubmissionStatus
            ?? claimed?.status
    }

    func generateSelectedBountySubmissionStructure() {
        guard let task = selectedBountyTask else { return }
        let now = Date()
        let claimed = claimedBountyTask(for: task)
        bountyAnswerDraft = BountyAnswerDraft(
            taskKey: bountyDraftKey(for: task),
            taskID: claimed?.taskID ?? task.claimableTaskID,
            bountyID: task.bountyID,
            questionID: task.questionID,
            title: task.title,
            body: bountyBody(for: task),
            implementationNotes: defaultBountyImplementationNotes(for: task, claimedTask: claimed),
            answerText: defaultBountyAnswerText(for: task),
            verificationNotes: defaultBountyVerificationNotes(for: task),
            followupQuestion: "",
            generatedAt: now,
            updatedAt: now,
            publishedAssetID: claimed?.mySubmissionAssetID,
            submissionID: claimed?.mySubmissionID,
            submissionStatus: claimed?.mySubmissionStatus,
            patchCourierRequestID: bountyAnswerDraft.patchCourierRequestID,
            patchCourierTaskID: bountyAnswerDraft.patchCourierTaskID,
            patchCourierStatus: bountyAnswerDraft.patchCourierStatus,
            patchCourierThreadToken: bountyAnswerDraft.patchCourierThreadToken,
            patchCourierSentAt: bountyAnswerDraft.patchCourierSentAt,
            patchCourierReceivedAt: bountyAnswerDraft.patchCourierReceivedAt,
            patchCourierMessageID: bountyAnswerDraft.patchCourierMessageID,
            patchCourierConfidence: bountyAnswerDraft.patchCourierConfidence,
            patchCourierRiskFlags: bountyAnswerDraft.patchCourierRiskFlags
        )
        persistSelectedBountyAnswerDraft()
        bountyAnswerDraftMessage = AppLocalization.string(
            "bounties.delivery.message.generated",
            fallback: "Generated a local implementation and submission structure. Review the answer before publishing."
        )
        bountyAnswerDraftErrorMessage = nil
    }

    func saveSelectedBountyAnswerDraft() {
        guard selectedBountyTask != nil else { return }
        persistSelectedBountyAnswerDraft()
        bountyAnswerDraftMessage = AppLocalization.string(
            "bounties.delivery.message.saved",
            fallback: "Draft saved locally on this Mac."
        )
        bountyAnswerDraftErrorMessage = nil
    }

    func copySelectedBountyExecutionBrief() {
        copyToPasteboard(selectedBountyExecutionBrief)
        bountyExecutionMessage = AppLocalization.string(
            "bounties.executor.message.brief_copied",
            fallback: "Execution brief copied. Paste it into Codex, Claude Code, or your model workflow."
        )
    }

    func copySelectedBountyExecutionCommand() {
        copyToPasteboard(selectedBountyExecutionCommand)
        bountyExecutionMessage = AppLocalization.string(
            "bounties.executor.message.command_copied",
            fallback: "Execution command copied. Run it in Terminal, then paste the produced answer back into Final answer."
        )
    }

    func runSelectedBountyAutopilot() {
        guard isRunningBountyAutopilot == false else { return }
        guard selectedBountyTask != nil else {
            bountyAutopilotErrorMessage = AppLocalization.string(
                "bounties.autopilot.error.no_selected",
                fallback: "Select a bounty before running automation."
            )
            return
        }
        startBountyAutopilotTask(mode: .selected)
    }

    func startBountyAutopilot() {
        guard isRunningBountyAutopilot == false else { return }
        startBountyAutopilotTask(mode: .nextCandidate)
    }

    func cancelBountyAutopilot() {
        guard let task = bountyAutopilotTask else { return }
        guard isCancellingBountyAutopilot == false else { return }
        isCancellingBountyAutopilot = true
        bountyAutopilotMessage = AppLocalization.string(
            "bounties.autopilot.cancelling",
            fallback: "Cancelling current run after the in-flight step."
        )
        task.cancel()
    }

    private enum BountyAutopilotMode {
        case nextCandidate, selected
    }

    private func startBountyAutopilotTask(mode: BountyAutopilotMode) {
        isRunningBountyAutopilot = true
        bountyAutopilotMessage = nil
        bountyAutopilotErrorMessage = nil
        bountyAutopilotTask = Task { [weak self] in
            await self?.runBountyAutopilotInternal(mode: mode)
        }
    }

    @MainActor
    private func runBountyAutopilotInternal(mode: BountyAutopilotMode) async {
        defer {
            isRunningBountyAutopilot = false
            isCancellingBountyAutopilot = false
            bountyAutopilotTask = nil
        }

        let runID = createBountyAutopilotRun()

        do {
            switch mode {
            case .selected:
                guard let task = selectedBountyTask else {
                    throw Self.autopilotError(AppLocalization.string(
                        "bounties.autopilot.error.no_selected",
                        fallback: "Select a bounty before running automation."
                    ))
                }
                appendBountyAutopilotEvent(
                    runID: runID,
                    status: .scanning,
                    title: AppLocalization.string("bounties.autopilot.event.selected.title", fallback: "Selected bounty locked"),
                    detail: AppLocalization.string("bounties.autopilot.event.selected.detail", fallback: "Using the currently selected bounty instead of scanning for the next candidate.")
                )
                await refreshClaimedBountyTasks()
                try Task.checkCancellation()
                try await runBountyAutopilot(
                    task: task,
                    candidate: nil,
                    runID: runID,
                    selectionDetail: AppLocalization.string(
                        "bounties.autopilot.event.choose.selected_detail",
                        fallback: "Manual selection · direct model and Skills execution through OpenClaw."
                    )
                )

            case .nextCandidate:
                appendBountyAutopilotEvent(
                    runID: runID,
                    status: .scanning,
                    title: AppLocalization.string("bounties.autopilot.event.scan.title", fallback: "Scanning bounty board"),
                    detail: AppLocalization.string("bounties.autopilot.event.scan.detail", fallback: "Refreshing public bounties and claimed tasks before choosing a candidate.")
                )
                if bountyTasks.isEmpty {
                    await refreshBountyTasks()
                } else {
                    await refreshClaimedBountyTasks()
                }
                try Task.checkCancellation()

                var paginationAttempts = 0
                let maxPaginationAttempts = 3
                while bountyAutopilotCandidates.isEmpty && hasMoreBountyTasks && paginationAttempts < maxPaginationAttempts {
                    try Task.checkCancellation()
                    appendBountyAutopilotEvent(
                        runID: runID,
                        status: .scanning,
                        title: AppLocalization.string("bounties.autopilot.event.paginate.title", fallback: "Loading more bounties"),
                        detail: AppLocalization.string(
                            "bounties.autopilot.event.paginate.detail",
                            fallback: "No suitable candidate in current page (attempt %d). Pulling the next page.",
                            paginationAttempts + 1
                        )
                    )
                    await loadMoreBountyTasks()
                    paginationAttempts += 1
                }
                try Task.checkCancellation()

                guard let candidate = bountyAutopilotCandidates.first else {
                    throw Self.autopilotError(AppLocalization.string(
                        "bounties.autopilot.error.no_candidate",
                        fallback: "No suitable bounty candidate found. Refresh bounties or lower the filter."
                    ))
                }
                try await runBountyAutopilot(
                    task: candidate.task,
                    candidate: candidate,
                    runID: runID,
                    selectionDetail: "\(candidate.score) · \(candidate.reasons.joined(separator: " · "))"
                )
            }
        } catch is CancellationError {
            completeBountyAutopilotRunWithError(
                Self.autopilotError(AppLocalization.string(
                    "bounties.autopilot.error.cancelled",
                    fallback: "Run cancelled by operator."
                )),
                runID: runID
            )
        } catch {
            completeBountyAutopilotRunWithError(error, runID: runID)
        }
    }

    private func runBountyAutopilot(
        task: EvoMapBountyTask,
        candidate: BountyAutopilotCandidate?,
        runID: BountyAutopilotRun.ID,
        selectionDetail: String
    ) async throws {
        selectedBountyTaskID = task.id
        followBountyTask(task)
        updateBountyAutopilotRun(runID) { run in
            run.taskID = task.claimableTaskID ?? task.taskID
            run.bountyID = task.bountyID
            run.title = AppLocalization.bountyText(task.title)
            run.rewardCredits = task.displayCredits
            run.score = candidate?.score
        }
        appendBountyAutopilotEvent(
            runID: runID,
            status: .scanning,
            title: AppLocalization.string("bounties.autopilot.event.choose.title", fallback: "Selected candidate"),
            detail: selectionDetail
        )

        try Task.checkCancellation()

        if claimedBountyTask(for: task) == nil {
            appendBountyAutopilotEvent(
                runID: runID,
                status: .claiming,
                title: AppLocalization.string("bounties.autopilot.event.claim.title", fallback: "Claiming in EvoMap"),
                detail: selectedBountyClaimContextLine ?? AppLocalization.string("bounties.autopilot.event.claim.detail", fallback: "Resolving task_id and claiming with the selected node.")
            )
            await claimBountyTask(task)
        }

        guard claimedBountyTask(for: task) != nil else {
            throw Self.autopilotError(bountyTaskErrorMessage ?? AppLocalization.string(
                "bounties.autopilot.error.claim_failed",
                fallback: "Autopilot could not claim the selected bounty."
            ))
        }

        try Task.checkCancellation()

        let prompt = selectedBountyExecutionBrief
        updateBountyAutopilotRun(runID) { run in
            run.prompt = prompt
        }
        appendBountyAutopilotEvent(
            runID: runID,
            status: .executing,
            title: AppLocalization.string("bounties.autopilot.event.prompt.title", fallback: "Prompt locked"),
            detail: AppLocalization.string("bounties.autopilot.event.prompt.detail", fallback: "The exact OpenClaw prompt is saved on this run for later review.")
        )

        bountyAutopilotLiveOutput = ""
        let rawOutput: String
        let finalAnswer: String
        let verificationLine: String

        if bountyAutopilotUseNativeEngine {
            let engineInput = BountyWorkflowEngine.Input(
                title: AppLocalization.bountyText(task.title),
                body: bountyBody(for: task).map { AppLocalization.bountyText($0) },
                rewardCredits: task.displayCredits,
                taskID: claimedBountyTask(for: task)?.taskID ?? task.claimableTaskID ?? task.id,
                bountyID: task.bountyID ?? task.id,
                currentDraft: bountyAnswerDraft.answerText.nonEmpty
            )
            let result = BountyWorkflowEngine.run(input: engineInput)
            try Task.checkCancellation()
            switch result {
            case .skipped(let reason):
                throw Self.autopilotError(reason.summary)
            case .answered(let answer):
                finalAnswer = answer.markdown
                rawOutput = [
                    "template_id: \(answer.templateID)",
                    "template_title: \(answer.templateTitle)",
                    "score: \(answer.matchScore)",
                    "signals: \(answer.signals.joined(separator: ", "))",
                    "reasons: \(answer.matchReasons.joined(separator: ", "))",
                    "",
                    answer.markdown
                ].joined(separator: "\n")
                verificationLine = answer.verificationNote
                bountyAutopilotLiveOutput = rawOutput
            }
        } else {
            let result = try await Task.detached { [weak self] in
                try Self.runOpenClawAgentCommand(brief: prompt) { chunk in
                    Task { @MainActor in
                        self?.bountyAutopilotLiveOutput.append(chunk)
                    }
                }
            }.value
            try Task.checkCancellation()
            rawOutput = result.combinedOutput
            finalAnswer = Self.extractAgentAnswer(from: result.stdout.nonEmpty ?? rawOutput)
            guard finalAnswer.nonEmpty != nil else {
                throw Self.autopilotError(AppLocalization.string(
                    "bounties.autopilot.error.empty_answer",
                    fallback: "OpenClaw returned no usable final answer."
                ))
            }
            verificationLine = AppLocalization.string(
                "bounties.autopilot.verification.generated",
                fallback: "Generated by Console Autopilot through OpenClaw. Review the saved prompt, raw output, and final answer before submission."
            )
        }

        bountyAnswerDraft.answerText = finalAnswer
        bountyAnswerDraft.generatedAt = Date()
        bountyAnswerDraft.updatedAt = Date()
        bountyAnswerDraft.verificationNotes = [
            bountyAnswerDraft.verificationNotes.nonEmpty,
            verificationLine
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        persistSelectedBountyAnswerDraft()

        updateBountyAutopilotRun(runID) { run in
            run.rawExecutorOutput = rawOutput
            run.finalAnswerPreview = String(finalAnswer.prefix(600))
        }
        appendBountyAutopilotEvent(
            runID: runID,
            status: bountyAutopilotAutoSubmit ? .submitting : .needsReview,
            title: AppLocalization.string("bounties.autopilot.event.answer.title", fallback: "Draft answer captured"),
            detail: AppLocalization.string("bounties.autopilot.event.answer.detail", fallback: "The answer has been written back into the Final answer field.")
        )

        if bountyAutopilotAutoSubmit {
            await submitSelectedBountyAnswer()
            if let error = bountyAnswerDraftErrorMessage?.nonEmpty {
                throw Self.autopilotError(error)
            }
            updateBountyAutopilotRun(runID) { run in
                run.status = .completed
                run.completedAt = Date()
                run.submissionID = bountyAnswerDraft.submissionID
                run.publishedAssetID = bountyAnswerDraft.publishedAssetID
            }
            appendBountyAutopilotEvent(
                runID: runID,
                status: .completed,
                title: AppLocalization.string("bounties.autopilot.event.complete.title", fallback: "Submitted to EvoMap"),
                detail: bountyAnswerDraftMessage ?? AppLocalization.string("bounties.autopilot.event.complete.detail", fallback: "Published and completed through EvoMap.")
            )
        } else {
            updateBountyAutopilotRun(runID) { run in
                run.status = .needsReview
                run.completedAt = Date()
            }
            bountyAutopilotMessage = AppLocalization.string(
                "bounties.autopilot.message.needs_review",
                fallback: "Autopilot finished the draft. Review the process and submit manually."
            )
        }
    }

    private func completeBountyAutopilotRunWithError(_ error: Error, runID: BountyAutopilotRun.ID) {
        updateBountyAutopilotRun(runID) { run in
            run.status = .failed
            run.completedAt = Date()
            run.errorMessage = error.localizedDescription
        }
        appendBountyAutopilotEvent(
            runID: runID,
            status: .failed,
            title: AppLocalization.string("bounties.autopilot.event.failed.title", fallback: "Run failed"),
            detail: error.localizedDescription
        )
        bountyAutopilotErrorMessage = error.localizedDescription
    }

    func importOpenClawBountyHistory() async {
        guard isImportingBountyAutopilotHistory == false else { return }
        isImportingBountyAutopilotHistory = true
        bountyAutopilotMessage = nil
        bountyAutopilotErrorMessage = nil
        defer { isImportingBountyAutopilotHistory = false }

        do {
            let existingKeys = Set(bountyAutopilotRuns.compactMap(Self.bountyAutopilotDedupeKey))
            let imported = try await Task.detached {
                try Self.loadOpenClawBountyHistoryRuns(existingKeys: existingKeys)
            }.value

            guard imported.isEmpty == false else {
                bountyAutopilotMessage = AppLocalization.string(
                    "bounties.autopilot.import.none",
                    fallback: "No new EvoMap bounty history found in OpenClaw workspace."
                )
                return
            }

            bountyAutopilotRuns = (imported + bountyAutopilotRuns)
                .sorted { $0.updatedAt > $1.updatedAt }
            if bountyAutopilotRuns.count > 120 {
                bountyAutopilotRuns.removeLast(bountyAutopilotRuns.count - 120)
            }
            selectedBountyAutopilotRunID = bountyAutopilotRuns.first?.id
            persistBountyAutopilotRuns()
            bountyAutopilotMessage = AppLocalization.string(
                "bounties.autopilot.import.done",
                fallback: "Imported %d historical OpenClaw bounty run(s).",
                imported.count
            )
        } catch {
            bountyAutopilotErrorMessage = error.localizedDescription
        }
    }

    private func createBountyAutopilotRun() -> BountyAutopilotRun.ID {
        let run = BountyAutopilotRun(
            status: .queued,
            taskID: nil,
            bountyID: nil,
            title: AppLocalization.string("bounties.autopilot.run.pending_title", fallback: "Choosing bounty"),
            rewardCredits: nil,
            score: nil,
            executor: .openClaw,
            autoSubmitEnabled: bountyAutopilotAutoSubmit,
            events: [
                BountyAutopilotEvent(
                    title: AppLocalization.string("bounties.autopilot.event.started.title", fallback: "Run started"),
                    detail: AppLocalization.string("bounties.autopilot.event.started.detail", fallback: "Console owns this run, so every prompt, answer, and submission decision is recorded."),
                    status: .queued
                )
            ]
        )
        bountyAutopilotRuns.insert(run, at: 0)
        selectedBountyAutopilotRunID = run.id
        persistBountyAutopilotRuns()
        return run.id
    }

    private func appendBountyAutopilotEvent(
        runID: BountyAutopilotRun.ID,
        status: BountyAutopilotRunStatus,
        title: String,
        detail: String
    ) {
        updateBountyAutopilotRun(runID) { run in
            run.status = status
            run.events.append(BountyAutopilotEvent(title: title, detail: detail, status: status))
        }
    }

    private func updateBountyAutopilotRun(
        _ runID: BountyAutopilotRun.ID,
        mutate: (inout BountyAutopilotRun) -> Void
    ) {
        guard let index = bountyAutopilotRuns.firstIndex(where: { $0.id == runID }) else { return }
        mutate(&bountyAutopilotRuns[index])
        bountyAutopilotRuns[index].updatedAt = Date()
        if bountyAutopilotRuns.count > 50 {
            bountyAutopilotRuns.removeLast(bountyAutopilotRuns.count - 50)
        }
        persistBountyAutopilotRuns()
    }

    private func persistBountyAutopilotRuns() {
        Self.saveBountyAutopilotRuns(bountyAutopilotRuns)
    }

    nonisolated private static func runOpenClawAgentCommand(
        brief: String,
        onChunk: (@Sendable (String) -> Void)? = nil
    ) throws -> ShellCommandResult {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let workdir = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("EvomapConsole", isDirectory: true)
            .appendingPathComponent("TaskRuns", isDirectory: true)
        try fileManager.createDirectory(at: workdir, withIntermediateDirectories: true)

        let openClawCandidates = [
            home.appendingPathComponent(".openclaw/bin/openclaw").path,
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
        ]
        let openClawPath = openClawCandidates.first { fileManager.isExecutableFile(atPath: $0) }
        let process = Process()
        if let openClawPath {
            process.executableURL = URL(fileURLWithPath: openClawPath)
            process.arguments = [
                "agent",
                "--local",
                "--agent",
                "main",
                "--timeout",
                "600",
                "--json",
                "--message",
                brief,
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "openclaw",
                "agent",
                "--local",
                "--agent",
                "main",
                "--timeout",
                "600",
                "--json",
                "--message",
                brief,
            ]
        }
        process.currentDirectoryURL = workdir

        var environment = ProcessInfo.processInfo.environment
        let extraPath = [
            home.appendingPathComponent(".openclaw/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ].joined(separator: ":")
        environment["PATH"] = [extraPath, environment["PATH"]].compactMap { $0 }.joined(separator: ":")
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBuffer = NSMutableString()
        let bufferLock = NSLock()
        if let onChunk {
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard data.isEmpty == false else {
                    handle.readabilityHandler = nil
                    return
                }
                if let chunk = String(data: data, encoding: .utf8) {
                    bufferLock.lock()
                    stdoutBuffer.append(chunk)
                    bufferLock.unlock()
                    onChunk(chunk)
                }
            }
        }

        do {
            try process.run()
        } catch {
            throw autopilotError("Could not launch OpenClaw: \(error.localizedDescription)")
        }

        let timeoutSeconds: TimeInterval = 660
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            throw autopilotError("OpenClaw timed out after \(Int(timeoutSeconds)) seconds.")
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        let stdoutTail = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stdout: String
        if onChunk != nil {
            bufferLock.lock()
            stdoutBuffer.append(stdoutTail)
            stdout = (stdoutBuffer as String).trimmingCharacters(in: .whitespacesAndNewlines)
            bufferLock.unlock()
        } else {
            stdout = stdoutTail.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let result = ShellCommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
        guard process.terminationStatus == 0 else {
            throw autopilotError(result.combinedOutput.nonEmpty ?? "OpenClaw exited with status \(process.terminationStatus).")
        }
        return result
    }

    nonisolated private static func extractAgentAnswer(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let value = bestTextValue(in: object)?.nonEmpty {
            return value
        }

        return trimmed
    }

    nonisolated private static func bestTextValue(in object: Any) -> String? {
        if let string = object as? String {
            return string
        }
        if let array = object as? [Any] {
            return array.compactMap { bestTextValue(in: $0) }.first(where: { $0.nonEmpty != nil })
        }
        guard let dictionary = object as? [String: Any] else { return nil }

        let preferredKeys = [
            "final_answer",
            "finalAnswer",
            "answer",
            "reply",
            "response",
            "message",
            "text",
            "content",
            "output",
            "result",
        ]
        for key in preferredKeys {
            if let value = dictionary[key],
               let text = bestTextValue(in: value)?.nonEmpty {
                return text
            }
        }
        return dictionary.values.compactMap { bestTextValue(in: $0) }.first(where: { $0.nonEmpty != nil })
    }

    nonisolated private static func autopilotError(_ message: String) -> NSError {
        NSError(
            domain: "EvomapConsole.BountyAutopilot",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    nonisolated private static func bountyAutopilotDedupeKey(for run: BountyAutopilotRun) -> String? {
        if let taskID = run.taskID?.nonEmpty {
            return "task:\(taskID)"
        }
        if let bountyID = run.bountyID?.nonEmpty {
            return "bounty:\(bountyID)"
        }
        return nil
    }

    nonisolated private struct ImportedOpenClawSubmission {
        var sourceURL: URL
        var sourceModifiedAt: Date
        var bountyID: String
        var taskID: String?
        var title: String
        var reward: Int?
        var summary: String?
        var content: String?
    }

    nonisolated private static func loadOpenClawBountyHistoryRuns(existingKeys: Set<String>) throws -> [BountyAutopilotRun] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let workspace = home
            .appendingPathComponent(".openclaw", isDirectory: true)
            .appendingPathComponent("workspace", isDirectory: true)
        let submissionsDirectory = workspace.appendingPathComponent("evomap-submissions", isDirectory: true)
        guard fileManager.fileExists(atPath: submissionsDirectory.path) else {
            return []
        }

        let sourceURLs = try fileManager.contentsOfDirectory(
            at: submissionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { ["js", "md"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var seenKeys = existingKeys
        var importedRuns: [BountyAutopilotRun] = []
        for sourceURL in sourceURLs {
            let text = try String(contentsOf: sourceURL, encoding: .utf8)
            let modifiedAt = (try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            let submissions: [ImportedOpenClawSubmission]
            if sourceURL.pathExtension.lowercased() == "js" {
                submissions = parseOpenClawSubmissionScript(text, sourceURL: sourceURL, modifiedAt: modifiedAt)
            } else {
                submissions = parseOpenClawSubmissionMarkdown(text, sourceURL: sourceURL, modifiedAt: modifiedAt)
            }

            for submission in submissions {
                let key = submission.taskID?.nonEmpty.map { "task:\($0)" } ?? "bounty:\(submission.bountyID)"
                guard seenKeys.contains(key) == false else { continue }
                seenKeys.insert(key)
                importedRuns.append(openClawImportedRun(from: submission))
            }
        }

        return importedRuns.sorted { $0.updatedAt > $1.updatedAt }
    }

    nonisolated private static func parseOpenClawSubmissionScript(
        _ text: String,
        sourceURL: URL,
        modifiedAt: Date
    ) -> [ImportedOpenClawSubmission] {
        let pattern = #"(?s)\{\s*bounty_id:\s*'([^']+)'.*?\},"#
        let objects = regexMatches(pattern, in: text).compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }

        return objects.compactMap { object in
            guard let bountyID = firstRegexGroup(#"bounty_id:\s*'([^']+)'"#, in: object)?.nonEmpty else {
                return nil
            }
            let title = firstRegexGroup(#"title:\s*'([^']+)'"#, in: object)
                ?? firstRegexGroup(#"title:\s*"([^"]+)""#, in: object)
                ?? bountyID
            let content = firstRegexGroup(#"(?s)content:\s*`(.*?)`\s*,?\n"#, in: object)
            return ImportedOpenClawSubmission(
                sourceURL: sourceURL,
                sourceModifiedAt: modifiedAt,
                bountyID: bountyID,
                taskID: firstRegexGroup(#"task_id:\s*'([^']+)'"#, in: object),
                title: title,
                reward: firstRegexGroup(#"reward:\s*([0-9]+)"#, in: object).flatMap(Int.init),
                summary: firstRegexGroup(#"summary:\s*'([^']*)'"#, in: object)
                    ?? firstRegexGroup(#"summary:\s*"([^"]*)""#, in: object),
                content: content
            )
        }
    }

    nonisolated private static func parseOpenClawSubmissionMarkdown(
        _ text: String,
        sourceURL: URL,
        modifiedAt: Date
    ) -> [ImportedOpenClawSubmission] {
        guard let bountyID = firstRegexGroup(#"bounty/([A-Za-z0-9_-]+)"#, in: text)
            ?? firstRegexGroup(#"(?i)bounty[_ -]?id[:：]\s*`?([A-Za-z0-9_-]+)"#, in: text) else {
            return []
        }
        let title = firstRegexGroup(#"(?m)^#\s+(.+)$"#, in: text) ?? bountyID
        let reward = firstRegexGroup(#"(?i)(?:reward observed|reward|credits)[:：]?\s*([0-9]+)"#, in: text).flatMap(Int.init)
        return [
            ImportedOpenClawSubmission(
                sourceURL: sourceURL,
                sourceModifiedAt: modifiedAt,
                bountyID: bountyID,
                taskID: firstRegexGroup(#"(?i)task[_ -]?id[:：]\s*`?([A-Za-z0-9_-]+)"#, in: text),
                title: title,
                reward: reward,
                summary: firstRegexGroup(#"(?m)^##\s+Summary\s*\n(.+)$"#, in: text),
                content: text
            )
        ]
    }

    nonisolated private static func openClawImportedRun(from submission: ImportedOpenClawSubmission) -> BountyAutopilotRun {
        let answerPreview = (submission.content ?? submission.summary ?? submission.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceName = submission.sourceURL.lastPathComponent
        let prompt = """
        Imported from OpenClaw historical artifact.
        Source: \(sourceName)
        Original session prompt is not available in EvoMap Console; this record preserves the submitted task metadata and answer preview recovered from the local OpenClaw workspace.
        """
        let rawOutput = [
            "source: \(sourceName)",
            "bounty_id: \(submission.bountyID)",
            submission.taskID.map { "task_id: \($0)" },
            submission.reward.map { "reward: \($0) credits" },
            submission.summary.map { "summary: \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        return BountyAutopilotRun(
            startedAt: submission.sourceModifiedAt,
            updatedAt: submission.sourceModifiedAt,
            completedAt: submission.sourceModifiedAt,
            status: .needsReview,
            taskID: submission.taskID,
            bountyID: submission.bountyID,
            title: submission.title,
            rewardCredits: submission.reward,
            score: nil,
            executor: .openClaw,
            autoSubmitEnabled: true,
            prompt: prompt,
            rawExecutorOutput: rawOutput,
            finalAnswerPreview: String(answerPreview.prefix(600)),
            submissionID: nil,
            publishedAssetID: nil,
            errorMessage: nil,
            events: [
                BountyAutopilotEvent(
                    timestamp: submission.sourceModifiedAt,
                    title: AppLocalization.string("bounties.autopilot.import.event.title", fallback: "Imported from OpenClaw"),
                    detail: AppLocalization.string(
                        "bounties.autopilot.import.event.detail",
                        fallback: "Recovered from %@. Verify final acceptance in EvoMap because historical scripts may include pending or attempted submissions.",
                        sourceName
                    ),
                    status: .needsReview
                ),
                BountyAutopilotEvent(
                    timestamp: submission.sourceModifiedAt,
                    title: AppLocalization.string("bounties.autopilot.import.event.answer", fallback: "Recovered answer draft"),
                    detail: String(answerPreview.prefix(240)),
                    status: .needsReview
                ),
            ]
        )
    }

    nonisolated private static func firstRegexGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
            .replacingOccurrences(of: "\\`", with: "`")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func regexMatches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range)
    }

    func sendSelectedBountyToPatchCourier() {
        openPatchCourierEmail(
            subject: selectedBountyPatchCourierExecuteEmailSubject,
            body: selectedBountyPatchCourierExecuteEmailBody,
            successMessage: AppLocalization.string(
                "bounties.patch_courier.message.execute_opened",
                fallback: "Patch Courier execute email opened. Send it from your mail app to start the remote Codex run."
            )
        )
    }

    func querySelectedBountyPatchCourierStatus() {
        openPatchCourierEmail(
            subject: selectedBountyPatchCourierStatusEmailSubject,
            body: selectedBountyPatchCourierStatusEmailBody,
            successMessage: AppLocalization.string(
                "bounties.patch_courier.message.status_opened",
                fallback: "Patch Courier status email opened. Send it to ask the relay for the latest task state."
            )
        )
    }

    func copySelectedBountyPatchCourierExecuteEmail() {
        copyToPasteboard(
            """
            To: \(ConsoleAppSettings.patchCourierRelayEmail.nonEmpty ?? AppLocalization.missing)
            Subject: \(selectedBountyPatchCourierExecuteEmailSubject)

            \(selectedBountyPatchCourierExecuteEmailBody)
            """
        )
        bountyExecutionMessage = AppLocalization.string(
            "bounties.patch_courier.message.execute_copied",
            fallback: "Patch Courier execute email copied."
        )
    }

    func sendSelectedBountyToPatchCourierBackend() async {
        guard isSendingPatchCourierBackendTask == false else { return }
        guard let task = selectedBountyTask else { return }
        guard selectedBountyTaskIsClaimed else {
            patchCourierBackendErrorMessage = AppLocalization.string(
                "bounties.patch_courier.backend.error.claim_first",
                fallback: "Claim this bounty before sending it to the Patch Courier backend."
            )
            return
        }
        guard let account = ConsoleAppSettings.patchCourierBackendAccount,
              let relayEmail = ConsoleAppSettings.patchCourierRelayEmail.nonEmpty else {
            patchCourierBackendErrorMessage = AppLocalization.string(
                "bounties.patch_courier.backend.error.not_configured",
                fallback: "Complete Patch Courier backend mail settings first."
            )
            return
        }
        guard let password = patchCourierBackendPassword()?.nonEmpty else {
            patchCourierBackendErrorMessage = AppLocalization.string(
                "bounties.patch_courier.backend.error.no_password",
                fallback: "Save the backend mailbox app password in Settings first."
            )
            return
        }

        isSendingPatchCourierBackendTask = true
        patchCourierBackendMessage = nil
        patchCourierBackendErrorMessage = nil
        defer { isSendingPatchCourierBackendTask = false }

        do {
            let taskID = selectedBountyPatchCourierTaskID(for: task)
            let requestID = selectedBountyPatchCourierRequestID(for: task)
            let message = PatchCourierOutboundMailMessage(
                to: [relayEmail],
                subject: selectedBountyPatchCourierExecuteEmailSubject,
                plainBody: selectedBountyPatchCourierExecuteEmailBody,
                htmlBody: nil,
                inReplyTo: nil,
                references: []
            )
            let result = try await Task.detached {
                try self.patchCourierMailTransportClient.sendMessage(account: account, password: password, message: message)
            }.value

            bountyAnswerDraft.patchCourierRequestID = requestID
            bountyAnswerDraft.patchCourierTaskID = taskID
            bountyAnswerDraft.patchCourierStatus = "sent"
            bountyAnswerDraft.patchCourierSentAt = Date()
            bountyAnswerDraft.patchCourierMessageID = result.messageID
            persistSelectedBountyAnswerDraft()
            startPatchCourierBackendPollingIfNeeded()
            patchCourierBackendMessage = AppLocalization.string(
                "bounties.patch_courier.backend.message.sent",
                fallback: "Task sent silently to Patch Courier. The app will check replies automatically."
            )
        } catch {
            patchCourierBackendErrorMessage = error.localizedDescription
        }
    }

    func checkSelectedBountyPatchCourierBackendInbox() async {
        await refreshPatchCourierBackendInbox(selectedOnly: true)
    }

    func startPatchCourierBackendPollingIfNeeded() {
        guard ConsoleAppSettings.patchCourierBackendEnabled else {
            isPatchCourierBackendPolling = false
            patchCourierBackendPollTask?.cancel()
            patchCourierBackendPollTask = nil
            return
        }
        guard patchCourierBackendPollTask == nil else {
            isPatchCourierBackendPolling = true
            return
        }

        isPatchCourierBackendPolling = true
        patchCourierBackendPollTask = Task { [weak self] in
            while Task.isCancelled == false {
                await self?.refreshPatchCourierBackendInbox(selectedOnly: false, isAutomatic: true)
                let interval = UInt64(max(30, ConsoleAppSettings.patchCourierBackendPollIntervalSeconds))
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            }
            await MainActor.run {
                self?.isPatchCourierBackendPolling = false
            }
        }
    }

    func stopPatchCourierBackendPolling() {
        patchCourierBackendPollTask?.cancel()
        patchCourierBackendPollTask = nil
        isPatchCourierBackendPolling = false
    }

    private func refreshPatchCourierBackendInbox(selectedOnly: Bool, isAutomatic: Bool = false) async {
        guard isCheckingPatchCourierBackendInbox == false else { return }
        guard ConsoleAppSettings.patchCourierBackendEnabled || isAutomatic == false else { return }
        guard let account = ConsoleAppSettings.patchCourierBackendAccount else {
            if isAutomatic == false {
                patchCourierBackendErrorMessage = AppLocalization.string(
                    "bounties.patch_courier.backend.error.not_configured",
                    fallback: "Complete Patch Courier backend mail settings first."
                )
            }
            return
        }
        guard let password = patchCourierBackendPassword()?.nonEmpty else {
            if isAutomatic == false {
                patchCourierBackendErrorMessage = AppLocalization.string(
                    "bounties.patch_courier.backend.error.no_password",
                    fallback: "Save the backend mailbox app password in Settings first."
                )
            }
            return
        }

        isCheckingPatchCourierBackendInbox = true
        if isAutomatic == false {
            patchCourierBackendMessage = nil
            patchCourierBackendErrorMessage = nil
        }
        defer { isCheckingPatchCourierBackendInbox = false }

        do {
            let history = try await Task.detached {
                try self.patchCourierMailTransportClient.fetchRecentHistory(account: account, password: password, limit: 100)
            }.value
            let parsedResults = history.messages.compactMap(PatchCourierExecutionResult.parse(from:))
            let updatedCount = applyPatchCourierExecutionResults(parsedResults, selectedOnly: selectedOnly)
            if isAutomatic == false {
                patchCourierBackendMessage = updatedCount > 0
                    ? AppLocalization.string("bounties.patch_courier.backend.message.updated", fallback: "Updated %d Patch Courier result(s).", updatedCount)
                    : AppLocalization.string("bounties.patch_courier.backend.message.no_result", fallback: "No matching Patch Courier result found yet.")
            }
        } catch {
            if isAutomatic == false {
                patchCourierBackendErrorMessage = error.localizedDescription
            }
        }
    }

    func submitSelectedBountyAnswer() async {
        guard isSubmittingBountyAnswer == false else { return }
        guard let task = selectedBountyTask,
              let claimedTask = claimedBountyTask(for: task) else {
            bountyAnswerDraftErrorMessage = AppLocalization.string(
                "bounties.delivery.error.not_claimed",
                fallback: "Claim this bounty before publishing and completing the answer."
            )
            return
        }
        guard let node = selectedOrFirstCreditNode,
              let nodeSecret = loadStoredSecret(for: node.senderID)?.nonEmpty else {
            bountyAnswerDraftErrorMessage = AppLocalization.string(
                "credits.bounty.blocker.no_secret",
                fallback: "Run /a2a/hello first so the node_secret is stored in Keychain."
            )
            return
        }
        guard bountyAnswerDraft.answerText.nonEmpty != nil else {
            bountyAnswerDraftErrorMessage = AppLocalization.string(
                "bounties.delivery.error.empty_answer",
                fallback: "Write the final answer before publishing."
            )
            return
        }

        isSubmittingBountyAnswer = true
        activeBountySubmissionTaskID = task.id
        bountyAnswerDraftErrorMessage = nil
        bountyAnswerDraftMessage = nil
        defer {
            isSubmittingBountyAnswer = false
            activeBountySubmissionTaskID = nil
        }

        do {
            persistSelectedBountyAnswerDraft()
            let bundle = try makeBountyPublishBundle(task: task, taskID: claimedTask.taskID, node: node, draft: bountyAnswerDraft)
            let publishResponse = try await client.publishAssetBundle(
                request: EvoMapPublishBundleRequest(
                    baseURL: node.apiBaseURL,
                    senderID: node.senderID,
                    nodeSecret: nodeSecret,
                    payload: bundle.payload
                )
            )
            let completeResponse = try await client.completeBountyTask(
                request: EvoMapBountyTaskCompleteRequest(
                    baseURL: node.apiBaseURL,
                    nodeSecret: nodeSecret,
                    payload: EvoMapBountyTaskCompletePayload(
                        senderID: node.senderID,
                        nodeID: node.senderID,
                        taskID: claimedTask.taskID,
                        assetID: bundle.capsuleAssetID,
                        followupQuestion: bountyAnswerDraft.followupQuestion.nonEmpty
                    )
                )
            )

            bountyAnswerDraft.publishedAssetID = bundle.capsuleAssetID
            bountyAnswerDraft.submissionID = completeResponse.submissionID
                ?? claimedTask.mySubmissionID
                ?? publishResponse.bundleID
            bountyAnswerDraft.submissionStatus = completeResponse.status?.nonEmpty
                ?? publishResponse.status?.nonEmpty
                ?? "submitted"
            persistSelectedBountyAnswerDraft()
            bountyAnswerDraftMessage = completeResponse.message?.nonEmpty
                ?? publishResponse.message?.nonEmpty
                ?? AppLocalization.string(
                    "bounties.delivery.message.submitted",
                    fallback: "Published the answer Capsule and completed the task. Wait for EvoMap acceptance and settlement."
                )
            await refreshClaimedBountyTasks()
        } catch {
            bountyAnswerDraftErrorMessage = error.localizedDescription
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func selectedBountyPatchCourierTaskID(for task: EvoMapBountyTask) -> String {
        selectedClaimedBountyTask?.taskID
            ?? task.claimableTaskID
            ?? task.bountyID
            ?? task.questionID
            ?? task.id
    }

    private func selectedBountyPatchCourierRequestID(for task: EvoMapBountyTask) -> String {
        "evomap:\(selectedBountyPatchCourierTaskID(for: task))"
    }

    private func patchCourierBackendPassword() -> String? {
        guard let sender = ConsoleAppSettings.patchCourierBackendSenderEmail.nonEmpty else {
            return nil
        }
        return try? patchCourierMailPasswordStore.loadPassword(account: sender)
    }

    private func applyPatchCourierExecutionResults(_ results: [PatchCourierExecutionResult], selectedOnly: Bool) -> Int {
        guard results.isEmpty == false else { return 0 }
        var drafts = Self.loadBountyAnswerDrafts()
        let targetKeys: Set<String>
        if selectedOnly, let task = selectedBountyTask {
            targetKeys = [bountyDraftKey(for: task)]
        } else {
            targetKeys = Set(drafts.keys)
        }

        var updatedCount = 0
        for key in targetKeys {
            guard var draft = drafts[key] else { continue }
            let candidates = results
                .filter { patchCourierResult($0, matches: draft) }
                .sorted { lhs, rhs in
                    if lhs.isUsableFinalAnswer != rhs.isUsableFinalAnswer {
                        return lhs.isUsableFinalAnswer
                    }
                    return lhs.receivedAt > rhs.receivedAt
                }
            guard let result = candidates.first else { continue }
            if draft.patchCourierMessageID == result.messageID {
                let incomingAnswer = result.finalAnswerMarkdown?.nonEmpty
                guard incomingAnswer != nil && incomingAnswer != draft.answerText else { continue }
            }

            draft.patchCourierRequestID = result.requestID ?? draft.patchCourierRequestID
            draft.patchCourierTaskID = result.taskID ?? draft.patchCourierTaskID
            draft.patchCourierStatus = result.status ?? (result.isUsableFinalAnswer ? "done" : "received")
            draft.patchCourierThreadToken = result.threadToken ?? draft.patchCourierThreadToken
            draft.patchCourierReceivedAt = result.receivedAt
            draft.patchCourierMessageID = result.messageID
            draft.patchCourierConfidence = result.confidence ?? draft.patchCourierConfidence
            draft.patchCourierRiskFlags = result.riskFlags ?? draft.patchCourierRiskFlags

            if let finalAnswer = result.finalAnswerMarkdown?.nonEmpty {
                draft.answerText = finalAnswer
                draft.verificationNotes = patchCourierVerificationNotes(existing: draft.verificationNotes, result: result)
            }
            draft.updatedAt = Date()
            drafts[key] = draft
            updatedCount += 1

            if bountyAnswerDraft.taskKey == key {
                bountyAnswerDraft = draft
            }
        }

        if updatedCount > 0 {
            Self.saveBountyAnswerDrafts(drafts)
        }
        return updatedCount
    }

    private func patchCourierResult(_ result: PatchCourierExecutionResult, matches draft: BountyAnswerDraft) -> Bool {
        let resultIDs = [result.requestID, result.taskID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let draftIDs = [
            draft.patchCourierRequestID,
            draft.patchCourierTaskID,
            draft.taskID,
            draft.bountyID,
            draft.questionID,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }

        guard resultIDs.isEmpty == false, draftIDs.isEmpty == false else {
            return false
        }
        let expandedResultIDs = Set(resultIDs.flatMap(Self.expandedPatchCourierIdentifierCandidates(_:)))
        let expandedDraftIDs = Set(draftIDs.flatMap(Self.expandedPatchCourierIdentifierCandidates(_:)))
        return expandedResultIDs.isDisjoint(with: expandedDraftIDs) == false
    }

    private static func expandedPatchCourierIdentifierCandidates(_ rawValue: String) -> [String] {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.isEmpty == false else { return [] }
        if value.hasPrefix("evomap:") {
            let stripped = String(value.dropFirst("evomap:".count))
            return [value, stripped].filter { $0.isEmpty == false }
        }
        return [value, "evomap:\(value)"]
    }

    private func patchCourierVerificationNotes(existing: String, result: PatchCourierExecutionResult) -> String {
        var lines = existing
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Patch Courier:") }
        lines.append(
            [
                "Patch Courier: \(result.status ?? "received")",
                result.confidence.map { "confidence \($0)" },
                result.riskFlags.map { "risk \($0)" },
                result.threadToken.map { "thread \($0)" },
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        )
        return lines.joined(separator: "\n")
    }

    private func selectedBountyPatchCourierPayload(
        task: EvoMapBountyTask,
        claimed: EvoMapClaimedBountyTask?,
        taskID: String
    ) -> String {
        let payload: [String: Any] = [
            "task_id": taskID,
            "bounty_id": task.bountyID ?? "",
            "question_id": task.questionID ?? "",
            "submission_id": claimed?.mySubmissionID ?? "",
            "submission_status": claimed?.mySubmissionStatus ?? "",
            "title": AppLocalization.bountyText(task.title),
            "body": bountyBody(for: task).map { AppLocalization.bountyText($0) } ?? "",
            "raw_title": task.title,
            "raw_body": bountyBody(for: task) ?? "",
            "reward_credits": task.displayCredits ?? 0,
            "required_reputation": bountyRequiredReputation(for: task) ?? 0,
            "node_id": selectedOrFirstCreditNode?.senderID ?? "",
            "expected_output": "final_answer_markdown",
            "current_draft": bountyAnswerDraft.answerText,
            "verification_notes": bountyAnswerDraft.verificationNotes
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func openPatchCourierEmail(subject: String, body: String, successMessage: String) {
        guard let relayEmail = ConsoleAppSettings.patchCourierRelayEmail.nonEmpty else {
            bountyExecutionMessage = AppLocalization.string(
                "bounties.patch_courier.error.no_relay",
                fallback: "Save the Patch Courier relay mailbox in Settings first."
            )
            return
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = relayEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else {
            bountyExecutionMessage = AppLocalization.string(
                "bounties.patch_courier.error.mailto",
                fallback: "Could not create the Patch Courier mailto link."
            )
            return
        }
        guard let mailAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") else {
            copyToPasteboard(patchCourierEmailEnvelope(to: relayEmail, subject: subject, body: body))
            bountyExecutionMessage = AppLocalization.string(
                "bounties.patch_courier.error.no_mail_app",
                fallback: "Could not find Apple Mail. The email was copied instead; paste it into your mail client."
            )
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: mailAppURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.copyToPasteboard(self.patchCourierEmailEnvelope(to: relayEmail, subject: subject, body: body))
                    self.bountyExecutionMessage = AppLocalization.string(
                        "bounties.patch_courier.error.mail_app_failed",
                        fallback: "Could not open Apple Mail (%@). The email was copied instead.",
                        error.localizedDescription
                    )
                    return
                }
                self.bountyExecutionMessage = successMessage
            }
        }
    }

    private func patchCourierEmailEnvelope(to relayEmail: String, subject: String, body: String) -> String {
        """
        To: \(relayEmail)
        Subject: \(subject)

        \(body)
        """
    }

    private func claimedBountyTask(for task: EvoMapBountyTask) -> EvoMapClaimedBountyTask? {
        claimedBountyTasks.first { bountyTaskMatchesClaimedTask(task, claimed: $0) }
    }

    private func bountyTaskMatchesClaimedTask(_ task: EvoMapBountyTask, claimed: EvoMapClaimedBountyTask) -> Bool {
        if task.claimableTaskID == claimed.taskID || task.taskID == claimed.taskID || task.id == claimed.taskID {
            return true
        }
        if let bountyID = task.bountyID?.nonEmpty,
           bountyID == claimed.bountyID?.nonEmpty {
            return true
        }
        if let questionID = task.questionID?.nonEmpty,
           questionID == claimed.questionID?.nonEmpty {
            return true
        }
        return false
    }

    private func loadSelectedBountyAnswerDraft() {
        guard let task = selectedBountyTask else {
            bountyAnswerDraft = .empty
            return
        }

        let key = bountyDraftKey(for: task)
        if let stored = Self.loadBountyAnswerDrafts()[key] {
            bountyAnswerDraft = stored
            return
        }

        let claimed = claimedBountyTask(for: task)
        bountyAnswerDraft = BountyAnswerDraft(
            taskKey: key,
            taskID: claimed?.taskID ?? task.claimableTaskID,
            bountyID: task.bountyID,
            questionID: task.questionID,
            title: task.title,
            body: bountyBody(for: task),
            implementationNotes: "",
            answerText: "",
            verificationNotes: "",
            followupQuestion: "",
            generatedAt: nil,
            updatedAt: Date(),
            publishedAssetID: claimed?.mySubmissionAssetID,
            submissionID: claimed?.mySubmissionID,
            submissionStatus: claimed?.mySubmissionStatus,
            patchCourierRequestID: nil,
            patchCourierTaskID: nil,
            patchCourierStatus: nil,
            patchCourierThreadToken: nil,
            patchCourierSentAt: nil,
            patchCourierReceivedAt: nil,
            patchCourierMessageID: nil,
            patchCourierConfidence: nil,
            patchCourierRiskFlags: nil
        )
    }

    private func persistSelectedBountyAnswerDraft() {
        guard let task = selectedBountyTask else { return }
        var draft = bountyAnswerDraft
        draft.taskKey = bountyDraftKey(for: task)
        draft.taskID = selectedClaimedBountyTask?.taskID ?? task.claimableTaskID
        draft.bountyID = task.bountyID
        draft.questionID = task.questionID
        draft.title = task.title
        draft.body = bountyBody(for: task)
        draft.updatedAt = Date()
        bountyAnswerDraft = draft

        var drafts = Self.loadBountyAnswerDrafts()
        drafts[draft.taskKey] = draft
        Self.saveBountyAnswerDrafts(drafts)
    }

    private func bountyDraftKey(for task: EvoMapBountyTask) -> String {
        task.claimableTaskID ?? task.bountyID ?? task.questionID ?? task.id
    }

    private func defaultBountyImplementationNotes(for task: EvoMapBountyTask, claimedTask: EvoMapClaimedBountyTask?) -> String {
        let taskID = claimedTask?.taskID ?? task.claimableTaskID ?? AppLocalization.unknown
        return AppLocalization.string(
            "bounties.delivery.default.implementation",
            fallback: "1. Confirm the task request and acceptance criteria.\n2. Draft the answer in a concrete, reviewable structure.\n3. Check assumptions, edge cases, and implementation tradeoffs.\n4. Publish the answer as a Gene + Capsule bundle, then complete task_id=%@.",
            taskID
        )
    }

    private func defaultBountyAnswerText(for task: EvoMapBountyTask) -> String {
        let title = AppLocalization.bountyText(task.title)
        let body = bountyBody(for: task).map { AppLocalization.bountyText($0) }?.nonEmpty
        return [
            "# \(title)",
            "",
            "## 1. 需求理解",
            body ?? "请在这里补充你对任务需求的理解、边界和验收标准。",
            "",
            "## 2. 实现方案",
            "- 目标用户和核心场景：",
            "- MVP 功能拆分：",
            "- 技术结构或交付物结构：",
            "- 数据、接口、页面或流程设计：",
            "",
            "## 3. 验证方式",
            "- 如何验证这个方案满足题目：",
            "- 需要用户确认的假设：",
            "",
            "## 4. 最终建议",
            "给出可执行的下一步，并说明为什么这样做风险最低。"
        ].joined(separator: "\n")
    }

    private func defaultBountyVerificationNotes(for task: EvoMapBountyTask) -> String {
        [
            AppLocalization.string("bounties.delivery.verify.answer_matches", fallback: "Answer directly addresses the bounty title/body."),
            AppLocalization.string("bounties.delivery.verify.no_secret", fallback: "No secrets, private keys, or local-only paths are included."),
            AppLocalization.string("bounties.delivery.verify.reviewable", fallback: "The final answer is concrete enough for the task owner to accept or reject.")
        ].joined(separator: "\n")
    }

    private struct BountyPublishBundle {
        let payload: EvoMapPublishBundlePayload
        let geneAssetID: String
        let capsuleAssetID: String
    }

    private func makeBountyPublishBundle(
        task: EvoMapBountyTask,
        taskID: String,
        node: NodeRecord?,
        draft: BountyAnswerDraft
    ) throws -> BountyPublishBundle {
        let title = AppLocalization.bountyText(task.title)
        let finalAnswer = draft.answerText.nonEmpty
            ?? defaultBountyAnswerText(for: task)
        let signals = Self.bountySignals(from: "\(task.title) \(bountyBody(for: task) ?? "")")
        let modelName = node?.modelName.nonEmpty
        let envFingerprint = [
            "platform": "macOS",
            "app": "EvomapConsole",
            "task_id": taskID,
        ]

        var gene = EvoMapPublishAsset(
            type: "Gene",
            schemaVersion: "1.5.0",
            id: "gene_bounty_answer_\(Self.slug(from: taskID))",
            category: "innovate",
            signalsMatch: signals,
            summary: "Prepare and validate a structured answer for bounty task: \(title)",
            preconditions: [
                "The bounty task is claimed by the publishing node.",
                "The answer draft has been reviewed before submission.",
            ],
            strategy: [
                "Read the bounty title, body, reward, and deadline.",
                "Draft an answer that directly addresses the requested scenario.",
                "Check assumptions, validation steps, and acceptance risks.",
                "Publish the answer Capsule and complete the task with its asset_id.",
            ],
            constraints: EvoMapPublishAssetConstraints(maxFiles: 0, forbiddenPaths: [".env", "node_modules/"]),
            validation: ["node --version"],
            trigger: nil,
            gene: nil,
            confidence: nil,
            blastRadius: nil,
            outcome: nil,
            successStreak: nil,
            envFingerprint: nil,
            modelName: modelName,
            domain: "other",
            assetID: nil
        )
        gene.assetID = try Self.assetID(for: gene)

        var capsule = EvoMapPublishAsset(
            type: "Capsule",
            schemaVersion: "1.5.0",
            id: nil,
            category: nil,
            signalsMatch: nil,
            summary: finalAnswer,
            preconditions: nil,
            strategy: nil,
            constraints: nil,
            validation: nil,
            trigger: signals,
            gene: gene.assetID,
            confidence: 0.78,
            blastRadius: EvoMapPublishAssetBlastRadius(files: 0, lines: finalAnswer.split(separator: "\n", omittingEmptySubsequences: false).count),
            outcome: EvoMapPublishAssetOutcome(status: "success", score: 0.78),
            successStreak: 2,
            envFingerprint: envFingerprint,
            modelName: modelName,
            domain: "other",
            assetID: nil
        )
        capsule.assetID = try Self.assetID(for: capsule)

        return BountyPublishBundle(
            payload: EvoMapPublishBundlePayload(assets: [gene, capsule]),
            geneAssetID: gene.assetID ?? "",
            capsuleAssetID: capsule.assetID ?? ""
        )
    }

    private static func bountySignals(from text: String) -> [String] {
        let tokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count >= 3 }

        var result: [String] = ["bounty", "answer", "implementation"]
        for token in tokens where result.contains(token) == false {
            result.append(token)
            if result.count >= 8 { break }
        }
        return result
    }

    private static func slug(from value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let pieces = value.lowercased().unicodeScalars.map { scalar -> String in
            allowed.contains(scalar) ? String(scalar) : "_"
        }
        let slug = pieces.joined()
            .split(separator: "_")
            .joined(separator: "_")
        return String(slug.prefix(48)).nonEmpty ?? "task"
    }

    private static func assetID(for asset: EvoMapPublishAsset) throws -> String {
        var unsigned = asset
        unsigned.assetID = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(unsigned)
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    func prepareNodeConnection() {
        let selectedNode = selectedNode?.isSampleData == true ? nil : selectedNode
        nodeConnectionDraft = NodeConnectionDraft(
            editingNodeID: selectedNode?.id,
            nodeName: selectedNode?.name ?? ConsoleAppSettings.defaultNodeName,
            senderID: selectedNode?.senderID.nonEmpty ?? Self.makeSenderID(),
            baseURL: selectedNode?.apiBaseURL ?? ConsoleAppSettings.hubBaseURL,
            environment: selectedNode?.environment ?? .production,
            modelName: selectedNode?.modelName ?? ConsoleAppSettings.defaultNodeModel,
            geneCount: selectedNode?.geneCount ?? 0,
            capsuleCount: selectedNode?.capsuleCount ?? 0,
            referrer: selectedNode?.referralCode ?? "",
            identityDoc: ConsoleAppSettings.defaultIdentityDoc,
            constitution: ConsoleAppSettings.defaultConstitution
        )
        nodeConnectionErrorMessage = nil
        isPresentingNodeConnectionSheet = true
        isInspectorPresented = true
    }

    func submitNodeConnection() async {
        var draft = nodeConnectionDraft
        draft.senderID = draft.senderID.nonEmpty ?? Self.makeSenderID()
        draft.baseURL = draft.baseURL.nonEmpty ?? ConsoleAppSettings.hubBaseURL
        draft.nodeName = draft.nodeName.nonEmpty ?? ConsoleAppSettings.defaultNodeName
        draft.modelName = draft.modelName.nonEmpty ?? ConsoleAppSettings.defaultNodeModel
        nodeConnectionDraft = draft

        isConnectingNode = true
        nodeConnectionErrorMessage = nil
        defer { isConnectingNode = false }

        let request = EvoMapHelloRequest(
            baseURL: draft.baseURL,
            senderID: draft.senderID,
            payload: EvoMapHelloPayload(
                capabilities: [
                    "desktop_console": true,
                    "node_management": true,
                    "skill_store": true,
                ],
                model: draft.modelName,
                geneCount: draft.geneCount,
                capsuleCount: draft.capsuleCount,
                envFingerprint: Self.makeEnvironmentFingerprint(),
                referrer: draft.referrer.nonEmpty,
                identityDoc: draft.identityDoc.nonEmpty,
                constitution: draft.constitution.nonEmpty
            )
        )

        do {
            let response = try await client.hello(request: request)
            applyHelloResponse(response, draft: draft)
            isPresentingNodeConnectionSheet = false
        } catch {
            nodeConnectionErrorMessage = Self.nodeConnectionFailureMessage(error)
        }
    }

    func markSelectedNodeClaimed() {
        guard let node = selectedNode, node.isSampleData == false else { return }
        guard let index = nodes.firstIndex(where: { $0.id == node.id }) else { return }

        let markedAt = Date()
        var updated = nodes[index]
        updated.claimState = .claimed
        updated.heartbeat = makeHeartbeatState(for: updated.claimState, snapshot: updated.heartbeatSnapshot ?? .empty)
        updated.notes = AppLocalization.string(
            "node.claim.local_confirmed_note",
            fallback: "Claim was marked complete locally after browser confirmation. EvoMap account pages remain the source of truth."
        )
        updated.lastErrorMessage = nil
        prependEvents(
            [
                NodeEvent(
                    timestamp: markedAt,
                    title: "Claim marked complete",
                    detail: "Browser claim was confirmed by the user in this app."
                )
            ],
            to: &updated
        )
        nodes[index] = updated
        persistLiveNodes()
    }

    func forgetSelectedNodeAndSecret() {
        guard let node = selectedNode, node.isSampleData == false else { return }

        do {
            try nodeSecretStore.deleteNodeSecret(for: node.senderID)
        } catch {
            nodeConnectionErrorMessage = AppLocalization.string(
                "node.forget.error",
                fallback: "Could not remove the node_secret from Keychain: %@",
                error.localizedDescription
            )
            return
        }

        nodes.removeAll { candidate in
            candidate.isSampleData == false && candidate.senderID == node.senderID
        }
        selectedNodeID = Self.displayNodes(from: nodes).first?.id
        lastRefreshAt = Date()
        persistLiveNodes()
    }

    func refreshSelectedNodeHeartbeat() async {
        guard !isRefreshingNodeHeartbeat else { return }
        guard let node = selectedNode else {
            lastRefreshAt = Date()
            return
        }
        selectedNodeID = node.id

        if node.isSampleData {
            applyHeartbeatNotice(
                message: AppLocalization.string(
                    "node.heartbeat.notice.sample",
                    fallback: "This is a built-in demo node. It does not call the live EvoMap heartbeat. Use Connect Node to create a real node."
                ),
                for: node.id
            )
            lastRefreshAt = Date()
            return
        }

        let now = Date()
        if let cooldownUntil = nodeHeartbeatCooldownUntil[node.id], cooldownUntil > now {
            applyHeartbeatNotice(
                message: AppLocalization.string(
                    "node.heartbeat.notice.cooldown",
                    fallback: "EvoMap is rate-limiting heartbeat requests. Wait until %@ before refreshing again.",
                    cooldownUntil.formatted(date: .omitted, time: .shortened)
                ),
                for: node.id
            )
            lastRefreshAt = now
            return
        }

        if node.heartbeatSnapshot != nil {
            let nextManualRefreshAt = node.lastSeen.addingTimeInterval(Self.minimumManualHeartbeatInterval)
            if nextManualRefreshAt > now {
                applyHeartbeatNotice(
                    message: AppLocalization.string(
                        "node.heartbeat.notice.too_soon",
                        fallback: "Heartbeat was just synced. Wait until %@ before manually refreshing again.",
                        nextManualRefreshAt.formatted(date: .omitted, time: .shortened)
                    ),
                    for: node.id
                )
                lastRefreshAt = now
                return
            }
        }

        isRefreshingNodeHeartbeat = true
        refreshStoredSecretFlags()
        defer {
            isRefreshingNodeHeartbeat = false
            lastRefreshAt = Date()
        }

        guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
            applyHeartbeatFailure(
                message: "No node_secret found in the local Keychain. Run `/a2a/hello` again before heartbeat.",
                for: node.id,
                markOffline: true
            )
            return
        }

        let fingerprint = Self.makeEnvironmentFingerprint()
        let request = EvoMapHeartbeatRequest(
            baseURL: node.apiBaseURL,
            senderID: node.senderID,
            nodeSecret: nodeSecret,
            payload: EvoMapHeartbeatPayload(
                nodeID: node.senderID,
                senderID: node.senderID,
                geneCount: node.geneCount,
                capsuleCount: node.capsuleCount,
                envFingerprint: fingerprint,
                fingerprint: fingerprint,
                workerEnabled: false
            )
        )

        do {
            let response = try await client.heartbeat(request: request)
            nodeHeartbeatCooldownUntil[node.id] = nil
            applyHeartbeatResponse(response, for: node.id)
        } catch {
            let message = Self.heartbeatFailureMessage(error)
            if Self.isRateLimitError(error) {
                nodeHeartbeatCooldownUntil[node.id] = Date().addingTimeInterval(Self.rateLimitHeartbeatBackoff)
                applyHeartbeatFailure(message: message, for: node.id, markOffline: false)
            } else {
                applyHeartbeatFailure(message: message, for: node.id, markOffline: true)
            }
        }
    }

    func prepareSkillImport() {
        skillImportErrorMessage = nil
        isPresentingSkillImporter = true
        isInspectorPresented = true
    }

    func importSkill(from url: URL) {
        skillImportErrorMessage = nil
        do {
            var importedSkill = try skillImportService.importSkill(from: url)
            if let existingIndex = skills.firstIndex(where: {
                $0.skillID == importedSkill.skillID || $0.sourcePath == importedSkill.sourcePath
            }) {
                var existing = skills[existingIndex]
                existing.skillID = importedSkill.skillID
                existing.name = importedSkill.name
                existing.summary = importedSkill.summary
                existing.category = importedSkill.category
                existing.tags = importedSkill.tags
                existing.state = existing.remoteVersion == nil ? .draft : .changed
                existing.localCharacterCount = importedSkill.localCharacterCount
                existing.bundledFiles = importedSkill.bundledFiles
                existing.updatedAt = Date()
                existing.sourcePath = importedSkill.sourcePath
                existing.content = importedSkill.content
                existing.validationIssues = importedSkill.validationIssues
                existing.lastPublishErrorMessage = nil
                importedSkill = existing
                skills[existingIndex] = existing
            } else {
                skills.insert(importedSkill, at: 0)
            }

            selectedSkillID = importedSkill.id
            lastRefreshAt = Date()
            isInspectorPresented = true
        } catch {
            skillImportErrorMessage = error.localizedDescription
        }
    }

    func setSkillWorkspaceMode(_ mode: SkillWorkspaceMode) {
        guard skillWorkspaceMode != mode else { return }
        skillWorkspaceMode = mode
        remoteSkillLoadErrorMessage = nil
        remoteSkillDetailErrorMessage = nil
        recycledSkillLoadErrorMessage = nil
        remoteSkillDownloadMessage = nil
        remoteSkillDownloadErrorMessage = nil
        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = nil
        switch mode {
        case .local:
            selectedSkillID = selectedSkillID ?? skills.first?.id
        case .store:
            selectedRemoteSkillID = selectedRemoteSkillID ?? remoteSkills.first?.id
            Task {
                await loadRemoteSkillsIfNeeded()
            }
        case .recycleBin:
            selectedRecycledSkillID = selectedRecycledSkillID ?? recycledSkills.first?.id
            Task {
                await loadRecycleBinIfNeeded()
            }
        }
    }

    func setGraphWorkspaceMode(_ mode: GraphWorkspaceMode) {
        guard graphWorkspaceMode != mode else { return }
        graphWorkspaceMode = mode
        knowledgeGraphSnapshotErrorMessage = nil
        knowledgeGraphSearchErrorMessage = nil
        knowledgeGraphMutationMessage = nil
        knowledgeGraphMutationErrorMessage = nil

        switch mode {
        case .myGraph:
            selectedKnowledgeGraphNodeID = selectedKnowledgeGraphNodeID ?? knowledgeGraphSnapshot?.nodes.first?.id
            Task {
                await loadKnowledgeGraphMyGraphIfNeeded()
            }
        case .search:
            selectedKnowledgeGraphSearchNodeID = selectedKnowledgeGraphSearchNodeID ?? knowledgeGraphSearchResult?.nodes.first?.id
        case .manage:
            break
        }
    }

    func selectRemoteSkill(_ skillID: String?) {
        guard selectedRemoteSkillID != skillID else { return }
        selectedRemoteSkillID = skillID
        remoteSkillDetail = nil
        remoteSkillVersions = []
        remoteSkillRollbackTargetVersion = nil
        remoteSkillDetailErrorMessage = nil
        remoteSkillDownloadMessage = nil
        remoteSkillDownloadErrorMessage = nil
        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = nil

        guard skillID != nil else { return }
        Task {
            await loadSelectedRemoteSkillDetail()
        }
    }

    func selectRecycledSkill(_ skillID: String?) {
        guard selectedRecycledSkillID != skillID else { return }
        selectedRecycledSkillID = skillID
        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = nil
    }

    func selectService(_ listingID: String?) {
        guard selectedServiceID != listingID else { return }
        selectedServiceID = listingID
        serviceDetail = nil
        serviceRatings = []
        serviceDetailErrorMessage = nil
        serviceRatingsErrorMessage = nil
        serviceMutationMessage = nil
        serviceMutationErrorMessage = nil
        serviceRatingMessage = nil
        serviceRatingErrorMessage = nil

        guard listingID != nil else { return }
        Task {
            await loadSelectedServiceDetail()
        }
    }

    func selectOrder(_ taskID: String?) {
        guard selectedOrderTaskID != taskID else { return }
        selectedOrderTaskID = taskID
        orderDetail = nil
        orderDetailErrorMessage = nil
        orderMutationMessage = nil
        orderMutationErrorMessage = nil
        serviceRatingMessage = nil
        serviceRatingErrorMessage = nil

        guard taskID != nil else { return }
        Task {
            await loadSelectedOrderDetail()
        }
    }

    func selectKnowledgeGraphNode(_ nodeID: String?) {
        guard selectedKnowledgeGraphNodeID != nodeID else { return }
        selectedKnowledgeGraphNodeID = nodeID
    }

    func selectKnowledgeGraphSearchNode(_ nodeID: String?) {
        guard selectedKnowledgeGraphSearchNodeID != nodeID else { return }
        selectedKnowledgeGraphSearchNodeID = nodeID
    }

    func prepareServiceComposerForPublish() {
        serviceDraft = .empty
        serviceMutationMessage = nil
        serviceMutationErrorMessage = nil
        isPresentingServiceComposer = true
        isInspectorPresented = true
    }

    func prepareJapaneseLearningServiceComposer() {
        serviceDraft = ServiceDraft(
            mode: .publish,
            listingID: nil,
            title: "Japanese Learning Assistant",
            description: "Callable service for JLPT vocabulary explanation, grammar correction, example generation, and quiz drafting from a curated Japanese learning library.",
            capabilitiesText: """
            JLPT vocabulary explanation
            Japanese grammar correction
            Natural example sentence generation
            Reading difficulty grading
            Quiz generation
            """,
            useCasesText: """
            Explain N5-N1 vocabulary with nuance
            Correct learner sentences
            Generate graded practice questions
            Build study paths from weak points
            """,
            pricePerTask: 20,
            maxConcurrent: 2,
            recipeID: "",
            status: .active,
            authorNodeID: selectedNode?.senderID
        )
        serviceMutationMessage = nil
        serviceMutationErrorMessage = nil
        selectedSection = .services
        isPresentingServiceComposer = true
        isInspectorPresented = true
    }

    func prepareOrderComposerForSelectedService() {
        if let service = serviceDetail {
            orderDraft = OrderDraft(
                listingID: service.listingID,
                serviceTitle: service.title,
                serviceDescription: service.description,
                providerNodeID: service.providerNodeID,
                providerAlias: service.providerAlias,
                requesterNodeID: selectedNode?.senderID,
                question: "",
                estimatedCredits: service.pricePerTask,
                recipeID: service.recipeID
            )
        } else if let service = selectedServiceSummary {
            orderDraft = OrderDraft(
                listingID: service.listingID,
                serviceTitle: service.title,
                serviceDescription: service.description,
                providerNodeID: service.providerNodeID,
                providerAlias: service.providerAlias,
                requesterNodeID: selectedNode?.senderID,
                question: "",
                estimatedCredits: service.pricePerTask,
                recipeID: service.recipeID
            )
        } else {
            orderMutationMessage = nil
            orderMutationErrorMessage = "Select a service before placing an order."
            return
        }

        orderMutationMessage = nil
        orderMutationErrorMessage = nil
        isPresentingOrderComposer = true
        isInspectorPresented = true
    }

    func prepareServiceComposerForSelectedServiceUpdate() {
        guard let detail = serviceDetail else {
            guard let summary = selectedServiceSummary else {
                serviceMutationMessage = nil
                serviceMutationErrorMessage = "Select a service before editing it."
                return
            }

            serviceDraft = ServiceDraft(
                mode: .update,
                listingID: summary.listingID,
                title: summary.title,
                description: summary.description,
                capabilitiesText: summary.capabilities.joined(separator: ", "),
                useCasesText: summary.useCases.joined(separator: ", "),
                pricePerTask: summary.pricePerTask ?? 10,
                maxConcurrent: summary.maxConcurrent ?? 1,
                recipeID: summary.recipeID ?? "",
                status: ServiceLifecycleStatus(rawValue: summary.status?.lowercased() ?? "") ?? .active,
                authorNodeID: summary.providerNodeID
            )
            serviceMutationMessage = nil
            serviceMutationErrorMessage = nil
            isPresentingServiceComposer = true
            isInspectorPresented = true
            return
        }

        let service = detail

        serviceDraft = ServiceDraft(
            mode: .update,
            listingID: service.listingID,
            title: service.title,
            description: service.description,
            capabilitiesText: service.capabilities.joined(separator: ", "),
            useCasesText: service.useCases.joined(separator: ", "),
            pricePerTask: service.pricePerTask ?? 10,
            maxConcurrent: service.maxConcurrent ?? 1,
            recipeID: service.recipeID ?? "",
            status: ServiceLifecycleStatus(rawValue: service.status?.lowercased() ?? "") ?? .active,
            authorNodeID: service.providerNodeID
        )
        serviceMutationMessage = nil
        serviceMutationErrorMessage = nil
        isPresentingServiceComposer = true
        isInspectorPresented = true
    }

    func loadRemoteSkillsIfNeeded() async {
        if remoteSkills.isEmpty == false || isLoadingRemoteSkills {
            if selectedRemoteSkillSummary != nil, remoteSkillDetail == nil, selectedRemoteSkillID != nil {
                await loadSelectedRemoteSkillDetail()
            }
            return
        }
        await refreshRemoteSkills()
    }

    func loadServicesIfNeeded() async {
        if services.isEmpty == false || isLoadingServices {
            if selectedServiceSummary != nil, serviceDetail == nil, selectedServiceID != nil {
                await loadSelectedServiceDetail()
            }
            if selectedServiceSummary != nil, serviceRatings.isEmpty, selectedServiceID != nil {
                await loadSelectedServiceRatings()
            }
            return
        }
        await refreshServices()
    }

    func loadOrdersIfNeeded() async {
        if selectedTrackedOrder != nil, orderDetail == nil, selectedOrderTaskID != nil {
            await loadSelectedOrderDetail()
        }
    }

    func loadKnowledgeGraphCurrentWorkspaceIfNeeded() async {
        switch graphWorkspaceMode {
        case .myGraph:
            await loadKnowledgeGraphMyGraphIfNeeded()
        case .search:
            break
        case .manage:
            break
        }
    }

    func refreshKnowledgeGraphCurrentWorkspace() async {
        await refreshKnowledgeGraphStatus()
        switch graphWorkspaceMode {
        case .myGraph:
            await refreshKnowledgeGraphMyGraph()
        case .search:
            if knowledgeGraphQueryText.nonEmpty != nil {
                await runKnowledgeGraphQuery()
            }
        case .manage:
            break
        }
    }

    func loadKnowledgeGraphStatusIfNeeded() async {
        if knowledgeGraphStatus != nil || isLoadingKnowledgeGraphStatus {
            return
        }
        await refreshKnowledgeGraphStatus()
    }

    func refreshKnowledgeGraphStatus() async {
        guard !isLoadingKnowledgeGraphStatus else { return }
        isLoadingKnowledgeGraphStatus = true
        knowledgeGraphStatusErrorMessage = nil
        defer {
            isLoadingKnowledgeGraphStatus = false
            lastRefreshAt = Date()
        }

        guard let apiKey = ConsoleAppSettings.kgAPIKey.nonEmpty else {
            knowledgeGraphStatus = nil
            knowledgeGraphStatusErrorMessage = knowledgeGraphAccessBlocker
            return
        }

        do {
            knowledgeGraphStatus = try await client.knowledgeGraphStatus(
                request: EvoMapKnowledgeGraphStatusRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    apiKey: apiKey
                )
            )
        } catch {
            knowledgeGraphStatus = nil
            knowledgeGraphStatusErrorMessage = error.localizedDescription
        }
    }

    func loadKnowledgeGraphMyGraphIfNeeded() async {
        if knowledgeGraphSnapshot != nil || isLoadingKnowledgeGraphSnapshot {
            if selectedKnowledgeGraphNodeID == nil {
                selectedKnowledgeGraphNodeID = knowledgeGraphSnapshot?.nodes.first?.id
            }
            return
        }
        await refreshKnowledgeGraphMyGraph()
    }

    func refreshKnowledgeGraphMyGraph() async {
        guard !isLoadingKnowledgeGraphSnapshot else { return }
        isLoadingKnowledgeGraphSnapshot = true
        knowledgeGraphSnapshotErrorMessage = nil
        defer {
            isLoadingKnowledgeGraphSnapshot = false
            lastRefreshAt = Date()
        }

        guard let apiKey = ConsoleAppSettings.kgAPIKey.nonEmpty else {
            knowledgeGraphSnapshot = nil
            selectedKnowledgeGraphNodeID = nil
            knowledgeGraphSnapshotErrorMessage = knowledgeGraphAccessBlocker
            return
        }

        do {
            let snapshot = try await client.knowledgeGraphMyGraph(
                request: EvoMapKnowledgeGraphMyGraphRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    apiKey: apiKey
                )
            )
            knowledgeGraphSnapshot = snapshot
            selectedKnowledgeGraphNodeID = snapshot.nodes.first(where: { $0.id == selectedKnowledgeGraphNodeID })?.id
                ?? snapshot.nodes.first?.id
        } catch {
            knowledgeGraphSnapshot = nil
            selectedKnowledgeGraphNodeID = nil
            knowledgeGraphSnapshotErrorMessage = error.localizedDescription
        }
    }

    func runKnowledgeGraphQuery() async {
        guard !isSearchingKnowledgeGraph else { return }
        knowledgeGraphMutationMessage = nil
        knowledgeGraphMutationErrorMessage = nil

        guard let apiKey = ConsoleAppSettings.kgAPIKey.nonEmpty else {
            knowledgeGraphSearchErrorMessage = knowledgeGraphAccessBlocker
            knowledgeGraphSearchResult = nil
            selectedKnowledgeGraphSearchNodeID = nil
            return
        }
        guard let query = knowledgeGraphQueryText.nonEmpty else {
            knowledgeGraphSearchErrorMessage = "Enter a graph query before calling `/kg/query`."
            knowledgeGraphSearchResult = nil
            selectedKnowledgeGraphSearchNodeID = nil
            return
        }

        isSearchingKnowledgeGraph = true
        knowledgeGraphSearchErrorMessage = nil
        defer {
            isSearchingKnowledgeGraph = false
            lastRefreshAt = Date()
        }

        do {
            let result = try await client.queryKnowledgeGraph(
                request: EvoMapKnowledgeGraphQueryRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    apiKey: apiKey,
                    payload: EvoMapKnowledgeGraphQueryPayload(query: query, type: "semantic")
                )
            )
            knowledgeGraphSearchResult = result
            selectedKnowledgeGraphSearchNodeID = result.nodes.first(where: { $0.id == selectedKnowledgeGraphSearchNodeID })?.id
                ?? result.nodes.first?.id
        } catch {
            knowledgeGraphSearchResult = nil
            selectedKnowledgeGraphSearchNodeID = nil
            knowledgeGraphSearchErrorMessage = error.localizedDescription
        }
    }

    func submitKnowledgeGraphIngest() async {
        guard !isSubmittingKnowledgeGraphIngest else { return }
        knowledgeGraphMutationMessage = nil
        knowledgeGraphMutationErrorMessage = nil

        guard let blocker = knowledgeGraphIngestPrerequisiteBlocker else {
            guard let apiKey = ConsoleAppSettings.kgAPIKey.nonEmpty else {
                knowledgeGraphMutationErrorMessage = knowledgeGraphAccessBlocker
                return
            }

            isSubmittingKnowledgeGraphIngest = true
            defer {
                isSubmittingKnowledgeGraphIngest = false
                lastRefreshAt = Date()
            }

            let entity = knowledgeGraphEntityDraft.name.nonEmpty.map {
                EvoMapKnowledgeGraphIngestPayload.Entity(
                    name: $0,
                    type: knowledgeGraphEntityDraft.type.rawValue,
                    description: knowledgeGraphEntityDraft.description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            let relationship = knowledgeGraphRelationshipDraft.sourceName.nonEmpty.flatMap { sourceName in
                knowledgeGraphRelationshipDraft.targetName.nonEmpty.map { targetName in
                    EvoMapKnowledgeGraphIngestPayload.Relationship(
                        sourceName: sourceName,
                        relation: knowledgeGraphRelationshipDraft.relationType.rawValue,
                        targetName: targetName
                    )
                }
            }

            do {
                let response = try await client.ingestKnowledgeGraph(
                    request: EvoMapKnowledgeGraphIngestRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        apiKey: apiKey,
                        payload: EvoMapKnowledgeGraphIngestPayload(
                            entities: entity.map { [$0] } ?? [],
                            relationships: relationship.map { [$0] } ?? []
                        )
                    )
                )

                var parts: [String] = []
                if let count = response.entitiesWritten {
                    parts.append("entities \(count)")
                }
                if let count = response.relationshipsWritten {
                    parts.append("relationships \(count)")
                }
                knowledgeGraphMutationMessage = response.message
                    ?? (parts.isEmpty ? "Knowledge Graph write completed." : "Wrote " + parts.joined(separator: ", ") + ".")
                knowledgeGraphEntityDraft = .empty
                knowledgeGraphRelationshipDraft = .empty
                await refreshKnowledgeGraphStatus()
                await refreshKnowledgeGraphMyGraph()
            } catch {
                knowledgeGraphMutationErrorMessage = error.localizedDescription
            }
            return
        }

        knowledgeGraphMutationErrorMessage = blocker
    }

    func refreshRemoteSkills() async {
        guard !isLoadingRemoteSkills else { return }
        isLoadingRemoteSkills = true
        remoteSkillLoadErrorMessage = nil
        remoteSkillDownloadErrorMessage = nil
        remoteSkillMutationErrorMessage = nil
        defer {
            isLoadingRemoteSkills = false
            lastRefreshAt = Date()
        }

        do {
            let status = try await client.skillStoreStatus(baseURL: ConsoleAppSettings.hubBaseURL)
            remoteSkillStoreEnabled = status.enabled
            guard status.enabled else {
                remoteSkills = []
                remoteSkillTotalCount = 0
                remoteSkillTotalDownloads = 0
                remoteSkillDetail = nil
                remoteSkillVersions = []
                selectedRemoteSkillID = nil
                return
            }

            let response = try await client.listSkills(
                request: EvoMapSkillStoreListRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    keyword: searchText.nonEmpty,
                    page: 1,
                    limit: 30,
                    sort: "downloads",
                    featured: nil
                )
            )

            remoteSkills = response.skills
            remoteSkillTotalCount = response.total
            remoteSkillTotalDownloads = response.totalDownloads ?? 0

            let selection = response.skills.first(where: { $0.id == selectedRemoteSkillID })?.id ?? response.skills.first?.id
            selectedRemoteSkillID = selection
            remoteSkillDetail = nil
            remoteSkillVersions = []
            remoteSkillRollbackTargetVersion = nil

            if selection != nil {
                await loadSelectedRemoteSkillDetail()
            }
        } catch {
            remoteSkillLoadErrorMessage = error.localizedDescription
        }
    }

    func loadRecycleBinIfNeeded() async {
        if recycledSkills.isEmpty == false || isLoadingRecycledSkills {
            return
        }
        await refreshRecycleBin()
    }

    func refreshRecycleBin() async {
        guard !isLoadingRecycledSkills else { return }
        isLoadingRecycledSkills = true
        recycledSkillLoadErrorMessage = nil
        defer {
            isLoadingRecycledSkills = false
            lastRefreshAt = Date()
        }

        guard let blocker = recycleBinAccessBlocker else {
            guard let node = selectedNode,
                  let nodeSecret = loadStoredSecret(for: node.senderID) else {
                recycledSkillLoadErrorMessage = "Select an authenticated node before opening the recycle bin."
                return
            }

            do {
                let response = try await client.recycleBin(
                    request: EvoMapSkillStoreRecycleBinRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreRecycleBinPayload(
                            senderID: node.senderID,
                            page: 1,
                            limit: 50
                        )
                    )
                )

                recycledSkills = response.skills
                recycledSkillTotalCount = response.total ?? response.skills.count
                selectedRecycledSkillID = response.skills.first(where: { $0.id == selectedRecycledSkillID })?.id ?? response.skills.first?.id
            } catch {
                recycledSkillLoadErrorMessage = error.localizedDescription
            }
            return
        }

        recycledSkills = []
        recycledSkillTotalCount = 0
        selectedRecycledSkillID = nil
        recycledSkillLoadErrorMessage = blocker
    }

    func refreshServices() async {
        guard !isLoadingServices else { return }
        isLoadingServices = true
        serviceLoadErrorMessage = nil
        serviceMutationErrorMessage = nil
        defer {
            isLoadingServices = false
            lastRefreshAt = Date()
        }

        do {
            let response: EvoMapServiceListResponse
            if let query = searchText.nonEmpty {
                response = try await client.searchServices(
                    request: EvoMapServiceSearchRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        query: query
                    )
                )
            } else {
                response = try await client.listServices(
                    request: EvoMapServiceListRequest(baseURL: ConsoleAppSettings.hubBaseURL)
                )
            }

            services = response.services
            let selection = response.services.first(where: { $0.id == selectedServiceID })?.id ?? response.services.first?.id
            selectedServiceID = selection
            serviceDetail = nil
            serviceRatings = []

            if selection != nil {
                await loadSelectedServiceDetail()
                await loadSelectedServiceRatings()
            }
        } catch {
            serviceLoadErrorMessage = error.localizedDescription
        }
    }

    func loadSelectedServiceDetail() async {
        guard !isLoadingServiceDetail else { return }
        guard let service = selectedServiceSummary else {
            serviceDetail = nil
            serviceDetailErrorMessage = nil
            return
        }

        isLoadingServiceDetail = true
        serviceDetailErrorMessage = nil
        defer { isLoadingServiceDetail = false }

        do {
            let detail = try await client.serviceDetail(
                request: EvoMapServiceDetailRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    listingID: service.listingID
                )
            )
            guard selectedServiceID == service.listingID else { return }
            serviceDetail = detail
        } catch {
            guard selectedServiceID == service.listingID else { return }
            serviceDetailErrorMessage = error.localizedDescription
            serviceDetail = nil
        }
    }

    func loadSelectedServiceRatings() async {
        guard !isLoadingServiceRatings else { return }
        guard let service = selectedServiceSummary else {
            serviceRatings = []
            serviceRatingsErrorMessage = nil
            return
        }

        isLoadingServiceRatings = true
        serviceRatingsErrorMessage = nil
        defer { isLoadingServiceRatings = false }

        do {
            let response = try await client.serviceRatings(
                request: EvoMapServiceRatingsRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    listingID: service.listingID,
                    page: 1,
                    limit: 12
                )
            )
            guard selectedServiceID == service.listingID else { return }
            serviceRatings = response.ratings
        } catch {
            guard selectedServiceID == service.listingID else { return }
            serviceRatingsErrorMessage = error.localizedDescription
            serviceRatings = []
        }
    }

    func refreshTrackedOrders() async {
        guard !isRefreshingOrders else { return }
        isRefreshingOrders = true
        orderLoadErrorMessage = nil
        orderDetailErrorMessage = nil
        defer {
            isRefreshingOrders = false
            lastRefreshAt = Date()
        }

        guard trackedOrders.isEmpty == false else {
            orderDetail = nil
            selectedOrderTaskID = nil
            return
        }

        var refreshedOrders = trackedOrders
        var firstFailure: String?

        for index in refreshedOrders.indices {
            let order = refreshedOrders[index]
            do {
                let detail = try await fetchOrderDetail(for: order)
                refreshedOrders[index] = mergedTrackedOrder(existing: order, with: detail, syncedAt: Date())
                if selectedOrderTaskID == order.taskID {
                    orderDetail = detail
                }
            } catch {
                if firstFailure == nil {
                    firstFailure = "Some tracked orders could not be refreshed. \(error.localizedDescription)"
                }
                if selectedOrderTaskID == order.taskID {
                    orderDetailErrorMessage = error.localizedDescription
                }
            }
        }

        trackedOrders = refreshedOrders.sorted(by: Self.sortOrders(lhs:rhs:))
        persistTrackedOrders()
        selectedOrderTaskID = trackedOrders.first(where: { $0.taskID == selectedOrderTaskID })?.taskID ?? trackedOrders.first?.taskID
        orderLoadErrorMessage = firstFailure
    }

    func loadSelectedOrderDetail() async {
        guard !isLoadingOrderDetail else { return }
        guard let order = selectedTrackedOrder else {
            orderDetail = nil
            orderDetailErrorMessage = nil
            return
        }

        isLoadingOrderDetail = true
        orderDetailErrorMessage = nil
        defer { isLoadingOrderDetail = false }

        do {
            let detail = try await fetchOrderDetail(for: order)
            guard selectedOrderTaskID == order.taskID else { return }
            orderDetail = detail
            updateTrackedOrder(for: order.taskID) { existing in
                mergedTrackedOrder(existing: existing ?? order, with: detail, syncedAt: Date())
            }
        } catch {
            guard selectedOrderTaskID == order.taskID else { return }
            orderDetailErrorMessage = error.localizedDescription
        }
    }

    func loadSelectedRemoteSkillDetail() async {
        guard !isLoadingRemoteSkillDetail else { return }
        guard let skill = selectedRemoteSkillSummary else {
            remoteSkillDetail = nil
            remoteSkillVersions = []
            remoteSkillRollbackTargetVersion = nil
            return
        }

        isLoadingRemoteSkillDetail = true
        remoteSkillDetailErrorMessage = nil
        defer { isLoadingRemoteSkillDetail = false }

        do {
            async let detail = client.skillDetail(
                request: EvoMapSkillStoreDetailRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    skillID: skill.skillId
                )
            )
            async let versions = client.skillVersions(
                request: EvoMapSkillStoreVersionsRequest(
                    baseURL: ConsoleAppSettings.hubBaseURL,
                    skillID: skill.skillId
                )
            )

            let (detailResponse, versionsResponse) = try await (detail, versions)
            guard selectedRemoteSkillID == skill.skillId else { return }
            remoteSkillDetail = detailResponse
            remoteSkillVersions = versionsResponse.versions
            resetRemoteSkillRollbackTargetVersion(using: detailResponse.version)
        } catch {
            guard selectedRemoteSkillID == skill.skillId else { return }
            remoteSkillDetailErrorMessage = error.localizedDescription
            remoteSkillVersions = []
            remoteSkillRollbackTargetVersion = nil
        }
    }

    func downloadSelectedRemoteSkill() async {
        guard activeRemoteSkillDownloadID == nil else { return }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedRemoteSkillDownloadPrerequisiteBlocker else {
            remoteSkillDownloadErrorMessage = nil
            remoteSkillDownloadMessage = nil
            let downloadedAt = Date()
            activeRemoteSkillDownloadID = skill.skillId
            defer {
                activeRemoteSkillDownloadID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillDownloadErrorMessage = "Store the node_secret for \(node.senderID) before downloading from the Skill Store."
                return
            }

            do {
                let response = try await client.downloadSkill(
                    request: EvoMapSkillStoreDownloadRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        skillID: skill.skillId,
                        senderID: node.senderID,
                        nodeSecret: nodeSecret
                    )
                )

                let materialization = try skillWorkspaceStore.materializeDownloadedSkill(response)
                if let conflictingSkill = conflictingLocalSkill(
                    for: response.skillID,
                    downloadedSkillPath: materialization.skillFileURL.path
                ) {
                    remoteSkillDownloadMessage = "Downloaded \(response.skillID) to \(materialization.rootDirectoryURL.path), but skipped auto-import because `\(conflictingSkill.name)` already uses the same `skill_id` from another local source."
                    return
                }

                importSkill(from: materialization.skillFileURL)
                applyDownloadedSkillMetadata(
                    skillID: response.skillID,
                    sourcePath: materialization.skillFileURL.path,
                    downloadedAt: downloadedAt,
                    authorNodeID: remoteSkillDetail?.author?.nodeId ?? skill.author?.nodeId,
                    storeVersion: response.version,
                    storeDirectoryPath: materialization.rootDirectoryURL.path,
                    creditCost: response.alreadyPurchased ? 0 : response.creditCost
                )

                if let nodeIndex = nodes.firstIndex(where: { $0.id == node.id }) {
                    var updatedNode = nodes[nodeIndex]
                    let costLabel = response.alreadyPurchased ? "free" : "\(response.creditCost ?? 0) credits"
                    prependEvents(
                        [
                            NodeEvent(
                                timestamp: downloadedAt,
                                title: "Downloaded Skill",
                                detail: "\(response.name ?? skill.name) (\(response.skillID)) -> \(response.version ?? "latest") · \(costLabel)"
                            )
                        ],
                        to: &updatedNode
                    )
                    nodes[nodeIndex] = updatedNode
                    persistLiveNodes()
                }

                skillWorkspaceMode = .local
                remoteSkillDownloadMessage = "Downloaded \(response.name ?? skill.name) into the managed local library."
                if materialization.skippedBundledFileNames.isEmpty == false {
                    remoteSkillDownloadMessage = (remoteSkillDownloadMessage ?? "")
                        + " Skipped \(materialization.skippedBundledFileNames.count) bundled file path(s) for safety."
                }
            } catch {
                remoteSkillDownloadErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillDownloadMessage = nil
        remoteSkillDownloadErrorMessage = blocker
    }

    func toggleSelectedRemoteSkillVisibility() async {
        guard activeRemoteSkillVisibilityID == nil else { return }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedRemoteSkillVisibilityPrerequisiteBlocker else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            activeRemoteSkillVisibilityID = skill.skillId
            defer {
                activeRemoteSkillVisibilityID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before managing Skill Store visibility."
                return
            }

            let targetVisibility = selectedRemoteSkillTargetVisibility

            do {
                let response = try await client.setSkillVisibility(
                    request: EvoMapSkillStoreVisibilityRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreVisibilityPayload(
                            senderID: node.senderID,
                            skillID: skill.skillId,
                            visibility: targetVisibility
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: nil,
                    message: response.message?.nonEmpty,
                    status: response.visibility?.nonEmpty ?? response.status?.nonEmpty
                )

                await refreshRemoteSkills()

                let resolvedMessage = response.message?.nonEmpty
                    ?? "\(skill.name) is now \(targetVisibility)."
                if targetVisibility == "private" && selectedRemoteSkillID != skill.skillId {
                    remoteSkillMutationMessage = "\(resolvedMessage) The skill is no longer visible in the public feed."
                } else {
                    remoteSkillMutationMessage = resolvedMessage
                }

                prependRemoteMutationEvent(
                    title: "Updated Skill Visibility",
                    detail: "\(skill.name) (\(skill.skillId)) -> \(targetVisibility)",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func submitServiceDraft() async {
        guard !isSubmittingServiceDraft else { return }
        guard let blocker = serviceDraftSubmitPrerequisiteBlocker else {
            serviceMutationMessage = nil
            serviceMutationErrorMessage = nil
            isSubmittingServiceDraft = true
            defer {
                isSubmittingServiceDraft = false
                lastRefreshAt = Date()
            }

            guard let node = selectedNode,
                  let nodeSecret = loadStoredSecret(for: node.senderID) else {
                serviceMutationErrorMessage = "Store the node_secret for the selected node before managing services."
                return
            }

            let capabilities = serviceDraftParsedCapabilities
            let useCases = serviceDraftParsedUseCases

            do {
                let response: EvoMapServiceMutationResponse
                if serviceDraft.mode == .publish {
                    response = try await client.publishService(
                        request: EvoMapServicePublishRequest(
                            baseURL: ConsoleAppSettings.hubBaseURL,
                            nodeSecret: nodeSecret,
                            payload: EvoMapServicePublishPayload(
                                senderID: node.senderID,
                                title: serviceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: serviceDraft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                                capabilities: capabilities,
                                pricePerTask: serviceDraft.pricePerTask,
                                maxConcurrent: serviceDraft.maxConcurrent,
                                useCases: useCases,
                                recipeID: serviceDraft.recipeID.nonEmpty,
                                status: serviceDraft.status.rawValue
                            )
                        )
                    )
                } else {
                    guard let listingID = serviceDraft.listingID?.nonEmpty else {
                        serviceMutationErrorMessage = "Load a service listing before updating it."
                        return
                    }
                    response = try await client.updateService(
                        request: EvoMapServiceUpdateRequest(
                            baseURL: ConsoleAppSettings.hubBaseURL,
                            nodeSecret: nodeSecret,
                            payload: EvoMapServiceUpdatePayload(
                                senderID: node.senderID,
                                listingID: listingID,
                                title: serviceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: serviceDraft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                                capabilities: capabilities,
                                pricePerTask: serviceDraft.pricePerTask,
                                maxConcurrent: serviceDraft.maxConcurrent,
                                useCases: useCases,
                                recipeID: serviceDraft.recipeID.nonEmpty,
                                status: serviceDraft.status.rawValue
                            )
                        )
                    )
                }

                let resolvedListingID = response.listingID?.nonEmpty ?? serviceDraft.listingID?.nonEmpty
                serviceMutationMessage = response.message?.nonEmpty
                    ?? (serviceDraft.mode == .publish
                        ? "Published \(serviceDraft.title) to the EvoMap marketplace."
                        : "Updated \(serviceDraft.title) on the EvoMap marketplace.")

                await refreshServices()
                if let resolvedListingID {
                    selectedServiceID = resolvedListingID
                    await loadSelectedServiceDetail()
                }

                prependRemoteMutationEvent(
                    title: serviceDraft.mode == .publish ? "Published Service" : "Updated Service",
                    detail: "\(serviceDraft.title) (\(resolvedListingID ?? "pending-id"))",
                    nodeID: node.id
                )

                if serviceDraft.mode == .publish {
                    serviceDraft = .empty
                }
                isPresentingServiceComposer = false
            } catch {
                serviceMutationErrorMessage = error.localizedDescription
            }
            return
        }

        serviceMutationMessage = nil
        serviceMutationErrorMessage = blocker
    }

    func submitOrderDraft() async {
        guard !isSubmittingOrder else { return }
        guard let blocker = orderDraftSubmitPrerequisiteBlocker else {
            orderMutationMessage = nil
            orderMutationErrorMessage = nil
            isSubmittingOrder = true
            defer {
                isSubmittingOrder = false
                lastRefreshAt = Date()
            }

            guard let node = selectedNode,
                  let nodeSecret = loadStoredSecret(for: node.senderID) else {
                orderMutationErrorMessage = "Store the node_secret for the selected node before placing orders."
                return
            }

            do {
                let response = try await client.placeServiceOrder(
                    request: EvoMapServiceOrderRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapServiceOrderPayload(
                            senderID: node.senderID,
                            listingID: orderDraft.listingID,
                            question: orderDraft.question.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                )

                let placedAt = Date()
                let newOrder = TrackedServiceOrder(
                    taskID: response.taskID,
                    listingID: response.listingID?.nonEmpty ?? orderDraft.listingID.nonEmpty,
                    serviceTitle: response.serviceTitle?.nonEmpty ?? orderDraft.serviceTitle.nonEmpty ?? orderDraft.listingID,
                    question: orderDraft.question.trimmingCharacters(in: .whitespacesAndNewlines),
                    requesterNodeID: node.senderID,
                    providerNodeID: response.providerNodeID?.nonEmpty ?? orderDraft.providerNodeID?.nonEmpty,
                    providerAlias: response.providerAlias?.nonEmpty ?? orderDraft.providerAlias?.nonEmpty,
                    status: response.status?.nonEmpty ?? "open",
                    creditsSpent: response.creditsDeducted ?? orderDraft.estimatedCredits,
                    organismID: response.organismID?.nonEmpty,
                    createdAt: placedAt,
                    updatedAt: placedAt,
                    lastSyncedAt: placedAt,
                    latestSubmissionID: nil,
                    latestSubmissionAt: nil,
                    finalAssetID: nil,
                    finalAssetURL: nil,
                    lastRatedAt: nil,
                    lastRating: nil
                )

                upsertTrackedOrder(newOrder)
                orderMutationMessage = response.message?.nonEmpty
                    ?? "Placed order \(response.taskID) for \(newOrder.serviceTitle)."
                orderDraft = .empty
                isPresentingOrderComposer = false
                selectedSection = .orders
                selectedOrderTaskID = response.taskID

                prependRemoteMutationEvent(
                    title: "Placed Service Order",
                    detail: "\(newOrder.serviceTitle) (\(response.taskID))",
                    nodeID: node.id
                )

                await loadSelectedOrderDetail()
            } catch {
                orderMutationErrorMessage = error.localizedDescription
            }
            return
        }

        orderMutationMessage = nil
        orderMutationErrorMessage = blocker
    }

    func prepareServiceRatingForSelectedOrder() {
        guard let order = selectedTrackedOrder else {
            serviceRatingMessage = nil
            serviceRatingErrorMessage = "Select a completed tracked order before rating the provider."
            return
        }

        serviceRatingDraft = ServiceRatingDraft(
            listingID: order.listingID ?? "",
            serviceTitle: order.serviceTitle,
            taskID: order.taskID,
            requesterNodeID: order.requesterNodeID,
            rating: order.lastRating ?? 5,
            comment: ""
        )
        serviceRatingMessage = nil
        serviceRatingErrorMessage = nil
        isPresentingServiceRatingComposer = true
        isInspectorPresented = true
    }

    func submitServiceRating() async {
        guard !isSubmittingServiceRating else { return }
        guard let blocker = serviceRatingSubmitPrerequisiteBlocker else {
            serviceRatingMessage = nil
            serviceRatingErrorMessage = nil
            isSubmittingServiceRating = true
            defer {
                isSubmittingServiceRating = false
                lastRefreshAt = Date()
            }

            guard let node = selectedNode,
                  let nodeSecret = loadStoredSecret(for: node.senderID) else {
                serviceRatingErrorMessage = "Store the node_secret for the selected node before submitting ratings."
                return
            }

            do {
                let response = try await client.rateService(
                    request: EvoMapServiceRateRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapServiceRatePayload(
                            senderID: node.senderID,
                            listingID: serviceRatingDraft.listingID,
                            rating: serviceRatingDraft.rating,
                            taskID: serviceRatingDraft.taskID?.nonEmpty,
                            comment: serviceRatingDraft.comment.nonEmpty
                        )
                    )
                )

                let ratedAt = Date()
                serviceRatingMessage = response.message?.nonEmpty
                    ?? "Rated \(serviceRatingDraft.serviceTitle) with \(serviceRatingDraft.rating) stars."

                if let taskID = serviceRatingDraft.taskID?.nonEmpty {
                    updateTrackedOrder(for: taskID) { existing in
                        var order = existing ?? TrackedServiceOrder(
                            taskID: taskID,
                            listingID: serviceRatingDraft.listingID.nonEmpty,
                            serviceTitle: serviceRatingDraft.serviceTitle,
                            question: "",
                            requesterNodeID: node.senderID,
                            providerNodeID: nil,
                            providerAlias: nil,
                            status: "completed",
                            creditsSpent: nil,
                            organismID: nil,
                            createdAt: ratedAt,
                            updatedAt: ratedAt,
                            lastSyncedAt: nil,
                            latestSubmissionID: nil,
                            latestSubmissionAt: nil,
                            finalAssetID: nil,
                            finalAssetURL: nil,
                            lastRatedAt: nil,
                            lastRating: nil
                        )
                        order.lastRatedAt = ratedAt
                        order.lastRating = serviceRatingDraft.rating
                        order.updatedAt = max(order.updatedAt, ratedAt)
                        return order
                    }
                }

                if let nodeIndex = nodes.firstIndex(where: { $0.id == node.id }) {
                    prependRemoteMutationEvent(
                        title: "Rated Service",
                        detail: "\(serviceRatingDraft.serviceTitle) · \(serviceRatingDraft.rating) star(s)",
                        nodeID: nodes[nodeIndex].id
                    )
                }

                if selectedServiceID == serviceRatingDraft.listingID {
                    await loadSelectedServiceRatings()
                    await loadSelectedServiceDetail()
                }

                isPresentingServiceRatingComposer = false
            } catch {
                serviceRatingErrorMessage = error.localizedDescription
            }
            return
        }

        serviceRatingMessage = nil
        serviceRatingErrorMessage = blocker
    }

    func acceptSelectedOrderSubmission(_ submission: RemoteOrderSubmission) async {
        guard activeOrderAcceptanceKey == nil else { return }
        guard let order = selectedTrackedOrder else { return }
        guard let blocker = orderAcceptancePrerequisiteBlocker(for: submission) else {
            orderMutationMessage = nil
            orderMutationErrorMessage = nil
            let acceptanceKey = orderAcceptanceKey(taskID: order.taskID, submissionID: submission.submissionID)
            activeOrderAcceptanceKey = acceptanceKey
            defer {
                activeOrderAcceptanceKey = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: order.requesterNodeID) else {
                orderMutationErrorMessage = "Store the node_secret for \(order.requesterNodeID) before accepting submissions."
                return
            }

            do {
                let response = try await client.acceptOrderSubmission(
                    request: EvoMapTaskAcceptSubmissionRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapTaskAcceptSubmissionPayload(
                            senderID: order.requesterNodeID,
                            taskID: order.taskID,
                            submissionID: submission.submissionID
                        )
                    )
                )

                orderMutationMessage = response.message?.nonEmpty
                    ?? "Accepted submission \(submission.submissionID) for \(order.taskID)."

                if let node = nodes.first(where: { $0.senderID == order.requesterNodeID }) {
                    prependRemoteMutationEvent(
                        title: "Accepted Order Submission",
                        detail: "\(order.serviceTitle) (\(order.taskID)) · \(submission.submissionID)",
                        nodeID: node.id
                    )
                }

                await loadSelectedOrderDetail()
            } catch {
                orderMutationErrorMessage = error.localizedDescription
            }
            return
        }

        orderMutationMessage = nil
        orderMutationErrorMessage = blocker
    }

    func toggleSelectedServiceStatus() async {
        guard activeServiceStatusListingID == nil else { return }
        guard let service = selectedServiceSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedServiceStatusPrerequisiteBlocker else {
            serviceMutationMessage = nil
            serviceMutationErrorMessage = nil
            activeServiceStatusListingID = service.listingID
            defer {
                activeServiceStatusListingID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                serviceMutationErrorMessage = "Store the node_secret for \(node.senderID) before managing services."
                return
            }

            do {
                let response = try await client.updateService(
                    request: EvoMapServiceUpdateRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapServiceUpdatePayload(
                            senderID: node.senderID,
                            listingID: service.listingID,
                            title: nil,
                            description: nil,
                            capabilities: nil,
                            pricePerTask: nil,
                            maxConcurrent: nil,
                            useCases: nil,
                            recipeID: nil,
                            status: selectedServiceTargetStatus.rawValue
                        )
                    )
                )

                serviceMutationMessage = response.message?.nonEmpty
                    ?? "\(service.title) is now \(selectedServiceTargetStatus.rawValue)."

                await refreshServices()
                await loadSelectedServiceDetail()

                prependRemoteMutationEvent(
                    title: "Updated Service Status",
                    detail: "\(service.title) (\(service.listingID)) -> \(selectedServiceTargetStatus.rawValue)",
                    nodeID: node.id
                )
            } catch {
                serviceMutationErrorMessage = error.localizedDescription
            }
            return
        }

        serviceMutationMessage = nil
        serviceMutationErrorMessage = blocker
    }

    func archiveSelectedService() async {
        guard activeServiceArchiveListingID == nil else { return }
        guard let service = selectedServiceSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedServiceArchivePrerequisiteBlocker else {
            serviceMutationMessage = nil
            serviceMutationErrorMessage = nil
            activeServiceArchiveListingID = service.listingID
            defer {
                activeServiceArchiveListingID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                serviceMutationErrorMessage = "Store the node_secret for \(node.senderID) before archiving services."
                return
            }

            do {
                let response = try await client.archiveService(
                    request: EvoMapServiceArchiveRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapServiceArchivePayload(
                            senderID: node.senderID,
                            listingID: service.listingID
                        )
                    )
                )

                serviceMutationMessage = response.message?.nonEmpty
                    ?? "Archived \(service.title) from the EvoMap marketplace."

                await refreshServices()

                prependRemoteMutationEvent(
                    title: "Archived Service",
                    detail: "\(service.title) (\(service.listingID))",
                    nodeID: node.id
                )
            } catch {
                serviceMutationErrorMessage = error.localizedDescription
            }
            return
        }

        serviceMutationMessage = nil
        serviceMutationErrorMessage = blocker
    }

    func rollbackSelectedRemoteSkill() async {
        guard activeRemoteSkillRollbackID == nil else { return }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedRemoteSkillRollbackPrerequisiteBlocker else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            activeRemoteSkillRollbackID = skill.skillId
            defer {
                activeRemoteSkillRollbackID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before rolling back published Skills."
                return
            }

            guard let targetVersion = remoteSkillRollbackTargetVersion else {
                remoteSkillMutationErrorMessage = "Choose an older version before requesting rollback."
                return
            }

            do {
                let response = try await client.rollbackSkill(
                    request: EvoMapSkillStoreRollbackRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreRollbackPayload(
                            senderID: node.senderID,
                            skillID: skill.skillId,
                            version: targetVersion
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: response.version?.nonEmpty ?? targetVersion,
                    message: response.message?.nonEmpty,
                    status: response.moderationStatus?.nonEmpty ?? response.status?.nonEmpty
                )

                await refreshRemoteSkills()

                remoteSkillMutationMessage = response.message?.nonEmpty
                    ?? "\(skill.name) rolled back to \(targetVersion)."

                prependRemoteMutationEvent(
                    title: "Rolled Back Skill",
                    detail: "\(skill.name) (\(skill.skillId)) -> \(targetVersion)",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func deleteRemoteSkillVersion(_ version: RemoteSkillVersion) async {
        guard activeRemoteSkillVersionDeleteKey == nil else { return }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedRemoteSkillVersionDeletePrerequisiteBlocker(for: version) else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            let mutationKey = remoteSkillVersionMutationKey(skillID: skill.skillId, version: version.version)
            activeRemoteSkillVersionDeleteKey = mutationKey
            defer {
                activeRemoteSkillVersionDeleteKey = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before deleting Skill Store history."
                return
            }

            do {
                let response = try await client.deleteSkillVersion(
                    request: EvoMapSkillStoreDeleteVersionRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreDeleteVersionPayload(
                            senderID: node.senderID,
                            skillID: skill.skillId,
                            version: version.version
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: nil,
                    message: response.message?.nonEmpty,
                    status: response.status?.nonEmpty
                )

                await refreshRemoteSkills()

                remoteSkillMutationMessage = response.message?.nonEmpty
                    ?? "Deleted history version \(version.version) from \(skill.name)."

                prependRemoteMutationEvent(
                    title: "Deleted Skill Version",
                    detail: "\(skill.name) (\(skill.skillId)) removed \(version.version)",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func deleteSelectedRemoteSkill() async {
        guard activeRemoteSkillDeleteID == nil else { return }
        guard let skill = selectedRemoteSkillSummary,
              let node = selectedNode else { return }
        guard let blocker = selectedRemoteSkillDeletePrerequisiteBlocker else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            activeRemoteSkillDeleteID = skill.skillId
            defer {
                activeRemoteSkillDeleteID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before deleting published Skills."
                return
            }

            do {
                let response = try await client.deleteSkill(
                    request: EvoMapSkillStoreDeleteRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreDeletePayload(
                            senderID: node.senderID,
                            skillID: skill.skillId
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: nil,
                    message: response.message?.nonEmpty,
                    status: "recycled"
                )
                selectedRecycledSkillID = skill.skillId
                skillWorkspaceMode = .recycleBin
                await refreshRecycleBin()
                await refreshRemoteSkills()

                remoteSkillMutationMessage = response.message?.nonEmpty
                    ?? "\(skill.name) moved to the recycle bin."

                prependRemoteMutationEvent(
                    title: "Deleted Skill",
                    detail: "\(skill.name) (\(skill.skillId)) moved to recycle bin",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func restoreSelectedRecycledSkill() async {
        guard activeRecycledSkillRestoreID == nil else { return }
        guard let skill = selectedRecycledSkill,
              let node = selectedNode else { return }
        guard let blocker = selectedRecycledSkillRestorePrerequisiteBlocker else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            activeRecycledSkillRestoreID = skill.skillId
            defer {
                activeRecycledSkillRestoreID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before restoring recycled Skills."
                return
            }

            do {
                let response = try await client.restoreSkill(
                    request: EvoMapSkillStoreDeleteRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreDeletePayload(
                            senderID: node.senderID,
                            skillID: skill.skillId
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: skill.version,
                    message: response.message?.nonEmpty,
                    status: "private"
                )
                await refreshRecycleBin()
                await refreshRemoteSkills()

                remoteSkillMutationMessage = response.message?.nonEmpty
                    ?? "\(skill.name) restored from the recycle bin as a private Skill."

                prependRemoteMutationEvent(
                    title: "Restored Skill",
                    detail: "\(skill.name) (\(skill.skillId)) restored from recycle bin",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func permanentlyDeleteSelectedRecycledSkill() async {
        guard activeRecycledSkillPermanentDeleteID == nil else { return }
        guard let skill = selectedRecycledSkill,
              let node = selectedNode else { return }
        guard let blocker = selectedRecycledSkillPermanentDeletePrerequisiteBlocker else {
            remoteSkillMutationMessage = nil
            remoteSkillMutationErrorMessage = nil
            activeRecycledSkillPermanentDeleteID = skill.skillId
            defer {
                activeRecycledSkillPermanentDeleteID = nil
                lastRefreshAt = Date()
            }

            guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
                remoteSkillMutationErrorMessage = "Store the node_secret for \(node.senderID) before permanently deleting recycled Skills."
                return
            }

            do {
                let response = try await client.permanentlyDeleteSkill(
                    request: EvoMapSkillStoreDeleteRequest(
                        baseURL: ConsoleAppSettings.hubBaseURL,
                        nodeSecret: nodeSecret,
                        payload: EvoMapSkillStoreDeletePayload(
                            senderID: node.senderID,
                            skillID: skill.skillId
                        )
                    )
                )

                applyRemoteMutationToLocalSkills(
                    skillID: skill.skillId,
                    remoteVersion: nil,
                    message: response.message?.nonEmpty,
                    status: "deleted"
                )
                await refreshRecycleBin()

                remoteSkillMutationMessage = response.message?.nonEmpty
                    ?? "\(skill.name) was permanently deleted from the recycle bin."

                prependRemoteMutationEvent(
                    title: "Permanently Deleted Skill",
                    detail: "\(skill.name) (\(skill.skillId)) permanently deleted",
                    nodeID: node.id
                )
            } catch {
                remoteSkillMutationErrorMessage = error.localizedDescription
            }
            return
        }

        remoteSkillMutationMessage = nil
        remoteSkillMutationErrorMessage = blocker
    }

    func publishSelectedSkill() async {
        guard !isPublishingSkill else { return }
        guard let skill = selectedSkill,
              let node = selectedNode else { return }
        guard selectedSkillPublishPrerequisiteBlocker == nil else {
            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index].lastPublishErrorMessage = selectedSkillPublishPrerequisiteBlocker
            }
            return
        }
        guard let nodeSecret = loadStoredSecret(for: node.senderID) else {
            if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                skills[index].lastPublishErrorMessage = "No node_secret found for \(node.senderID)."
            }
            return
        }

        activeSkillPublishID = skill.id
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index].lastPublishErrorMessage = nil
        }

        defer {
            activeSkillPublishID = nil
            lastRefreshAt = Date()
        }

        let publishRequest = EvoMapSkillStoreMutationRequest(
            baseURL: node.apiBaseURL,
            nodeSecret: nodeSecret,
            payload: skill.skillStorePayload(senderID: node.senderID)
        )

        do {
            let response = try await client.publishSkill(request: publishRequest)
            applySkillMutationResponse(
                response,
                action: .publish,
                skillID: skill.id,
                nodeID: node.id,
                senderID: node.senderID
            )
        } catch let error as EvoMapClientError {
            guard case .httpStatus(409, _) = error else {
                applySkillMutationFailure(
                    message: error.localizedDescription,
                    skillID: skill.id,
                    nodeID: node.id
                )
                return
            }

            let updateRequest = EvoMapSkillStoreMutationRequest(
                baseURL: node.apiBaseURL,
                nodeSecret: nodeSecret,
                payload: skill.skillStorePayload(
                    senderID: node.senderID,
                    changelog: Self.defaultSkillUpdateChangelog
                )
            )

            do {
                let response = try await client.updateSkill(request: updateRequest)
                applySkillMutationResponse(
                    response,
                    action: .update,
                    skillID: skill.id,
                    nodeID: node.id,
                    senderID: node.senderID
                )
            } catch {
                applySkillMutationFailure(
                    message: error.localizedDescription,
                    skillID: skill.id,
                    nodeID: node.id
                )
            }
        } catch {
            applySkillMutationFailure(
                message: error.localizedDescription,
                skillID: skill.id,
                nodeID: node.id
            )
        }
    }

    private var selectedSkillPublishPrerequisiteBlocker: String? {
        guard let skill = selectedSkill else {
            return "Import a local `SKILL.md` file before publishing."
        }
        guard let node = selectedNode else {
            return "Select a connected node as the Skill Store publisher."
        }
        if skill.isPublishReady == false {
            return "\(skill.errorCount) blocking validation issue(s) still need changes before publish."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before publishing."
        }
        if let skillStoreStatus = node.skillStoreStatus, skillStoreStatus.eligible == false {
            return skillStoreStatus.hint?.nonEmpty ?? "The selected node is not eligible for Skill Store publishing yet."
        }
        return nil
    }

    private var selectedRemoteSkillDownloadPrerequisiteBlocker: String? {
        guard selectedRemoteSkillSummary != nil else {
            return "Select a remote skill before downloading."
        }
        guard let node = selectedNode else {
            return "Select a connected node to authenticate the Skill Store download."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before downloading from the public Skill Store."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before downloading from the Skill Store."
        }
        return nil
    }

    private var selectedRemoteSkillManagementPrerequisiteBlocker: String? {
        guard selectedRemoteSkillSummary != nil else {
            return "Select a remote skill before using Skill Store management actions."
        }
        guard let node = selectedNode else {
            return "Select a connected node to authenticate Skill Store management actions."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before managing public Skill Store entries."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before managing published Skills."
        }
        if let authorNodeID = selectedRemoteSkillAuthorNodeID?.nonEmpty,
           authorNodeID != node.senderID {
            return "Select the author node `\(authorNodeID)` to manage this Skill Store entry."
        }
        return nil
    }

    private var selectedRemoteSkillVisibilityPrerequisiteBlocker: String? {
        selectedRemoteSkillManagementPrerequisiteBlocker
    }

    private var selectedRemoteSkillRollbackPrerequisiteBlocker: String? {
        if let blocker = selectedRemoteSkillManagementPrerequisiteBlocker {
            return blocker
        }
        guard let currentVersion = selectedRemoteSkillCurrentVersion?.nonEmpty else {
            return "Load the current version before rolling back."
        }
        guard availableRemoteRollbackVersions.isEmpty == false else {
            return "No older versions are available for rollback."
        }
        guard let targetVersion = remoteSkillRollbackTargetVersion?.nonEmpty else {
            return "Choose an older version before requesting rollback."
        }
        guard targetVersion != currentVersion else {
            return "Choose an older version than the current live version."
        }
        guard availableRemoteRollbackVersions.contains(where: { $0.version == targetVersion }) else {
            return "The selected rollback target is no longer available."
        }
        return nil
    }

    private var selectedRemoteSkillDeletePrerequisiteBlocker: String? {
        selectedRemoteSkillManagementPrerequisiteBlocker
    }

    private func selectedRemoteSkillVersionDeletePrerequisiteBlocker(for version: RemoteSkillVersion?) -> String? {
        if let blocker = selectedRemoteSkillManagementPrerequisiteBlocker {
            return blocker
        }
        guard let version else {
            return "Choose a historical version before deleting it."
        }
        guard let currentVersion = selectedRemoteSkillCurrentVersion?.nonEmpty else {
            return "Load the current live version before deleting history."
        }
        guard remoteSkillVersions.count > 1 else {
            return "The last remaining version cannot be deleted."
        }
        guard version.version != currentVersion else {
            return "The current live version cannot be deleted."
        }
        guard remoteSkillVersions.contains(where: { $0.version == version.version }) else {
            return "The selected version is no longer available."
        }
        return nil
    }

    private var servicePublishAccessBlocker: String? {
        guard let node = selectedNode else {
            return "Select a connected node before publishing services."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before using marketplace publishing actions."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before publishing services."
        }
        return nil
    }

    private var selectedServiceManagementPrerequisiteBlocker: String? {
        guard selectedServiceSummary != nil else {
            return "Select a service before using marketplace management actions."
        }
        if let blocker = servicePublishAccessBlocker {
            return blocker
        }
        guard let node = selectedNode else {
            return "Select a connected node before managing services."
        }
        if let providerNodeID = selectedServiceProviderNodeID?.nonEmpty,
           providerNodeID != node.senderID {
            return "Select the author node `\(providerNodeID)` to manage this service."
        }
        return nil
    }

    private var selectedServiceStatusPrerequisiteBlocker: String? {
        if let blocker = selectedServiceManagementPrerequisiteBlocker {
            return blocker
        }
        if selectedServiceStatus.lowercased() == ServiceLifecycleStatus.archived.rawValue {
            return "Archived services cannot be paused or resumed."
        }
        return nil
    }

    private var selectedServiceArchivePrerequisiteBlocker: String? {
        if let blocker = selectedServiceManagementPrerequisiteBlocker {
            return blocker
        }
        if selectedServiceStatus.lowercased() == ServiceLifecycleStatus.archived.rawValue {
            return "This service is already archived."
        }
        return nil
    }

    private var serviceDraftSubmitPrerequisiteBlocker: String? {
        if let blocker = servicePublishAccessBlocker {
            return blocker
        }

        let title = serviceDraft.title.nonEmpty
        let description = serviceDraft.description.nonEmpty
        let capabilities = serviceDraftParsedCapabilities
        let useCases = serviceDraftParsedUseCases

        guard title != nil else {
            return "Enter a service title before publishing."
        }
        guard description != nil else {
            return "Enter a service description before publishing."
        }
        guard capabilities.isEmpty == false else {
            return "Add at least one capability before publishing."
        }
        guard useCases.isEmpty == false else {
            return "Add at least one use case before publishing."
        }
        guard serviceDraft.pricePerTask > 0 else {
            return "Price per task must be greater than zero."
        }
        guard serviceDraft.maxConcurrent > 0 else {
            return "Max concurrency must be at least one."
        }
        if serviceDraft.mode == .update {
            guard serviceDraft.listingID?.nonEmpty != nil else {
                return "Load a service listing before updating it."
            }
            guard let node = selectedNode else {
                return "Select a connected node before updating this service."
            }
            if let authorNodeID = serviceDraft.authorNodeID?.nonEmpty,
               authorNodeID != node.senderID {
                return "Select the author node `\(authorNodeID)` before updating this service."
            }
        }
        return nil
    }

    private var selectedServiceOrderPrerequisiteBlocker: String? {
        guard let service = selectedServiceSummary else {
            return "Select a service before placing an order."
        }
        guard let node = selectedNode else {
            return "Select a connected node before placing an order."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before using marketplace order actions."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before placing orders."
        }
        if let providerNodeID = selectedServiceProviderNodeID?.nonEmpty,
           providerNodeID == node.senderID {
            return "The selected node owns this service. Choose a different requester node."
        }
        if selectedServiceStatus.lowercased() == ServiceLifecycleStatus.archived.rawValue {
            return "Archived services cannot receive new orders."
        }
        if service.listingID.nonEmpty == nil {
            return "The selected service does not have a valid listing identifier."
        }
        return nil
    }

    private var orderDraftSubmitPrerequisiteBlocker: String? {
        if let blocker = selectedServiceOrderPrerequisiteBlocker {
            return blocker
        }
        guard orderDraft.listingID.nonEmpty != nil else {
            return "Load a service listing before placing an order."
        }
        guard orderDraft.question.nonEmpty != nil else {
            return "Describe what you want the provider to do before placing an order."
        }
        return nil
    }

    private var selectedOrderServiceRatingPrerequisiteBlocker: String? {
        guard let order = selectedTrackedOrder else {
            return "Select a tracked order before rating the provider."
        }
        guard let node = selectedNode else {
            return "Select the requester node before submitting a service rating."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before using marketplace rating actions."
        }
        guard order.requesterNodeID == node.senderID else {
            return "Select the requester node `\(order.requesterNodeID)` before rating this service."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before submitting service ratings."
        }
        guard order.listingID?.nonEmpty != nil else {
            return "This tracked order is missing a service listing identifier."
        }
        guard order.statusCategory == .completed else {
            return "Only completed orders can be rated."
        }
        if order.lastRatedAt != nil {
            return "This order has already been rated locally."
        }
        return nil
    }

    private var serviceRatingSubmitPrerequisiteBlocker: String? {
        if let blocker = selectedOrderServiceRatingPrerequisiteBlocker {
            return blocker
        }
        guard serviceRatingDraft.listingID.nonEmpty != nil else {
            return "Load a completed order with a valid listing before rating this service."
        }
        guard (1...5).contains(serviceRatingDraft.rating) else {
            return "Service ratings must be between 1 and 5."
        }
        return nil
    }

    private var knowledgeGraphIngestPrerequisiteBlocker: String? {
        if let blocker = knowledgeGraphAccessBlocker {
            return blocker
        }

        let hasEntityDraft = knowledgeGraphEntityDraft.name.nonEmpty != nil
        let hasRelationshipDraft = knowledgeGraphRelationshipDraft.sourceName.nonEmpty != nil
            || knowledgeGraphRelationshipDraft.targetName.nonEmpty != nil

        guard hasEntityDraft || hasRelationshipDraft else {
            return "Add an entity or relationship draft before writing to the Knowledge Graph."
        }

        if hasEntityDraft {
            guard knowledgeGraphEntityDraft.description.nonEmpty != nil else {
                return "Enter an entity description before writing to the Knowledge Graph."
            }
        }

        if hasRelationshipDraft {
            guard knowledgeGraphRelationshipDraft.sourceName.nonEmpty != nil else {
                return "Choose a source entity name before writing a relationship."
            }
            guard knowledgeGraphRelationshipDraft.targetName.nonEmpty != nil else {
                return "Choose a target entity name before writing a relationship."
            }
        }

        return nil
    }

    private var selectedOrderRefreshPrerequisiteBlocker: String? {
        guard let order = selectedTrackedOrder else {
            return "Select a tracked order before refreshing it."
        }
        if loadStoredSecret(for: order.requesterNodeID) == nil {
            return "Store the node_secret for \(order.requesterNodeID) before refreshing task detail."
        }
        return nil
    }

    private func orderAcceptancePrerequisiteBlocker(for submission: RemoteOrderSubmission) -> String? {
        if let blocker = selectedOrderRefreshPrerequisiteBlocker {
            return blocker
        }
        guard selectedTrackedOrder != nil else {
            return "Select a tracked order before accepting a submission."
        }
        guard submission.submissionID.nonEmpty != nil else {
            return "The selected submission is missing an identifier."
        }
        if submission.acceptedAt != nil {
            return "This submission is already accepted."
        }
        switch selectedOrderStatusCategory {
        case .completed:
            return "This order is already completed."
        case .expired:
            return "Expired orders cannot accept submissions."
        default:
            break
        }
        return nil
    }

    private var recycleBinAccessBlocker: String? {
        guard let node = selectedNode else {
            return "Select a connected node before opening the recycle bin."
        }
        guard normalizedHubBaseURL(node.apiBaseURL) == normalizedHubBaseURL(ConsoleAppSettings.hubBaseURL) else {
            return "Select a node connected to \(ConsoleAppSettings.hubBaseURL) before loading recycle-bin entries."
        }
        if loadStoredSecret(for: node.senderID) == nil {
            return "Store the node_secret for \(node.senderID) before opening the recycle bin."
        }
        return nil
    }

    private var selectedRecycledSkillManagementPrerequisiteBlocker: String? {
        if let blocker = recycleBinAccessBlocker {
            return blocker
        }
        guard let skill = selectedRecycledSkill else {
            return "Select a recycled skill before using recycle-bin actions."
        }
        if let node = selectedNode,
           let authorNodeID = skill.author?.nodeId.nonEmpty,
           authorNodeID != node.senderID {
            return "Select the author node `\(authorNodeID)` to manage this recycled Skill."
        }
        return nil
    }

    private var selectedRecycledSkillRestorePrerequisiteBlocker: String? {
        selectedRecycledSkillManagementPrerequisiteBlocker
    }

    private var selectedRecycledSkillPermanentDeletePrerequisiteBlocker: String? {
        selectedRecycledSkillManagementPrerequisiteBlocker
    }

    private func scheduleRemoteSkillSearchIfNeeded() {
        remoteSkillSearchTask?.cancel()
        guard selectedSection == .skills, skillWorkspaceMode == .store else { return }

        remoteSkillSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, Task.isCancelled == false else { return }
            while self.isLoadingRemoteSkills {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard Task.isCancelled == false else { return }
            }
            await self.refreshRemoteSkills()
        }
    }

    private func scheduleServiceSearchIfNeeded() {
        serviceSearchTask?.cancel()
        guard selectedSection == .services else { return }

        serviceSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, Task.isCancelled == false else { return }
            while self.isLoadingServices {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard Task.isCancelled == false else { return }
            }
            await self.refreshServices()
        }
    }

    private func applySkillMutationResponse(
        _ response: EvoMapSkillStoreMutationResponse,
        action: SkillStoreMutationAction,
        skillID: SkillRecord.ID,
        nodeID: NodeRecord.ID,
        senderID: String
    ) {
        let publishedAt = Date()
        guard let skillIndex = skills.firstIndex(where: { $0.id == skillID }) else { return }

        var skill = skills[skillIndex]
        let resolvedVersion = response.version?.nonEmpty ?? (action == .publish && skill.remoteVersion == nil ? "1.0.0" : skill.suggestedVersion)
        let resolvedMessage = response.message?.nonEmpty ?? action.defaultMessage
        let resolvedStatus = response.moderationStatus?.nonEmpty ?? response.status?.nonEmpty ?? "published"
        let isFirstRemoteVersion = skill.remoteVersion == nil

        skill.remoteVersion = resolvedVersion
        skill.remoteStatus = resolvedStatus
        skill.state = .published
        skill.updatedAt = publishedAt
        skill.lastPublishedAt = publishedAt
        skill.lastPublishedBySenderID = senderID
        skill.lastPublishMessage = resolvedMessage
        skill.lastPublishErrorMessage = nil
        skills[skillIndex] = skill

        guard let nodeIndex = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var node = nodes[nodeIndex]

        if action == .publish,
           isFirstRemoteVersion,
           var snapshot = node.heartbeatSnapshot,
           var skillStore = snapshot.skillStore {
            skillStore.publishedSkillCount += 1
            snapshot.skillStore = skillStore
            node.heartbeatSnapshot = snapshot
        }

        prependEvents(
            [
                NodeEvent(
                    timestamp: publishedAt,
                    title: action.eventTitle,
                    detail: "\(skill.name) (\(skill.skillID)) -> \(resolvedVersion). \(resolvedMessage)"
                )
            ],
            to: &node
        )
        nodes[nodeIndex] = node
        persistLiveNodes()
    }

    private func applyRemoteMutationToLocalSkills(
        skillID: String,
        remoteVersion: String?,
        message: String?,
        status: String?
    ) {
        let updatedAt = Date()

        for index in skills.indices where skills[index].skillID == skillID {
            if let remoteVersion = remoteVersion?.nonEmpty {
                skills[index].remoteVersion = remoteVersion
            }
            if let status = status?.nonEmpty {
                skills[index].remoteStatus = status
            }
            if let message = message?.nonEmpty {
                skills[index].lastPublishMessage = message
            }
            skills[index].updatedAt = updatedAt
        }
    }

    private func prependRemoteMutationEvent(title: String, detail: String, nodeID: NodeRecord.ID) {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var node = nodes[nodeIndex]
        prependEvents(
            [
                NodeEvent(
                    timestamp: Date(),
                    title: title,
                    detail: detail
                )
            ],
            to: &node
        )
        nodes[nodeIndex] = node
        persistLiveNodes()
    }

    private func applySkillMutationFailure(
        message: String,
        skillID: SkillRecord.ID,
        nodeID: NodeRecord.ID
    ) {
        let failedAt = Date()

        if let skillIndex = skills.firstIndex(where: { $0.id == skillID }) {
            skills[skillIndex].updatedAt = failedAt
            skills[skillIndex].lastPublishErrorMessage = message
        }

        guard let nodeIndex = nodes.firstIndex(where: { $0.id == nodeID }),
              let skill = skills.first(where: { $0.id == skillID }) else { return }

        var node = nodes[nodeIndex]
        prependEvents(
            [
                NodeEvent(
                    timestamp: failedAt,
                    title: "Skill publish failed",
                    detail: "\(skill.name) (\(skill.skillID)) could not be synced. \(message)"
                )
            ],
            to: &node
        )
        nodes[nodeIndex] = node
        persistLiveNodes()
    }

    private func applyHelloResponse(_ response: EvoMapHelloResponse, draft: NodeConnectionDraft) {
        let senderID = response.yourNodeID
        var node = nodes.first(where: { $0.id == draft.editingNodeID })
            ?? nodes.first(where: { $0.senderID == senderID })
            ?? NodeRecord(
                id: UUID(),
                name: draft.nodeName,
                senderID: senderID,
                apiBaseURL: draft.baseURL,
                environment: draft.environment,
                modelName: draft.modelName,
                geneCount: draft.geneCount,
                capsuleCount: draft.capsuleCount,
                claimState: .pending,
                heartbeat: .healthy,
                lastSeen: Date(),
                onlineWorkers: 0,
                creditBalance: 0,
                claimCode: nil,
                claimURL: nil,
                referralCode: nil,
                survivalStatus: nil,
                nodeSecretStored: false,
                lastErrorMessage: nil,
                notes: "",
                recentEvents: [],
                recommendedHeartbeatIntervalMS: nil,
                heartbeatEndpoint: nil,
                heartbeatSnapshot: nil,
                isSampleData: false
            )

        let secretSaved = persistNodeSecretIfPresent(response.nodeSecret, senderID: senderID)

        node.name = draft.nodeName
        node.senderID = senderID
        node.apiBaseURL = draft.baseURL
        node.environment = draft.environment
        node.modelName = draft.modelName
        node.geneCount = draft.geneCount
        node.capsuleCount = draft.capsuleCount
        node.isSampleData = false
        node.lastSeen = Date()
        node.creditBalance = response.creditBalance ?? node.creditBalance
        node.claimCode = response.claimCode
        node.claimURL = response.claimURL
        node.referralCode = response.referralCode
        node.survivalStatus = response.survivalStatus
        node.nodeSecretStored = secretSaved || hasStoredSecret(for: senderID)
        node.recommendedHeartbeatIntervalMS = response.heartbeatIntervalMS
        node.heartbeatEndpoint = response.heartbeatEndpoint
        node.claimState = Self.resolvedClaimState(
            claimed: response.claimed,
            stateValues: [response.claimState, response.claimStatus, response.bindingStatus],
            claimedAt: response.claimedAt,
            hasClaimLink: response.claimURL?.nonEmpty != nil || response.claimCode?.nonEmpty != nil,
            current: node.claimState
        )
        node.heartbeat = makeHeartbeatState(for: node.claimState, snapshot: node.heartbeatSnapshot ?? .empty)
        node.notes = makeHelloNotes(for: node, response: response)

        prependEvents(
            [
                NodeEvent(
                    timestamp: Date(),
                    title: "Hello acknowledged",
                    detail: [
                        "Node \(senderID) was acknowledged by the Hub.",
                        response.migratedFrom.map { "Migrated from \($0)." },
                        response.mergeHint.map { "Merge hint: \($0)." },
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")
                )
            ],
            to: &node
        )

        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        } else {
            nodes.insert(node, at: 0)
        }

        selectedNodeID = node.id
        isInspectorPresented = true
        lastRefreshAt = Date()
        refreshStoredSecretFlags()
    }

    private func applyHeartbeatResponse(_ response: EvoMapHeartbeatResponse, for nodeID: NodeRecord.ID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        let refreshedAt = Date()
        let snapshot = makeHeartbeatSnapshot(from: response, refreshedAt: refreshedAt)
        var node = nodes[index]

        node.lastSeen = refreshedAt
        node.creditBalance = response.creditBalance ?? node.creditBalance
        node.survivalStatus = response.survivalStatus ?? node.survivalStatus
        node.heartbeatSnapshot = snapshot
        node.lastErrorMessage = nil
        node.claimState = Self.resolvedClaimState(
            claimed: response.claimed,
            stateValues: [response.claimState, response.claimStatus, response.bindingStatus],
            claimedAt: response.claimedAt,
            hasClaimLink: node.claimURL?.nonEmpty != nil || node.claimCode?.nonEmpty != nil,
            current: node.claimState
        )
        node.heartbeat = makeHeartbeatState(for: node.claimState, snapshot: snapshot)
        node.notes = makeHeartbeatNotes(for: node, snapshot: snapshot)
        if snapshot.accountability?.quarantineStrikes ?? 0 > 0 {
            node.onlineWorkers = max(node.onlineWorkers - 1, 0)
        }

        var newEvents = [NodeEvent(
            timestamp: refreshedAt,
            title: "Heartbeat synced",
            detail: makeHeartbeatEventDetail(from: snapshot, response: response)
        )]

        if let recommendation = snapshot.accountability?.recommendation?.nonEmpty {
            newEvents.append(
                NodeEvent(
                    timestamp: refreshedAt,
                    title: "Accountability signal",
                    detail: recommendation
                )
            )
        }

        if let firstPendingEvent = snapshot.pendingEvents.first {
            newEvents.append(
                NodeEvent(
                    timestamp: firstPendingEvent.createdAt ?? refreshedAt,
                    title: "Pending event: \(firstPendingEvent.type)",
                    detail: firstPendingEvent.summary
                )
            )
        }

        prependEvents(newEvents, to: &node)
        nodes[index] = node
        persistLiveNodes()
    }

    private func applyHeartbeatFailure(message: String, for nodeID: NodeRecord.ID, markOffline: Bool) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        var node = nodes[index]
        node.lastErrorMessage = message
        node.heartbeat = markOffline ? .offline : .warning
        node.notes = [
            "Authenticated heartbeat could not be completed.",
            node.nodeSecretStored ? "Check the Hub endpoint and your local network." : "Store node_secret in Keychain before retrying.",
        ]
        .joined(separator: " ")

        prependEvents(
            [
                NodeEvent(
                    timestamp: Date(),
                    title: "Heartbeat failed",
                    detail: message
                )
            ],
            to: &node
        )

        nodes[index] = node
        persistLiveNodes()
    }

    private func applyHeartbeatNotice(message: String, for nodeID: NodeRecord.ID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        var node = nodes[index]
        node.lastErrorMessage = message
        node.notes = message

        let shouldAppendEvent = node.recentEvents.first?.title != "Heartbeat skipped"
            || Date().timeIntervalSince(node.recentEvents.first?.timestamp ?? .distantPast) > 30
        if shouldAppendEvent {
            prependEvents(
                [
                    NodeEvent(
                        timestamp: Date(),
                        title: "Heartbeat skipped",
                        detail: message
                    )
                ],
                to: &node
            )
        }

        nodes[index] = node
        persistLiveNodes()
    }

    private static func heartbeatFailureMessage(_ error: Error) -> String {
        if isRateLimitError(error) {
            return AppLocalization.string(
                "node.heartbeat.error.rate_limited",
                fallback: "EvoMap is rate-limiting heartbeat requests. Wait a minute or two before refreshing again."
            )
        }
        return error.localizedDescription
    }

    private static func bountyClaimFailureMessage(_ error: Error) -> String {
        if case EvoMapClientError.httpStatus(let status, let message) = error {
            let normalized = message.lowercased()
            if status == 409 && normalized.contains("task_not_open") {
                return AppLocalization.string(
                    "credits.bounty.error.task_not_open",
                    fallback: "HTTP 409: This bounty is not open for claiming now. The public board can show matched/pending/stale bounties, but /a2a/task/claim only accepts open task IDs. Refresh bounties or choose another Open task."
                )
            }
            if status == 403 && normalized.contains("insufficient_reputation") {
                return AppLocalization.string(
                    "credits.bounty.error.insufficient_reputation",
                    fallback: "HTTP 403: This node's reputation is not high enough for the selected bounty. EvoMap docs gate bounty claims by reputation: >=20 for 1+ credits, >=40 for 5+ credits, and >=65 for 10+ credits. Track it for later or choose an easier task."
                )
            }
        }
        return error.localizedDescription
    }

    private static func isTaskNotOpenError(_ error: Error) -> Bool {
        if case EvoMapClientError.httpStatus(let status, let message) = error {
            return status == 409 && message.lowercased().contains("task_not_open")
        }
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("409") && normalized.contains("task_not_open")
    }

    private static func isRateLimitError(_ error: Error) -> Bool {
        if case EvoMapClientError.httpStatus(let status, _) = error, status == 429 {
            return true
        }
        let message = error.localizedDescription.lowercased()
        return message.contains("429") || message.contains("rate_limited") || message.contains("rate limited")
    }

    private func makeHeartbeatSnapshot(from response: EvoMapHeartbeatResponse, refreshedAt: Date) -> NodeHeartbeatSnapshot {
        let availableTasks = (response.availableTasks ?? []).map(Self.makeTaskPreview)
        let availableWork = (response.availableWork ?? []).map(Self.makeTaskPreview)
        let overdueTasks = (response.overdueTasks ?? []).map(Self.makeOverdueTaskPreview)
        let pendingEvents = (response.pendingEvents ?? []).map(Self.makePendingEventPreview)
        let peers = (response.peers ?? []).map(Self.makePeerPreview)
        let accountability = Self.makeAccountabilitySnapshot(from: response.accountability)
        let skillStore = Self.makeSkillStoreStatus(from: response.skillStore)

        return NodeHeartbeatSnapshot(
            nextHeartbeatAt: response.nextHeartbeatMS.map { refreshedAt.addingTimeInterval(TimeInterval($0) / 1000) },
            availableTasks: availableTasks,
            availableWork: availableWork,
            overdueTasks: overdueTasks,
            pendingEvents: pendingEvents,
            peers: peers,
            accountability: accountability,
            skillStore: skillStore
        )
    }

    private func makeHeartbeatState(for claimState: NodeClaimState, snapshot: NodeHeartbeatSnapshot) -> NodeHeartbeatState {
        if snapshot.overdueTasks.isEmpty,
           snapshot.accountability?.needsAttention != true,
           claimState != .pending {
            return .healthy
        }
        return .warning
    }

    private static func resolvedClaimState(
        claimed: Bool?,
        stateValues: [String?],
        claimedAt: String?,
        hasClaimLink: Bool,
        current: NodeClaimState
    ) -> NodeClaimState {
        if claimed == true || claimedAt?.nonEmpty != nil {
            return .claimed
        }
        if let claimed, claimed == false {
            return hasClaimLink ? .pending : .unclaimed
        }

        for value in stateValues.compactMap({ $0?.nonEmpty }) {
            switch normalizedClaimStatus(value) {
            case "claimed", "bound", "verified", "confirmed", "complete", "completed", "active", "success", "succeeded", "ok":
                return .claimed
            case "pending", "waiting", "claim_pending", "needs_claim", "requires_claim", "unverified":
                return .pending
            case "unclaimed", "not_claimed", "unbound", "none", "missing":
                return hasClaimLink ? .pending : .unclaimed
            default:
                continue
            }
        }

        if current == .claimed {
            return .claimed
        }
        return hasClaimLink ? .pending : .unclaimed
    }

    private static func normalizedClaimStatus(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func makeHelloNotes(for node: NodeRecord, response: EvoMapHelloResponse) -> String {
        var parts = ["Model: \(node.modelName)."]
        parts.append(node.nodeSecretStored ? "Bearer auth is stored in Keychain." : "Save the returned node_secret locally before sending heartbeat.")
        if node.claimState == .claimed {
            parts.append("Claim is marked complete for this node.")
        } else if let claimURL = response.claimURL, !claimURL.isEmpty {
            parts.append("Claim this node in the browser to bind it to your EvoMap account.")
        } else {
            parts.append("Node is ready for authenticated follow-up requests.")
        }
        if let heartbeatIntervalMS = response.heartbeatIntervalMS {
            parts.append("Hub recommended a heartbeat every \(Self.formattedHeartbeatInterval(milliseconds: heartbeatIntervalMS)).")
        }
        if response.recommendedTasks?.isEmpty == false {
            parts.append("Hub returned \(response.recommendedTasks?.count ?? 0) recommended tasks.")
        }
        return parts.joined(separator: " ")
    }

    private func makeHeartbeatNotes(for node: NodeRecord, snapshot: NodeHeartbeatSnapshot) -> String {
        var parts = ["Authenticated heartbeat is synced through `/a2a/heartbeat` using the Keychain-backed node_secret."]
        if node.claimState == .pending {
            parts.append("If the EvoMap claim page already showed success, mark this node as claimed locally; the public heartbeat docs do not expose a stable claim-state field yet.")
        } else if node.claimState == .claimed {
            parts.append("Claim is marked complete for this node.")
        }
        if let nextHeartbeatAt = snapshot.nextHeartbeatAt {
            parts.append("Next heartbeat target is \(Self.relativeLabel(for: nextHeartbeatAt)).")
        }
        if snapshot.dispatchCount > 0 {
            parts.append("Hub exposed \(snapshot.dispatchCount) dispatch item(s) for local polling.")
        }
        if snapshot.pendingEvents.isEmpty == false {
            parts.append("\(snapshot.pendingEvents.count) pending event(s) are waiting in the poll queue.")
        }
        if let recommendation = snapshot.accountability?.recommendation?.nonEmpty {
            parts.append(recommendation)
        }
        if snapshot.peers.isEmpty == false {
            parts.append("Visible peer count: \(snapshot.peers.count).")
        }
        return parts.joined(separator: " ")
    }

    private func makeHeartbeatEventDetail(from snapshot: NodeHeartbeatSnapshot, response: EvoMapHeartbeatResponse) -> String {
        var parts = [
            "Dispatch \(snapshot.dispatchCount)",
            "Pending events \(snapshot.pendingEvents.count)",
            "Peers \(snapshot.peers.count)",
            "Overdue \(snapshot.overdueTasks.count)",
        ]
        if let nextHeartbeatAt = snapshot.nextHeartbeatAt {
            parts.append("Next due \(Self.relativeLabel(for: nextHeartbeatAt))")
        }
        if let status = response.status?.nonEmpty {
            parts.append("Status \(status)")
        }
        return parts.joined(separator: " · ")
    }

    private func persistNodeSecretIfPresent(_ nodeSecret: String?, senderID: String) -> Bool {
        guard let nodeSecret = nodeSecret?.trimmingCharacters(in: .whitespacesAndNewlines),
              !nodeSecret.isEmpty else {
            return false
        }

        do {
            try nodeSecretStore.saveNodeSecret(nodeSecret, for: senderID)
            return true
        } catch {
            nodeConnectionErrorMessage = "Hello succeeded, but saving node_secret failed: \(error.localizedDescription)"
            return false
        }
    }

    private func refreshStoredSecretFlags() {
        nodes = nodes.map { node in
            var node = node
            node.nodeSecretStored = hasStoredSecret(for: node.senderID)
            return node
        }
        if nodes.contains(where: { $0.isSampleData == false }) {
            persistLiveNodes()
        }
    }

    private func hasStoredSecret(for senderID: String) -> Bool {
        loadStoredSecret(for: senderID)?.nonEmpty != nil
    }

    private func loadStoredSecret(for senderID: String) -> String? {
        (try? nodeSecretStore.loadNodeSecret(for: senderID))?.nonEmpty
    }

    private func conflictingLocalSkill(for skillID: String, downloadedSkillPath: String) -> SkillRecord? {
        skills.first { skill in
            guard skill.skillID == skillID else { return false }
            guard let sourcePath = skill.sourcePath?.nonEmpty else { return false }
            guard sourcePath != downloadedSkillPath else { return false }
            return isManagedSkillStoreDownloadPath(sourcePath) == false
        }
    }

    private func applyDownloadedSkillMetadata(
        skillID: String,
        sourcePath: String,
        downloadedAt: Date,
        authorNodeID: String?,
        storeVersion: String?,
        storeDirectoryPath: String,
        creditCost: Int?
    ) {
        guard let skillIndex = skills.firstIndex(where: {
            $0.skillID == skillID && $0.sourcePath == sourcePath
        }) ?? skills.firstIndex(where: { $0.skillID == skillID }) else {
            return
        }

        skills[skillIndex].storeSnapshotVersion = storeVersion?.nonEmpty
        skills[skillIndex].downloadedFromStoreAt = downloadedAt
        skills[skillIndex].downloadedFromStoreAuthorNodeID = authorNodeID?.nonEmpty
        skills[skillIndex].downloadedStoreDirectoryPath = storeDirectoryPath
        skills[skillIndex].downloadedCreditCost = creditCost
        selectedSkillID = skills[skillIndex].id
    }

    private func isManagedSkillStoreDownloadPath(_ sourcePath: String) -> Bool {
        sourcePath.contains("/EvomapConsole/SkillStoreDownloads/")
    }

    private func remoteSkillVersionMutationKey(skillID: String, version: String) -> String {
        "\(skillID)::\(version)"
    }

    private func parseServiceList(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func canAcceptSelectedOrderSubmission(_ submission: RemoteOrderSubmission) -> Bool {
        activeOrderAcceptanceKey == nil && orderAcceptancePrerequisiteBlocker(for: submission) == nil
    }

    func isAcceptingSelectedOrderSubmission(_ submission: RemoteOrderSubmission) -> Bool {
        guard let order = selectedTrackedOrder else { return false }
        return activeOrderAcceptanceKey == orderAcceptanceKey(taskID: order.taskID, submissionID: submission.submissionID)
    }

    private func fetchOrderDetail(for order: TrackedServiceOrder) async throws -> RemoteOrderDetail {
        guard let nodeSecret = loadStoredSecret(for: order.requesterNodeID) else {
            throw NSError(
                domain: "EvomapConsole.OrderAuth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Store the node_secret for \(order.requesterNodeID) before refreshing task detail."]
            )
        }

        return try await client.orderDetail(
            request: EvoMapTaskDetailRequest(
                baseURL: ConsoleAppSettings.hubBaseURL,
                taskID: order.taskID,
                nodeSecret: nodeSecret
            )
        )
    }

    private func mergedTrackedOrder(existing: TrackedServiceOrder, with detail: RemoteOrderDetail, syncedAt: Date) -> TrackedServiceOrder {
        let latestSubmission = detail.submissions.max { lhs, rhs in
            (lhs.submittedAt ?? .distantPast) < (rhs.submittedAt ?? .distantPast)
        }

        return TrackedServiceOrder(
            taskID: detail.taskID,
            listingID: detail.listingID?.nonEmpty ?? existing.listingID?.nonEmpty,
            serviceTitle: detail.serviceTitle.nonEmpty ?? existing.serviceTitle,
            question: detail.question?.nonEmpty ?? existing.question,
            requesterNodeID: detail.requesterNodeID?.nonEmpty ?? existing.requesterNodeID,
            providerNodeID: detail.providerNodeID?.nonEmpty ?? existing.providerNodeID,
            providerAlias: detail.providerAlias?.nonEmpty ?? existing.providerAlias,
            status: detail.status?.nonEmpty ?? existing.status,
            creditsSpent: detail.creditsSpent ?? existing.creditsSpent,
            organismID: detail.organismID?.nonEmpty ?? existing.organismID,
            createdAt: detail.createdAt ?? existing.createdAt,
            updatedAt: detail.updatedAt ?? detail.completedAt ?? detail.submittedAt ?? syncedAt,
            lastSyncedAt: syncedAt,
            latestSubmissionID: latestSubmission?.submissionID ?? existing.latestSubmissionID,
            latestSubmissionAt: latestSubmission?.submittedAt ?? existing.latestSubmissionAt,
            finalAssetID: detail.finalAssetID?.nonEmpty ?? latestSubmission?.assetID?.nonEmpty ?? existing.finalAssetID,
            finalAssetURL: detail.finalAssetURL?.nonEmpty ?? latestSubmission?.assetURL?.nonEmpty ?? existing.finalAssetURL,
            lastRatedAt: existing.lastRatedAt,
            lastRating: existing.lastRating
        )
    }

    private func upsertTrackedOrder(_ order: TrackedServiceOrder) {
        if let index = trackedOrders.firstIndex(where: { $0.taskID == order.taskID }) {
            trackedOrders[index] = order
        } else {
            trackedOrders.insert(order, at: 0)
        }
        trackedOrders.sort(by: Self.sortOrders(lhs:rhs:))
        selectedOrderTaskID = order.taskID
        persistTrackedOrders()
    }

    private func updateTrackedOrder(for taskID: String, transform: (TrackedServiceOrder?) -> TrackedServiceOrder) {
        let existingIndex = trackedOrders.firstIndex(where: { $0.taskID == taskID })
        let updated = transform(existingIndex.map { trackedOrders[$0] })
        if let existingIndex {
            trackedOrders[existingIndex] = updated
        } else {
            trackedOrders.insert(updated, at: 0)
        }
        trackedOrders.sort(by: Self.sortOrders(lhs:rhs:))
        persistTrackedOrders()
    }

    private func persistTrackedOrders() {
        do {
            try orderWorkspaceStore.saveTrackedOrders(trackedOrders.sorted(by: Self.sortOrders(lhs:rhs:)))
        } catch {
            orderLoadErrorMessage = error.localizedDescription
        }
    }

    private func persistLiveNodes() {
        do {
            try nodeWorkspaceStore.saveNodes(nodes.filter { $0.isSampleData == false })
        } catch {
            nodeConnectionErrorMessage = error.localizedDescription
        }
    }

    private static func loadFollowedBountyTaskIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: followedBountyTaskIDsKey) ?? [])
    }

    private func persistFollowedBountyTaskIDs() {
        UserDefaults.standard.set(
            Array(followedBountyTaskIDs).sorted(),
            forKey: Self.followedBountyTaskIDsKey
        )
    }

    private static func loadBountyAnswerDrafts() -> [String: BountyAnswerDraft] {
        guard let data = UserDefaults.standard.data(forKey: bountyAnswerDraftsKey),
              let drafts = try? JSONDecoder().decode([String: BountyAnswerDraft].self, from: data) else {
            return [:]
        }
        return drafts
    }

    private static func saveBountyAnswerDrafts(_ drafts: [String: BountyAnswerDraft]) {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        UserDefaults.standard.set(data, forKey: bountyAnswerDraftsKey)
    }

    private static func loadBountyAutopilotRuns() -> [BountyAutopilotRun] {
        guard let data = UserDefaults.standard.data(forKey: bountyAutopilotRunsKey),
              let runs = try? JSONDecoder().decode([BountyAutopilotRun].self, from: data) else {
            return []
        }
        return runs
    }

    private static func saveBountyAutopilotRuns(_ runs: [BountyAutopilotRun]) {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        UserDefaults.standard.set(data, forKey: bountyAutopilotRunsKey)
    }

    private func orderAcceptanceKey(taskID: String, submissionID: String) -> String {
        "\(taskID)::\(submissionID)"
    }

    private func resetRemoteSkillRollbackTargetVersion(using currentVersion: String?) {
        let currentVersion = currentVersion?.nonEmpty
        let eligibleVersions = remoteSkillVersions.filter { version in
            guard let currentVersion else { return true }
            return version.version != currentVersion
        }

        if let existingTarget = remoteSkillRollbackTargetVersion?.nonEmpty,
           eligibleVersions.contains(where: { $0.version == existingTarget }) {
            return
        }

        remoteSkillRollbackTargetVersion = eligibleVersions.first?.version
    }

    func isCurrentRemoteSkillVersion(_ version: RemoteSkillVersion) -> Bool {
        version.version == selectedRemoteSkillCurrentVersion?.nonEmpty
    }

    func isDeletingRemoteSkillVersion(_ version: RemoteSkillVersion) -> Bool {
        guard let skill = selectedRemoteSkillSummary else { return false }
        return activeRemoteSkillVersionDeleteKey == remoteSkillVersionMutationKey(skillID: skill.skillId, version: version.version)
    }

    func canDeleteRemoteSkillVersion(_ version: RemoteSkillVersion) -> Bool {
        skillWorkspaceMode == .store
            && activeRemoteSkillVisibilityID == nil
            && activeRemoteSkillRollbackID == nil
            && activeRemoteSkillVersionDeleteKey == nil
            && activeRemoteSkillDeleteID == nil
            && selectedRemoteSkillVersionDeletePrerequisiteBlocker(for: version) == nil
    }

    private func normalizedHubBaseURL(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func prependEvents(_ newEvents: [NodeEvent], to node: inout NodeRecord) {
        node.recentEvents = Array((newEvents + node.recentEvents).prefix(12))
    }

    private static func nodeConnectionFailureMessage(_ error: Error) -> String {
        if let clientError = error as? EvoMapClientError,
           case .decodingFailed(let diagnostic) = clientError {
            return AppLocalization.string(
                "node_connection.error.unreadable_response",
                fallback: "EvoMap returned a response this app could not read. This is not local data loss. Diagnostic: %@",
                diagnostic
            )
        }
        return error.localizedDescription
    }

    private static func makeTaskPreview(from task: EvoMapTaskSummary) -> NodeTaskPreview {
        let title = task.title?.nonEmpty ?? task.summary?.nonEmpty ?? task.taskID ?? "Unnamed task"
        return NodeTaskPreview(
            id: task.taskID ?? UUID().uuidString,
            title: title,
            summary: task.summary,
            rewardCredits: task.bountyCredits ?? task.rewardCredits,
            domain: task.domain,
            kind: task.kind
        )
    }

    private static func makeOverdueTaskPreview(from task: EvoMapOverdueTask) -> NodeOverdueTask {
        NodeOverdueTask(
            id: task.taskID ?? UUID().uuidString,
            title: task.title?.nonEmpty ?? task.taskID ?? "Unnamed task",
            commitmentDeadline: task.commitmentDeadline,
            overdueMinutes: task.overdueMinutes
        )
    }

    private static func makePendingEventPreview(from event: EvoMapPendingEvent) -> NodePendingEventPreview {
        let summary = event.payload?.compactDescription.nonEmpty ?? "No payload details were returned."
        return NodePendingEventPreview(
            id: event.eventID ?? UUID().uuidString,
            type: event.type?.nonEmpty ?? "event",
            createdAt: event.createdAt,
            priority: event.priority,
            summary: summary
        )
    }

    private static func makePeerPreview(from peer: EvoMapPeer) -> NodePeerPreview {
        NodePeerPreview(
            id: peer.nodeID ?? UUID().uuidString,
            alias: peer.alias,
            online: peer.online ?? false,
            reputation: peer.reputation,
            workload: peer.workload
        )
    }

    private static func makeAccountabilitySnapshot(from accountability: EvoMapAccountability?) -> NodeAccountabilitySnapshot? {
        guard let accountability else { return nil }
        let patterns = (accountability.topPatterns ?? []).map { pattern in
            NodeErrorPatternPreview(
                id: pattern.fingerprint ?? UUID().uuidString,
                count: pattern.count ?? 0,
                escalation: pattern.escalation,
                reason: pattern.reason
            )
        }
        return NodeAccountabilitySnapshot(
            reputationPenalty: accountability.reputationPenalty ?? 0,
            quarantineStrikes: accountability.quarantineStrikes ?? 0,
            publishCooldownUntil: accountability.publishCooldownUntil,
            recommendation: accountability.recommendation,
            topPatterns: patterns
        )
    }

    private static func makeSkillStoreStatus(from skillStore: EvoMapSkillStoreStatus?) -> NodeSkillStoreStatus? {
        guard let skillStore else { return nil }
        return NodeSkillStoreStatus(
            eligible: skillStore.eligible ?? false,
            publishedSkillCount: skillStore.publishedSkills ?? 0,
            publishEndpoint: skillStore.publishEndpoint,
            hint: skillStore.hint
        )
    }

    private static func makeSenderID() -> String {
        let suffix = UUID().uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
        return "node_\(suffix)"
    }

    private static func makeEnvironmentFingerprint() -> [String: String] {
        [
            "app_version": AppBuildMetadata.version,
            "build": AppBuildMetadata.build,
            "platform": "macOS",
            "arch": machineArchitecture(),
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
        ]
    }

    private static func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partialResult.append(String(UnicodeScalar(UInt8(value))))
        }
        return identifier.nonEmpty ?? "unknown"
    }

    private static func formattedHeartbeatInterval(milliseconds: Int) -> String {
        let seconds = max(milliseconds / 1000, 1)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = max(seconds / 60, 1)
        return "\(minutes)m"
    }

    private static func relativeLabel(for date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private static func sortOrders(lhs: TrackedServiceOrder, rhs: TrackedServiceOrder) -> Bool {
        let lhsDate = lhs.updatedAt > lhs.createdAt ? lhs.updatedAt : lhs.createdAt
        let rhsDate = rhs.updatedAt > rhs.createdAt ? rhs.updatedAt : rhs.createdAt
        if lhsDate == rhsDate {
            return lhs.taskID > rhs.taskID
        }
        return lhsDate > rhsDate
    }
}

private enum SkillStoreMutationAction {
    case publish
    case update

    var defaultMessage: String {
        switch self {
        case .publish:
            return "Skill submitted to the EvoMap Skill Store."
        case .update:
            return "Skill Store version updated successfully."
        }
    }

    var eventTitle: String {
        switch self {
        case .publish:
            return "Skill publish submitted"
        case .update:
            return "Skill update submitted"
        }
    }
}

private enum SampleData {
    static let nodes: [NodeRecord] = [
        NodeRecord(
            id: UUID(),
            name: AppLocalization.phrase("Primary Mac Node"),
            senderID: "node_demo_primary",
            apiBaseURL: "https://evomap.ai",
            environment: .production,
            modelName: "gpt-5",
            geneCount: 12,
            capsuleCount: 4,
            claimState: .claimed,
            heartbeat: .healthy,
            lastSeen: Date().addingTimeInterval(-180),
            onlineWorkers: 3,
            creditBalance: 0,
            claimCode: nil,
            claimURL: nil,
            referralCode: "node_demo_primary",
            survivalStatus: "alive",
            nodeSecretStored: false,
            lastErrorMessage: nil,
            notes: "Main publishing node used for skill management and authenticated node polling.",
            recentEvents: [
                NodeEvent(
                    timestamp: Date().addingTimeInterval(-180),
                    title: "Heartbeat healthy",
                    detail: "Worker heartbeat reported three active workers and two dispatch items.",
                    titleKey: "sample.event.heartbeat_healthy.title",
                    detailKey: "sample.event.heartbeat_healthy.detail"
                ),
                NodeEvent(
                    timestamp: Date().addingTimeInterval(-2400),
                    title: "Skill publish succeeded",
                    detail: "Published `commit-and-push` version 1.4.2.",
                    titleKey: "sample.event.skill_publish_succeeded.title",
                    detailKey: "sample.event.skill_publish_succeeded.detail"
                ),
            ],
            recommendedHeartbeatIntervalMS: 300_000,
            heartbeatEndpoint: "https://evomap.ai/a2a/heartbeat",
            heartbeatSnapshot: NodeHeartbeatSnapshot(
                nextHeartbeatAt: Date().addingTimeInterval(240),
                availableTasks: [
                    NodeTaskPreview(
                        id: "task-publish-1",
                        title: "Review skill publish payload",
                        summary: "Confirm the next workflow skill revision before release.",
                        rewardCredits: 40,
                        domain: "skills",
                        kind: "review"
                    )
                ],
                availableWork: [
                    NodeTaskPreview(
                        id: "task-poll-1",
                        title: "Poll service orders",
                        summary: "Check for newly matched service requests from the hub.",
                        rewardCredits: 25,
                        domain: "services",
                        kind: "poll"
                    )
                ],
                overdueTasks: [],
                pendingEvents: [
                    NodePendingEventPreview(
                        id: "evt-claim-1",
                        type: "service_assignment",
                        createdAt: Date().addingTimeInterval(-140),
                        priority: 2,
                        summary: "keys: order_id, service_id"
                    )
                ],
                peers: [
                    NodePeerPreview(
                        id: "peer-alpha",
                        alias: "Tokyo Skill Router",
                        online: true,
                        reputation: 0.97,
                        workload: 1
                    ),
                    NodePeerPreview(
                        id: "peer-beta",
                        alias: "JP Lexicon Worker",
                        online: true,
                        reputation: 0.91,
                        workload: 2
                    ),
                ],
                accountability: NodeAccountabilitySnapshot(
                    reputationPenalty: 0,
                    quarantineStrikes: 0,
                    publishCooldownUntil: nil,
                    recommendation: nil,
                    topPatterns: []
                ),
                skillStore: NodeSkillStoreStatus(
                    eligible: true,
                    publishedSkillCount: 3,
                    publishEndpoint: "https://evomap.ai/a2a/skill/store/publish",
                    hint: "This node is ready to publish or update skills."
                )
            ),
            isSampleData: true
        ),
        NodeRecord(
            id: UUID(),
            name: "Staging Automation Node",
            senderID: "node_staging_automation",
            apiBaseURL: "https://staging.evomap.ai",
            environment: .staging,
            modelName: "claude-sonnet-4",
            geneCount: 6,
            capsuleCount: 2,
            claimState: .pending,
            heartbeat: .warning,
            lastSeen: Date().addingTimeInterval(-3600),
            onlineWorkers: 1,
            creditBalance: 0,
            claimCode: nil,
            claimURL: nil,
            referralCode: "node_staging_automation",
            survivalStatus: "alive",
            nodeSecretStored: false,
            lastErrorMessage: nil,
            notes: "Waiting for account claim confirmation before service publishing.",
            recentEvents: [
                NodeEvent(
                    timestamp: Date().addingTimeInterval(-3600),
                    title: "Claim pending",
                    detail: "Node secret issued; account claim is still incomplete.",
                    titleKey: "sample.event.claim_pending.title",
                    detailKey: "sample.event.claim_pending.detail"
                ),
                NodeEvent(
                    timestamp: Date().addingTimeInterval(-7200),
                    title: "Hello handshake complete",
                    detail: "Received `node_secret` from `/a2a/hello`.",
                    titleKey: "sample.event.hello_complete.title",
                    detailKey: "sample.event.hello_complete.detail"
                ),
            ],
            recommendedHeartbeatIntervalMS: 300_000,
            heartbeatEndpoint: "https://staging.evomap.ai/a2a/heartbeat",
            heartbeatSnapshot: NodeHeartbeatSnapshot(
                nextHeartbeatAt: Date().addingTimeInterval(-120),
                availableTasks: [],
                availableWork: [],
                overdueTasks: [
                    NodeOverdueTask(
                        id: "overdue-staging-1",
                        title: "Acknowledge staging order",
                        commitmentDeadline: Date().addingTimeInterval(-900),
                        overdueMinutes: 15
                    )
                ],
                pendingEvents: [
                    NodePendingEventPreview(
                        id: "evt-staging-1",
                        type: "claim_reminder",
                        createdAt: Date().addingTimeInterval(-2400),
                        priority: 1,
                        summary: "keys: claim_code, claim_url"
                    )
                ],
                peers: [
                    NodePeerPreview(
                        id: "peer-staging-1",
                        alias: "Staging Hub",
                        online: true,
                        reputation: 0.74,
                        workload: 3
                    )
                ],
                accountability: NodeAccountabilitySnapshot(
                    reputationPenalty: 1,
                    quarantineStrikes: 0,
                    publishCooldownUntil: Date().addingTimeInterval(3600),
                    recommendation: "Claim the node and clear the overdue staging task before the next publish.",
                    topPatterns: [
                        NodeErrorPatternPreview(
                            id: "claim-missing",
                            count: 2,
                            escalation: "warn",
                            reason: "Account claim has not been completed."
                        )
                    ]
                ),
                skillStore: NodeSkillStoreStatus(
                    eligible: false,
                    publishedSkillCount: 0,
                    publishEndpoint: "https://staging.evomap.ai/a2a/skill/store/publish",
                    hint: "Claim the node first; staging publish remains blocked."
                )
            ),
            isSampleData: true
        ),
        NodeRecord(
            id: UUID(),
            name: "Archive Worker",
            senderID: "node_archive_worker",
            apiBaseURL: "https://evomap.ai",
            environment: .production,
            modelName: "gpt-4.1",
            geneCount: 0,
            capsuleCount: 0,
            claimState: .unclaimed,
            heartbeat: .offline,
            lastSeen: Date().addingTimeInterval(-86_400),
            onlineWorkers: 0,
            creditBalance: 0,
            claimCode: nil,
            claimURL: nil,
            referralCode: nil,
            survivalStatus: "dormant",
            nodeSecretStored: false,
            lastErrorMessage: "No node_secret found in the local Keychain.",
            notes: "Kept for reference while the new macOS console replaces older scripts.",
            recentEvents: [
                NodeEvent(
                    timestamp: Date().addingTimeInterval(-86_400),
                    title: "Heartbeat missing",
                    detail: "No worker heartbeat has been received for 24 hours.",
                    titleKey: "sample.event.heartbeat_missing.title",
                    detailKey: "sample.event.heartbeat_missing.detail"
                )
            ],
            recommendedHeartbeatIntervalMS: 300_000,
            heartbeatEndpoint: "https://evomap.ai/a2a/heartbeat",
            heartbeatSnapshot: nil,
            isSampleData: true
        ),
    ]

    static let skills: [SkillRecord] = [
        SkillRecord(
            id: UUID(),
            skillID: "skill_commit_and_push",
            name: "commit-and-push",
            summary: "Safely inspect, stage, commit, push, and optionally open a draft PR.",
            category: .optimize,
            tags: ["git", "github", "publish"],
            state: .published,
            localCharacterCount: 6371,
            bundledFiles: [
                SkillBundledFile(
                    id: "agents/openai.yaml",
                    relativePath: "agents/openai.yaml",
                    characterCount: 224,
                    content: "model: gpt-5.4\nreasoning_effort: medium\n",
                    isIncluded: true,
                    note: nil
                )
            ],
            remoteVersion: "1.4.2",
            updatedAt: Date().addingTimeInterval(-2400),
            sourcePath: "examples/skills/commit-and-push/SKILL.md",
            content: """
            ---
            name: commit-and-push
            description: Safely inspect, stage, commit, push, and optionally open a draft PR.
            ---

            # commit-and-push

            ## Trigger Signals
            - publish the current worktree
            - open a draft pull request

            ## Constraints
            - never stage unrelated changes
            - never rewrite history unless explicitly asked

            ## Validation
            - inspect git status before staging
            - report branch, commit SHA, and push target
            """,
            validationIssues: [],
            remoteStatus: "approved",
            lastPublishedAt: Date().addingTimeInterval(-2400),
            lastPublishedBySenderID: "node_demo_primary",
            lastPublishMessage: "Latest Skill Store version is live.",
            isSampleData: true
        ),
        SkillRecord(
            id: UUID(),
            skillID: "skill_japanese_learning_video_pipeline",
            name: "japanese-learning-video-pipeline",
            summary: "Generate a local-first Japanese lesson video workflow with draft, TTS, and render stages.",
            category: .innovate,
            tags: ["japanese", "video", "tts"],
            state: .changed,
            localCharacterCount: 5206,
            bundledFiles: [
                SkillBundledFile(
                    id: "references/pipeline.md",
                    relativePath: "references/pipeline.md",
                    characterCount: 1180,
                    content: "# pipeline\nUse the local render flow.\n",
                    isIncluded: true,
                    note: nil
                ),
                SkillBundledFile(
                    id: "scripts/render_video.py",
                    relativePath: "scripts/render_video.py",
                    characterCount: 4820,
                    content: "print('render video')\n",
                    isIncluded: true,
                    note: nil
                )
            ],
            remoteVersion: "0.9.0",
            updatedAt: Date().addingTimeInterval(-9600),
            sourcePath: "examples/skills/japanese-learning-video-pipeline/SKILL.md",
            content: """
            ---
            name: japanese-learning-video-pipeline
            description: Build a local-first Japanese lesson video from topic to rendered output.
            ---

            # japanese-learning-video-pipeline

            ## Workflow
            1. generate the outline
            2. create the voice plan
            3. render the local video

            ## Constraints
            - keep the lesson accurate
            - keep the pacing short and reusable

            ## Validation
            - confirm source facts
            - export a local MP4
            """,
            validationIssues: [
                SkillValidationIssue(
                    severity: .info,
                    title: "Remote update pending",
                    detail: "This local draft differs from the published `0.9.0` version."
                )
            ],
            remoteStatus: "approved",
            lastPublishedAt: Date().addingTimeInterval(-86_400),
            lastPublishedBySenderID: "node_demo_primary",
            lastPublishMessage: "Published version `0.9.0` is still live.",
            isSampleData: true
        ),
        SkillRecord(
            id: UUID(),
            skillID: "skill_evomap_console_layout",
            name: "evomap-console-layout",
            summary: "Internal draft for the EvoMap Console product and layout workflow.",
            category: .innovate,
            tags: ["macos", "swiftui", "console"],
            state: .draft,
            localCharacterCount: 2810,
            bundledFiles: [],
            remoteVersion: nil,
            updatedAt: Date().addingTimeInterval(-5400),
            sourcePath: nil,
            content: """
            ---
            name: evomap-console-layout
            description: Design the native macOS operator workflow for EvoMap management.
            ---

            # evomap-console-layout

            ## Trigger Signals
            - design the app shell
            - review the navigation model

            ## Workflow
            - map the operator tasks
            - lock the macOS layout
            - validate the screens before coding
            """,
            validationIssues: [
                SkillValidationIssue(
                    severity: .warning,
                    title: "Thin validation guidance",
                    detail: "Add a dedicated validation section before this draft is publishable."
                )
            ],
            isSampleData: true
        ),
    ]
}

private extension NodeHeartbeatSnapshot {
    static var empty: NodeHeartbeatSnapshot {
        NodeHeartbeatSnapshot(
            nextHeartbeatAt: nil,
            availableTasks: [],
            availableWork: [],
            overdueTasks: [],
            pendingEvents: [],
            peers: [],
            accountability: nil,
            skillStore: nil
        )
    }
}

private extension String {
    var normalizedSearchKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
