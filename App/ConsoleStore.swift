import AppKit
import Foundation

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
    @Published private(set) var activeBountyClaimTaskID: String?
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
    @Published var selectedBountyTaskID: String?
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
    private var remoteSkillSearchTask: Task<Void, Never>?
    private var serviceSearchTask: Task<Void, Never>?

    init(
        nodes: [NodeRecord] = SampleData.nodes,
        skills: [SkillRecord] = SampleData.skills,
        client: EvoMapClientProtocol = EvoMapClient(),
        nodeSecretStore: NodeSecretStoring = KeychainNodeSecretStore(),
        skillImportService: SkillImportService = SkillImportService(),
        skillWorkspaceStore: SkillWorkspacePersisting = LocalSkillWorkspaceStore(),
        orderWorkspaceStore: OrderWorkspacePersisting = LocalOrderWorkspaceStore()
    ) {
        self.client = client
        self.nodeSecretStore = nodeSecretStore
        self.skillImportService = skillImportService
        self.skillWorkspaceStore = skillWorkspaceStore
        self.orderWorkspaceStore = orderWorkspaceStore
        self.nodes = nodes
        self.skills = skills
        self.selectedNodeID = nodes.first?.id
        self.selectedSkillID = skills.first?.id

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

    var currentSectionTitle: String {
        selectedSection.title
    }

    var searchPrompt: String {
        selectedSection.searchPrompt
    }

    var filteredNodes: [NodeRecord] {
        guard !searchText.isEmpty else { return nodes }
        let query = searchText.normalizedSearchKey
        return nodes.filter {
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
        let source = filteredNodes.isEmpty ? nodes : filteredNodes
        guard let selectedNodeID else { return source.first }
        return source.first(where: { $0.id == selectedNodeID }) ?? nodes.first(where: { $0.id == selectedNodeID })
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
        guard let selectedBountyTaskID else { return bountyTasks.first }
        return bountyTasks.first(where: { $0.id == selectedBountyTaskID }) ?? bountyTasks.first
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
        if storedNodeSecretCount == 0 {
            return AppLocalization.string("primary.connect_node", fallback: "Connect Node")
        }
        if claimedNodeCount == 0 {
            return AppLocalization.string("primary.open_claim", fallback: "Open Claim")
        }
        return AppLocalization.string("primary.open_bounties", fallback: "Open Bounties")
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
                id: "connect",
                title: AppLocalization.string("credits.step.connect.title", fallback: "Connect local node"),
                detail: AppLocalization.string(
                    "credits.step.connect.detail",
                    fallback: "Use `/a2a/hello`; this stores node_secret in Keychain and unlocks authenticated node actions."
                ),
                systemImage: "server.rack",
                tintName: storedNodeSecretCount > 0 ? "green" : "orange",
                isComplete: storedNodeSecretCount > 0
            ),
            CreditSprintStep(
                id: "claim",
                title: AppLocalization.string("credits.step.claim.title", fallback: "Claim the node"),
                detail: AppLocalization.string(
                    "credits.step.claim.detail",
                    fallback: "Open the claim URL so credits and future earnings attach to your EvoMap account."
                ),
                systemImage: "link.badge.plus",
                tintName: claimedNodeCount > 0 ? "green" : "orange",
                isComplete: claimedNodeCount > 0
            ),
            CreditSprintStep(
                id: "bounties",
                title: AppLocalization.string("credits.step.bounties.title", fallback: "Work bounty questions"),
                detail: AppLocalization.string(
                    "credits.step.bounties.detail",
                    fallback: "Filter for bounty-backed questions, then start with language, education, and content-structure tasks."
                ),
                systemImage: "target",
                tintName: claimedNodeCount > 0 ? "blue" : "secondary",
                isComplete: false
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

    var bestCreditNodeClaimURL: URL? {
        let node = selectedOrFirstCreditNode
        guard let claimURL = node?.claimURL else { return nil }
        return URL(string: claimURL)
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
            selectedNodeID = selectedNodeID ?? nodes.first?.id
        case .credits:
            selectedNodeID = selectedNodeID ?? nodes.first?.id
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
        if storedNodeSecretCount == 0 {
            prepareNodeConnection()
            return
        }

        if claimedNodeCount == 0, let claimURL = bestCreditNodeClaimURL {
            NSWorkspace.shared.open(claimURL)
            return
        }

        NSWorkspace.shared.open(evoMapBountiesURL)
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
        guard !isLoadingBountyTasks else { return }
        guard let node = selectedOrFirstCreditNode else {
            bountyTaskErrorMessage = AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
            return
        }
        guard let nodeSecret = loadStoredSecret(for: node.senderID)?.nonEmpty else {
            bountyTaskErrorMessage = AppLocalization.string(
                "credits.bounty.blocker.no_secret",
                fallback: "Run /a2a/hello first so the node_secret is stored in Keychain."
            )
            return
        }

        isLoadingBountyTasks = true
        bountyTaskErrorMessage = nil
        bountyTaskMessage = nil
        defer { isLoadingBountyTasks = false }

        do {
            let response = try await client.listBountyTasks(
                request: EvoMapBountyTaskListRequest(
                    baseURL: node.apiBaseURL,
                    nodeSecret: nodeSecret,
                    minBounty: 1,
                    limit: 25
                )
            )
            bountyTasks = response.tasks
            selectedBountyTaskID = bountyTasks.first(where: { $0.id == selectedBountyTaskID })?.id ?? bountyTasks.first?.id
            bountyTaskMessage = response.message?.nonEmpty ?? AppLocalization.string(
                "credits.bounty.message.loaded",
                fallback: "Loaded %d bounty task(s).",
                bountyTasks.count
            )
        } catch {
            bountyTaskErrorMessage = error.localizedDescription
        }
    }

    func claimBountyTask(_ task: EvoMapBountyTask?) async {
        guard activeBountyClaimTaskID == nil else { return }
        guard let task else { return }
        guard let node = selectedOrFirstCreditNode else {
            bountyTaskErrorMessage = AppLocalization.string("credits.bounty.blocker.no_node", fallback: "Connect a real node first.")
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
            let response = try await client.claimBountyTask(
                request: EvoMapBountyTaskClaimRequest(
                    baseURL: node.apiBaseURL,
                    nodeSecret: nodeSecret,
                    payload: EvoMapBountyTaskClaimPayload(
                        senderID: node.senderID,
                        taskID: task.taskID
                    )
                )
            )
            bountyTaskMessage = response.message?.nonEmpty ?? AppLocalization.string(
                "credits.bounty.message.claimed",
                fallback: "Claimed task %@.",
                response.taskID ?? task.taskID
            )
            selectedBountyTaskID = task.id
        } catch {
            bountyTaskErrorMessage = error.localizedDescription
        }
    }

    func canClaimBountyTask(_ task: EvoMapBountyTask?) -> Bool {
        task != nil && activeBountyClaimTaskID == nil && bountyTaskPrerequisiteBlocker == nil
    }

    func prepareNodeConnection() {
        let selectedNode = selectedNode
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
            nodeConnectionErrorMessage = error.localizedDescription
        }
    }

    func refreshSelectedNodeHeartbeat() async {
        guard !isRefreshingNodeHeartbeat else { return }
        guard let selectedNodeID else {
            lastRefreshAt = Date()
            return
        }

        guard let node = nodes.first(where: { $0.id == selectedNodeID }) else {
            lastRefreshAt = Date()
            return
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
            applyHeartbeatResponse(response, for: node.id)
        } catch {
            applyHeartbeatFailure(message: error.localizedDescription, for: node.id, markOffline: true)
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
        node.heartbeat = node.claimState == .pending ? .warning : .healthy
        node.lastSeen = Date()
        node.creditBalance = response.creditBalance ?? node.creditBalance
        node.claimCode = response.claimCode
        node.claimURL = response.claimURL
        node.referralCode = response.referralCode
        node.survivalStatus = response.survivalStatus
        node.nodeSecretStored = secretSaved || hasStoredSecret(for: senderID)
        node.recommendedHeartbeatIntervalMS = response.heartbeatIntervalMS
        node.heartbeatEndpoint = response.heartbeatEndpoint
        if response.claimURL != nil || response.claimCode != nil {
            node.claimState = node.claimState == .claimed ? .claimed : .pending
        }
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

    private func makeHelloNotes(for node: NodeRecord, response: EvoMapHelloResponse) -> String {
        var parts = ["Model: \(node.modelName)."]
        parts.append(node.nodeSecretStored ? "Bearer auth is stored in Keychain." : "Save the returned node_secret locally before sending heartbeat.")
        if let claimURL = response.claimURL, !claimURL.isEmpty {
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

private extension String {
    var normalizedSearchKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
