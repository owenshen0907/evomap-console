import Foundation

enum ConsoleSection: String, CaseIterable, Identifiable {
    case overview
    case nodes
    case credits
    case bounties
    case skills
    case services
    case orders
    case graph
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return AppLocalization.string("section.overview", fallback: "Overview")
        case .nodes:
            return AppLocalization.string("section.nodes", fallback: "Nodes")
        case .credits:
            return AppLocalization.string("section.credits", fallback: "Credits")
        case .bounties:
            return AppLocalization.string("section.bounties", fallback: "Bounties")
        case .skills:
            return AppLocalization.string("section.skills", fallback: "Skills")
        case .services:
            return AppLocalization.string("section.services", fallback: "Services")
        case .orders:
            return AppLocalization.string("section.orders", fallback: "Orders")
        case .graph:
            return AppLocalization.string("section.graph", fallback: "Graph")
        case .activity:
            return AppLocalization.string("section.activity", fallback: "Activity")
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.3.group"
        case .nodes:
            return "server.rack"
        case .credits:
            return "creditcard.and.123"
        case .bounties:
            return "target"
        case .skills:
            return "sparkles.rectangle.stack"
        case .services:
            return "shippingbox"
        case .orders:
            return "list.bullet.clipboard"
        case .graph:
            return "point.3.connected.trianglepath.dotted"
        case .activity:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }

    var isAvailableInV1: Bool {
        switch self {
        case .overview, .nodes, .credits, .bounties, .skills, .services, .orders, .graph:
            return true
        case .activity:
            return false
        }
    }

    var badgeTitle: String? {
        isAvailableInV1 ? nil : AppLocalization.string("badge.later", fallback: "Later")
    }

    var searchPrompt: String {
        switch self {
        case .overview:
            return AppLocalization.string("search.overview", fallback: "Search recent activity")
        case .nodes:
            return AppLocalization.string("search.nodes", fallback: "Search nodes")
        case .credits:
            return AppLocalization.string("search.credits", fallback: "Search credit tasks")
        case .bounties:
            return AppLocalization.string("search.bounties", fallback: "Search bounty tasks")
        case .skills:
            return AppLocalization.string("search.skills", fallback: "Search skills")
        case .services:
            return AppLocalization.string("search.services", fallback: "Search services")
        case .orders:
            return AppLocalization.string("search.orders", fallback: "Search orders")
        case .graph:
            return AppLocalization.string("search.graph", fallback: "Search graph resources")
        case .activity:
            return AppLocalization.string("search.activity", fallback: "Search activity")
        }
    }
}

enum GraphWorkspaceMode: String, CaseIterable, Identifiable {
    case myGraph
    case search
    case manage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myGraph:
            return AppLocalization.string("graph.workspace.my_graph", fallback: "My Graph")
        case .search:
            return AppLocalization.string("graph.workspace.search", fallback: "Search")
        case .manage:
            return AppLocalization.string("graph.workspace.manage", fallback: "Manage")
        }
    }
}

enum KnowledgeGraphEntityType: String, CaseIterable, Identifiable {
    case concept
    case tool
    case technique
    case pattern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concept:
            return AppLocalization.string("kg.entity_type.concept", fallback: "Concept")
        case .tool:
            return AppLocalization.string("kg.entity_type.tool", fallback: "Tool")
        case .technique:
            return AppLocalization.string("kg.entity_type.technique", fallback: "Technique")
        case .pattern:
            return AppLocalization.string("kg.entity_type.pattern", fallback: "Pattern")
        }
    }
}

enum KnowledgeGraphRelationType: String, CaseIterable, Identifiable {
    case uses
    case solves
    case requires
    case improves
    case contradicts
    case relatedTo = "related_to"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uses:
            return AppLocalization.string("kg.relation.uses", fallback: "Uses")
        case .solves:
            return AppLocalization.string("kg.relation.solves", fallback: "Solves")
        case .requires:
            return AppLocalization.string("kg.relation.requires", fallback: "Requires")
        case .improves:
            return AppLocalization.string("kg.relation.improves", fallback: "Improves")
        case .contradicts:
            return AppLocalization.string("kg.relation.contradicts", fallback: "Contradicts")
        case .relatedTo:
            return AppLocalization.string("kg.relation.related_to", fallback: "Related To")
        }
    }
}

struct KnowledgeGraphEntityDraft: Equatable {
    var name: String
    var type: KnowledgeGraphEntityType
    var description: String

    static let empty = KnowledgeGraphEntityDraft(
        name: "",
        type: .concept,
        description: ""
    )
}

struct KnowledgeGraphRelationshipDraft: Equatable {
    var sourceName: String
    var relationType: KnowledgeGraphRelationType
    var targetName: String

    static let empty = KnowledgeGraphRelationshipDraft(
        sourceName: "",
        relationType: .relatedTo,
        targetName: ""
    )
}

struct KnowledgeGraphPropertyLine: Identifiable, Hashable {
    let key: String
    let value: String

    var id: String { key }
}

struct KnowledgeGraphStatusSnapshot: Decodable, Hashable {
    var planName: String?
    var accessStatus: String?
    var scopeGranted: Bool?
    var isEnabled: Bool?
    var queryCount: Int?
    var ingestCount: Int?
    var creditsUsed: Double?
    var queryPriceCredits: Double?
    var ingestPriceCredits: Double?
    var queryRateLimitPerMinute: Int?
    var ingestRateLimitPerMinute: Int?
    var properties: [KnowledgeGraphPropertyLine]

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "status"],
                ["status"],
                ["data", "usage"],
                ["usage"],
                ["data", "entitlement"],
                ["entitlement"],
                ["data", "pricing"],
                ["pricing"],
                ["data"],
            ]
        )

        planName = OrderDecodedPayload.string(
            keys: ["plan", "tier", "subscription", "entitlement", "package"],
            preferred: containers,
            recursive: containers
        )
        accessStatus = OrderDecodedPayload.string(
            keys: ["status", "access_status", "message", "note"],
            preferred: containers,
            recursive: containers
        )
        scopeGranted = KnowledgeGraphDecodingSupport.bool(
            keys: ["scope_granted", "has_scope", "granted", "allowed"],
            preferred: containers,
            recursive: containers
        )
        isEnabled = KnowledgeGraphDecodingSupport.bool(
            keys: ["enabled", "available", "can_use", "kg_enabled"],
            preferred: containers,
            recursive: containers
        )
        queryCount = OrderDecodedPayload.int(
            keys: ["query_count", "queries", "query_count_30d", "queries_30d"],
            preferred: containers,
            recursive: containers
        )
        ingestCount = OrderDecodedPayload.int(
            keys: ["ingest_count", "writes", "write_count", "ingest_count_30d", "writes_30d"],
            preferred: containers,
            recursive: containers
        )
        creditsUsed = KnowledgeGraphDecodingSupport.double(
            keys: ["credits_used", "used_credits", "credit_usage", "spent_credits"],
            preferred: containers,
            recursive: containers
        )
        queryPriceCredits = KnowledgeGraphDecodingSupport.double(
            keys: ["query_price", "query_price_credits", "query_cost", "query_credit_cost"],
            preferred: containers,
            recursive: containers
        )
        ingestPriceCredits = KnowledgeGraphDecodingSupport.double(
            keys: ["ingest_price", "ingest_price_credits", "write_cost", "ingest_credit_cost"],
            preferred: containers,
            recursive: containers
        )
        queryRateLimitPerMinute = OrderDecodedPayload.int(
            keys: ["query_rate_limit", "query_limit_per_minute", "query_rpm"],
            preferred: containers,
            recursive: containers
        )
        ingestRateLimitPerMinute = OrderDecodedPayload.int(
            keys: ["ingest_rate_limit", "write_limit_per_minute", "ingest_rpm"],
            preferred: containers,
            recursive: containers
        )
        properties = KnowledgeGraphDecodingSupport.properties(
            from: containers,
            excluding: [
                "plan", "tier", "subscription", "entitlement", "package",
                "status", "access_status", "message", "note",
                "scope_granted", "has_scope", "granted", "allowed",
                "enabled", "available", "can_use", "kg_enabled",
                "query_count", "queries", "query_count_30d", "queries_30d",
                "ingest_count", "writes", "write_count", "ingest_count_30d", "writes_30d",
                "credits_used", "used_credits", "credit_usage", "spent_credits",
                "query_price", "query_price_credits", "query_cost", "query_credit_cost",
                "ingest_price", "ingest_price_credits", "write_cost", "ingest_credit_cost",
                "query_rate_limit", "query_limit_per_minute", "query_rpm",
                "ingest_rate_limit", "write_limit_per_minute", "ingest_rpm",
            ]
        )
    }
}

struct KnowledgeGraphNode: Identifiable, Decodable, Hashable {
    var nodeID: String
    var name: String
    var type: String?
    var group: String?
    var description: String?
    var score: Double?
    var properties: [KnowledgeGraphPropertyLine]

    var id: String { nodeID }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "node"],
                ["node"],
                ["data", "entity"],
                ["entity"],
                ["data"],
            ]
        )

        let metadataContainers = OrderDecodedPayload.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["properties"]),
                    container.value(at: ["metadata"]),
                    container.value(at: ["attrs"]),
                ]
            }
        )

        nodeID = OrderDecodedPayload.string(
            keys: ["node_id", "entity_id", "asset_id", "id", "name", "title"],
            preferred: containers,
            recursive: containers
        ) ?? UUID().uuidString
        name = OrderDecodedPayload.string(
            keys: ["name", "title", "label"],
            preferred: containers,
            recursive: containers
        ) ?? nodeID
        type = OrderDecodedPayload.string(
            keys: ["type", "entity_type", "kind"],
            preferred: containers,
            recursive: containers
        )
        group = OrderDecodedPayload.string(
            keys: ["group", "category", "node_group", "bucket"],
            preferred: containers,
            recursive: containers
        )
        description = OrderDecodedPayload.string(
            keys: ["description", "summary", "detail", "content"],
            preferred: containers,
            recursive: containers
        )
        score = KnowledgeGraphDecodingSupport.double(
            keys: ["score", "confidence", "gdi", "rating"],
            preferred: containers,
            recursive: containers
        )
        properties = KnowledgeGraphDecodingSupport.properties(
            from: metadataContainers + containers,
            excluding: [
                "node_id", "entity_id", "asset_id", "id", "name", "title", "label",
                "type", "entity_type", "kind",
                "group", "category", "node_group", "bucket",
                "description", "summary", "detail", "content",
                "score", "confidence", "gdi", "rating",
                "properties", "metadata", "attrs",
            ]
        )
    }
}

struct KnowledgeGraphEdge: Identifiable, Decodable, Hashable {
    var edgeID: String
    var sourceID: String
    var targetID: String
    var sourceLabel: String?
    var targetLabel: String?
    var relation: String
    var properties: [KnowledgeGraphPropertyLine]

    var id: String { edgeID }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "edge"],
                ["edge"],
                ["data", "relationship"],
                ["relationship"],
                ["data", "relation"],
                ["relation"],
                ["data"],
            ]
        )

        let sourceContainers = OrderDecodedPayload.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["source"]),
                    container.value(at: ["from"]),
                    container.value(at: ["start"]),
                ]
            }
        )
        let targetContainers = OrderDecodedPayload.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["target"]),
                    container.value(at: ["to"]),
                    container.value(at: ["end"]),
                ]
            }
        )

        sourceID = OrderDecodedPayload.string(
            keys: ["source_id", "from_id", "start_id", "id"],
            preferred: containers + sourceContainers,
            recursive: containers + sourceContainers
        ) ?? "source"
        targetID = OrderDecodedPayload.string(
            keys: ["target_id", "to_id", "end_id", "id"],
            preferred: containers + targetContainers,
            recursive: containers + targetContainers
        ) ?? "target"
        relation = OrderDecodedPayload.string(
            keys: ["relation", "relationship", "type", "label"],
            preferred: containers,
            recursive: containers
        ) ?? "related_to"
        edgeID = OrderDecodedPayload.string(
            keys: ["edge_id", "relationship_id", "id"],
            preferred: containers,
            recursive: containers
        ) ?? "\(sourceID)-\(relation)-\(targetID)"
        sourceLabel = OrderDecodedPayload.string(
            keys: ["name", "title", "label"],
            preferred: sourceContainers,
            recursive: sourceContainers
        )
        targetLabel = OrderDecodedPayload.string(
            keys: ["name", "title", "label"],
            preferred: targetContainers,
            recursive: targetContainers
        )
        properties = KnowledgeGraphDecodingSupport.properties(
            from: containers,
            excluding: [
                "edge_id", "relationship_id", "id",
                "source_id", "from_id", "start_id",
                "target_id", "to_id", "end_id",
                "source", "from", "start", "target", "to", "end",
                "relation", "relationship", "type", "label",
            ]
        )
    }
}

struct KnowledgeGraphCluster: Identifiable, Decodable, Hashable {
    var clusterID: String
    var label: String?
    var memberIDs: [String]
    var memberCount: Int
    var summary: String?

    var id: String { clusterID }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "cluster"],
                ["cluster"],
                ["data"],
            ]
        )

        clusterID = OrderDecodedPayload.string(
            keys: ["id", "cluster_id"],
            preferred: containers,
            recursive: containers
        ) ?? UUID().uuidString
        label = OrderDecodedPayload.string(
            keys: ["label", "name", "title"],
            preferred: containers,
            recursive: containers
        )
        memberIDs = KnowledgeGraphDecodingSupport.stringArray(
            keys: ["members", "member_ids", "nodes"],
            preferred: containers,
            recursive: containers
        )
        memberCount = OrderDecodedPayload.int(
            keys: ["member_count", "count", "size"],
            preferred: containers,
            recursive: containers
        ) ?? memberIDs.count
        summary = OrderDecodedPayload.string(
            keys: ["summary", "description", "detail"],
            preferred: containers,
            recursive: containers
        )
    }
}

struct KnowledgeGraphSearchResult: Decodable, Hashable {
    var nodes: [KnowledgeGraphNode]
    var edges: [KnowledgeGraphEdge]
    var clusters: [KnowledgeGraphCluster]
    var recommendedSequence: [String]
    var resultCount: Int
    var properties: [KnowledgeGraphPropertyLine]

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "result"],
                ["result"],
                ["data"],
            ]
        )

        nodes = KnowledgeGraphDecodingSupport.decodeArray(
            of: KnowledgeGraphNode.self,
            from: containers,
            candidateKeys: ["nodes", "results", "items", "entities"]
        )
        edges = KnowledgeGraphDecodingSupport.decodeArray(
            of: KnowledgeGraphEdge.self,
            from: containers,
            candidateKeys: ["edges", "relationships", "relations", "links"]
        )
        clusters = KnowledgeGraphDecodingSupport.decodeArray(
            of: KnowledgeGraphCluster.self,
            from: containers,
            candidateKeys: ["clusters", "semantic_clusters"]
        )
        recommendedSequence = KnowledgeGraphDecodingSupport.stringArray(
            keys: ["recommended_sequence", "sequence", "execution_sequence"],
            preferred: containers,
            recursive: containers
        )
        resultCount = OrderDecodedPayload.int(
            keys: ["result_count", "total", "count"],
            preferred: containers,
            recursive: containers
        ) ?? nodes.count
        properties = KnowledgeGraphDecodingSupport.properties(
            from: containers,
            excluding: [
                "nodes", "results", "items", "entities",
                "edges", "relationships", "relations", "links",
                "clusters", "semantic_clusters",
                "recommended_sequence", "sequence", "execution_sequence",
                "result_count", "total", "count",
            ]
        )
    }
}

struct KnowledgeGraphSnapshot: Decodable, Hashable {
    var nodes: [KnowledgeGraphNode]
    var edges: [KnowledgeGraphEdge]
    var updatedAt: Date?
    var totalNodes: Int
    var totalEdges: Int
    var properties: [KnowledgeGraphPropertyLine]

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = KnowledgeGraphDecodingSupport.containers(
            from: root,
            preferredPaths: [
                ["data", "graph"],
                ["graph"],
                ["data", "my_graph"],
                ["my_graph"],
                ["data"],
            ]
        )

        nodes = KnowledgeGraphDecodingSupport.decodeArray(
            of: KnowledgeGraphNode.self,
            from: containers,
            candidateKeys: ["nodes", "entities", "items"]
        )
        edges = KnowledgeGraphDecodingSupport.decodeArray(
            of: KnowledgeGraphEdge.self,
            from: containers,
            candidateKeys: ["edges", "relationships", "relations", "links"]
        )
        updatedAt = OrderDecodedPayload.date(
            keys: ["updated_at", "refreshed_at", "generated_at"],
            preferred: containers,
            recursive: containers
        )
        totalNodes = OrderDecodedPayload.int(
            keys: ["total_nodes", "node_count", "count"],
            preferred: containers,
            recursive: containers
        ) ?? nodes.count
        totalEdges = OrderDecodedPayload.int(
            keys: ["total_edges", "edge_count", "relationship_count", "relation_count"],
            preferred: containers,
            recursive: containers
        ) ?? edges.count
        properties = KnowledgeGraphDecodingSupport.properties(
            from: containers,
            excluding: [
                "nodes", "entities", "items",
                "edges", "relationships", "relations", "links",
                "updated_at", "refreshed_at", "generated_at",
                "total_nodes", "node_count", "count",
                "total_edges", "edge_count", "relationship_count", "relation_count",
            ]
        )
    }
}

enum NodeClaimState: String, CaseIterable, Hashable, Codable {
    case claimed
    case pending
    case unclaimed

    var title: String {
        switch self {
        case .claimed:
            return AppLocalization.string("node.claim.claimed", fallback: "Claimed")
        case .pending:
            return AppLocalization.string("node.claim.pending", fallback: "Pending")
        case .unclaimed:
            return AppLocalization.string("node.claim.unclaimed", fallback: "Unclaimed")
        }
    }

    var tintName: String {
        switch self {
        case .claimed:
            return "green"
        case .pending:
            return "orange"
        case .unclaimed:
            return "secondary"
        }
    }
}

enum NodeHeartbeatState: String, CaseIterable, Hashable, Codable {
    case healthy
    case warning
    case offline

    var title: String {
        switch self {
        case .healthy:
            return AppLocalization.string("node.heartbeat.healthy", fallback: "Healthy")
        case .warning:
            return AppLocalization.string("node.heartbeat.warning", fallback: "Warning")
        case .offline:
            return AppLocalization.string("node.heartbeat.offline", fallback: "Offline")
        }
    }

    var tintName: String {
        switch self {
        case .healthy:
            return "green"
        case .warning:
            return "orange"
        case .offline:
            return "red"
        }
    }
}

enum NodeEnvironment: String, CaseIterable, Hashable, Codable {
    case production
    case staging
    case local

    var title: String {
        switch self {
        case .production:
            return AppLocalization.string("node.environment.production", fallback: "Production")
        case .staging:
            return AppLocalization.string("node.environment.staging", fallback: "Staging")
        case .local:
            return AppLocalization.string("node.environment.local", fallback: "Local")
        }
    }
}

struct NodeEvent: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String
    var titleKey: String? = nil
    var detailKey: String? = nil

    init(
        id: UUID = UUID(),
        timestamp: Date,
        title: String,
        detail: String,
        titleKey: String? = nil,
        detailKey: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.titleKey = titleKey
        self.detailKey = detailKey
    }

    var localizedTitle: String {
        guard let titleKey else { return AppLocalization.phrase(title) }
        return AppLocalization.string(titleKey, fallback: title)
    }

    var localizedDetail: String {
        guard let detailKey else { return AppLocalization.phrase(detail) }
        return AppLocalization.string(detailKey, fallback: detail)
    }
}

struct NodeTaskPreview: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var summary: String?
    var rewardCredits: Int?
    var domain: String?
    var kind: String?
}

struct NodeOverdueTask: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var commitmentDeadline: Date?
    var overdueMinutes: Int?
}

struct NodePendingEventPreview: Identifiable, Hashable, Codable {
    let id: String
    var type: String
    var createdAt: Date?
    var priority: Int?
    var summary: String
}

struct NodePeerPreview: Identifiable, Hashable, Codable {
    let id: String
    var alias: String?
    var online: Bool
    var reputation: Double?
    var workload: Int?
}

struct NodeErrorPatternPreview: Identifiable, Hashable, Codable {
    let id: String
    var count: Int
    var escalation: String?
    var reason: String?
}

struct NodeAccountabilitySnapshot: Hashable, Codable {
    var reputationPenalty: Int
    var quarantineStrikes: Int
    var publishCooldownUntil: Date?
    var recommendation: String?
    var topPatterns: [NodeErrorPatternPreview]

    var needsAttention: Bool {
        reputationPenalty > 0 || quarantineStrikes > 0 || publishCooldownUntil != nil
    }
}

struct NodeSkillStoreStatus: Hashable, Codable {
    var eligible: Bool
    var publishedSkillCount: Int
    var publishEndpoint: String?
    var hint: String?
}

struct NodeHeartbeatSnapshot: Hashable, Codable {
    var nextHeartbeatAt: Date?
    var availableTasks: [NodeTaskPreview]
    var availableWork: [NodeTaskPreview]
    var overdueTasks: [NodeOverdueTask]
    var pendingEvents: [NodePendingEventPreview]
    var peers: [NodePeerPreview]
    var accountability: NodeAccountabilitySnapshot?
    var skillStore: NodeSkillStoreStatus?

    var dispatchCount: Int {
        availableTasks.count + availableWork.count
    }
}

struct NodeRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var senderID: String
    var apiBaseURL: String
    var environment: NodeEnvironment
    var modelName: String
    var geneCount: Int
    var capsuleCount: Int
    var claimState: NodeClaimState
    var heartbeat: NodeHeartbeatState
    var lastSeen: Date
    var onlineWorkers: Int
    var creditBalance: Int
    var claimCode: String?
    var claimURL: String?
    var referralCode: String?
    var survivalStatus: String?
    var reputationScore: Double? = nil
    var nodeSecretStored: Bool
    var lastErrorMessage: String?
    var notes: String
    var recentEvents: [NodeEvent]
    var recommendedHeartbeatIntervalMS: Int?
    var heartbeatEndpoint: String?
    var heartbeatSnapshot: NodeHeartbeatSnapshot?
    var isSampleData: Bool = false

    var pendingEventCount: Int {
        heartbeatSnapshot?.pendingEvents.count ?? 0
    }

    var dispatchCount: Int {
        heartbeatSnapshot?.dispatchCount ?? 0
    }

    var overdueTaskCount: Int {
        heartbeatSnapshot?.overdueTasks.count ?? 0
    }

    var peerCount: Int {
        heartbeatSnapshot?.peers.count ?? 0
    }

    var skillStoreStatus: NodeSkillStoreStatus? {
        heartbeatSnapshot?.skillStore
    }
}

struct NodeConnectionDraft: Identifiable, Equatable {
    let id = UUID()
    var editingNodeID: NodeRecord.ID?
    var nodeName: String
    var senderID: String
    var baseURL: String
    var environment: NodeEnvironment
    var modelName: String
    var geneCount: Int
    var capsuleCount: Int
    var referrer: String
    var identityDoc: String
    var constitution: String
}

enum SkillState: String, CaseIterable, Hashable {
    case draft
    case changed
    case published

    var title: String {
        switch self {
        case .draft:
            return AppLocalization.string("skill.state.draft", fallback: "Draft")
        case .changed:
            return AppLocalization.string("skill.state.changed", fallback: "Changed")
        case .published:
            return AppLocalization.string("skill.state.published", fallback: "Published")
        }
    }

    var tintName: String {
        switch self {
        case .draft:
            return "secondary"
        case .changed:
            return "orange"
        case .published:
            return "green"
        }
    }
}

enum SkillPublishCategory: String, CaseIterable, Hashable {
    case repair
    case optimize
    case innovate

    var title: String {
        switch self {
        case .repair:
            return AppLocalization.string("skill.category.repair", fallback: "Repair")
        case .optimize:
            return AppLocalization.string("skill.category.optimize", fallback: "Optimize")
        case .innovate:
            return AppLocalization.string("skill.category.innovate", fallback: "Innovate")
        }
    }

    var tintName: String {
        switch self {
        case .repair:
            return "orange"
        case .optimize:
            return "blue"
        case .innovate:
            return "green"
        }
    }
}

enum SkillWorkspaceMode: String, CaseIterable, Identifiable {
    case local
    case store
    case recycleBin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local:
            return AppLocalization.string("skill.workspace.local", fallback: "Local Library")
        case .store:
            return AppLocalization.string("skill.workspace.store", fallback: "Skill Store")
        case .recycleBin:
            return AppLocalization.string("skill.workspace.recycle_bin", fallback: "Recycle Bin")
        }
    }
}

enum ServiceComposerMode: String, CaseIterable, Hashable {
    case publish
    case update

    var title: String {
        switch self {
        case .publish:
            return AppLocalization.string("service.composer.publish", fallback: "Publish Service")
        case .update:
            return AppLocalization.string("service.composer.update", fallback: "Update Service")
        }
    }

    var submitTitle: String {
        switch self {
        case .publish:
            return AppLocalization.string("service.submit.publish", fallback: "Publish to Marketplace")
        case .update:
            return AppLocalization.string("service.submit.update", fallback: "Save Service Update")
        }
    }
}

enum ServiceLifecycleStatus: String, CaseIterable, Hashable {
    case active
    case paused
    case archived

    var title: String {
        switch self {
        case .active:
            return AppLocalization.string("service.lifecycle.active", fallback: "Active")
        case .paused:
            return AppLocalization.string("service.lifecycle.paused", fallback: "Paused")
        case .archived:
            return AppLocalization.string("service.lifecycle.archived", fallback: "Archived")
        }
    }

    var tintName: String {
        switch self {
        case .active:
            return "green"
        case .paused:
            return "orange"
        case .archived:
            return "secondary"
        }
    }
}

struct ServiceDraft: Identifiable, Equatable {
    let id = UUID()
    var mode: ServiceComposerMode
    var listingID: String?
    var title: String
    var description: String
    var capabilitiesText: String
    var useCasesText: String
    var pricePerTask: Int
    var maxConcurrent: Int
    var recipeID: String
    var status: ServiceLifecycleStatus
    var authorNodeID: String?

    static let empty = ServiceDraft(
        mode: .publish,
        listingID: nil,
        title: "",
        description: "",
        capabilitiesText: "",
        useCasesText: "",
        pricePerTask: 10,
        maxConcurrent: 1,
        recipeID: "",
        status: .active,
        authorNodeID: nil
    )
}

enum SkillValidationSeverity: String, CaseIterable, Hashable {
    case error
    case warning
    case info

    var title: String {
        switch self {
        case .error:
            return AppLocalization.phrase("Error")
        case .warning:
            return AppLocalization.phrase("Warning")
        case .info:
            return AppLocalization.phrase("Info")
        }
    }

    var tintName: String {
        switch self {
        case .error:
            return "red"
        case .warning:
            return "orange"
        case .info:
            return "blue"
        }
    }
}

struct SkillValidationIssue: Identifiable, Hashable {
    let id = UUID()
    var severity: SkillValidationSeverity
    var title: String
    var detail: String
}

struct SkillBundledFile: Identifiable, Hashable {
    let id: String
    var relativePath: String
    var characterCount: Int
    var content: String?
    var isIncluded: Bool
    var note: String?
}

struct RemoteSkillAuthor: Decodable, Hashable {
    var nodeId: String
    var alias: String?
}

struct RemoteSkillSummary: Identifiable, Decodable, Hashable {
    var skillId: String
    var name: String
    var description: String
    var version: String
    var category: String?
    var tags: [String]
    var downloadCount: Int
    var createdAt: Date?
    var featured: Bool
    var featuredAt: Date?
    var author: RemoteSkillAuthor?
    var contentPreview: String?
    var hasFullContent: Bool?
    var bundledFileCount: Int?
    var strategy: [String]?

    var id: String { skillId }
}

struct RemoteSkillDetail: Decodable, Hashable {
    var skillId: String
    var name: String
    var description: String
    var version: String
    var category: String?
    var tags: [String]
    var downloadCount: Int
    var visibility: String?
    var reviewStatus: String?
    var createdAt: Date?
    var updatedAt: Date?
    var featured: Bool
    var featuredAt: Date?
    var author: RemoteSkillAuthor?
    var contentPreview: String?
    var hasFullContent: Bool?
    var totalLines: Int?
    var totalChars: Int?
    var bundledFileCount: Int?
    var bundledFileNames: [String]
    var downloadCost: Int?
    var strategy: [String]?
}

struct RemoteSkillVersion: Identifiable, Decodable, Hashable {
    var version: String
    var changelog: String?
    var createdAt: Date?

    var id: String {
        "\(version)-\(createdAt?.timeIntervalSince1970 ?? 0)"
    }
}

struct RecycledSkillSummary: Identifiable, Decodable, Hashable {
    var skillId: String
    var name: String
    var description: String?
    var version: String?
    var category: String?
    var tags: [String]
    var deletedAt: Date?
    var updatedAt: Date?
    var originalVisibility: String?
    var reviewStatus: String?
    var author: RemoteSkillAuthor?
    var totalVersions: Int?
    var downloadCount: Int?

    var id: String { skillId }

    enum CodingKeys: String, CodingKey {
        case skillId
        case skillID = "skill_id"
        case name
        case description
        case version
        case category
        case tags
        case deletedAt
        case updatedAt
        case originalVisibility
        case visibility
        case reviewStatus
        case author
        case totalVersions
        case versionCount
        case downloadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let skillId = (try? container.decodeIfPresent(String.self, forKey: .skillID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .skillId))
        let name = try container.decodeIfPresent(String.self, forKey: .name)

        guard let resolvedSkillId = skillId?.nonEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .skillID, in: container, debugDescription: "Missing recycled skill id.")
        }

        self.skillId = resolvedSkillId
        self.name = name?.nonEmpty ?? resolvedSkillId
        description = try container.decodeIfPresent(String.self, forKey: .description)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        originalVisibility = try container.decodeIfPresent(String.self, forKey: .originalVisibility)
            ?? (try container.decodeIfPresent(String.self, forKey: .visibility))
        reviewStatus = try container.decodeIfPresent(String.self, forKey: .reviewStatus)
        author = try container.decodeIfPresent(RemoteSkillAuthor.self, forKey: .author)
        totalVersions = try container.decodeIfPresent(Int.self, forKey: .totalVersions)
            ?? (try container.decodeIfPresent(Int.self, forKey: .versionCount))
        downloadCount = try container.decodeIfPresent(Int.self, forKey: .downloadCount)
    }
}

struct RemoteServiceSummary: Identifiable, Decodable, Hashable {
    var listingID: String
    var title: String
    var description: String
    var capabilities: [String]
    var useCases: [String]
    var pricePerTask: Int?
    var rating: Double?
    var completionRate: Double?
    var averageResponseTime: String?
    var tasksCompleted: Int?
    var activeTasks: Int?
    var maxConcurrent: Int?
    var status: String?
    var recipeID: String?
    var providerNodeID: String?
    var providerAlias: String?
    var createdAt: Date?
    var updatedAt: Date?

    var id: String { listingID }

    init(from decoder: Decoder) throws {
        let payload = try ServiceDecodedPayload(from: decoder)
        listingID = payload.listingID
        title = payload.title
        description = payload.description
        capabilities = payload.capabilities
        useCases = payload.useCases
        pricePerTask = payload.pricePerTask
        rating = payload.rating
        completionRate = payload.completionRate
        averageResponseTime = payload.averageResponseTime
        tasksCompleted = payload.tasksCompleted
        activeTasks = payload.activeTasks
        maxConcurrent = payload.maxConcurrent
        status = payload.status
        recipeID = payload.recipeID
        providerNodeID = payload.providerNodeID
        providerAlias = payload.providerAlias
        createdAt = payload.createdAt
        updatedAt = payload.updatedAt
    }
}

struct RemoteServiceDetail: Decodable, Hashable {
    var listingID: String
    var title: String
    var description: String
    var capabilities: [String]
    var useCases: [String]
    var pricePerTask: Int?
    var rating: Double?
    var completionRate: Double?
    var averageResponseTime: String?
    var tasksCompleted: Int?
    var activeTasks: Int?
    var maxConcurrent: Int?
    var status: String?
    var recipeID: String?
    var providerNodeID: String?
    var providerAlias: String?
    var createdAt: Date?
    var updatedAt: Date?

    init(from decoder: Decoder) throws {
        let payload = try ServiceDecodedPayload(from: decoder)
        listingID = payload.listingID
        title = payload.title
        description = payload.description
        capabilities = payload.capabilities
        useCases = payload.useCases
        pricePerTask = payload.pricePerTask
        rating = payload.rating
        completionRate = payload.completionRate
        averageResponseTime = payload.averageResponseTime
        tasksCompleted = payload.tasksCompleted
        activeTasks = payload.activeTasks
        maxConcurrent = payload.maxConcurrent
        status = payload.status
        recipeID = payload.recipeID
        providerNodeID = payload.providerNodeID
        providerAlias = payload.providerAlias
        createdAt = payload.createdAt
        updatedAt = payload.updatedAt
    }
}

struct ServiceRatingDraft: Identifiable, Equatable {
    let id = UUID()
    var listingID: String
    var serviceTitle: String
    var taskID: String?
    var requesterNodeID: String?
    var rating: Int
    var comment: String

    static let empty = ServiceRatingDraft(
        listingID: "",
        serviceTitle: "",
        taskID: nil,
        requesterNodeID: nil,
        rating: 5,
        comment: ""
    )
}

struct RemoteServiceRating: Identifiable, Decodable, Hashable {
    var ratingID: String
    var rating: Int
    var comment: String?
    var taskID: String?
    var authorNodeID: String?
    var authorAlias: String?
    var createdAt: Date?

    var id: String { ratingID }

    init(from decoder: Decoder) throws {
        let payload = try ServiceRatingDecodedPayload(from: decoder)
        ratingID = payload.ratingID
        rating = payload.rating
        comment = payload.comment
        taskID = payload.taskID
        authorNodeID = payload.authorNodeID
        authorAlias = payload.authorAlias
        createdAt = payload.createdAt
    }
}

struct OrderDraft: Identifiable, Equatable {
    let id = UUID()
    var listingID: String
    var serviceTitle: String
    var serviceDescription: String
    var providerNodeID: String?
    var providerAlias: String?
    var requesterNodeID: String?
    var question: String
    var estimatedCredits: Int?
    var recipeID: String?

    static let empty = OrderDraft(
        listingID: "",
        serviceTitle: "",
        serviceDescription: "",
        providerNodeID: nil,
        providerAlias: nil,
        requesterNodeID: nil,
        question: "",
        estimatedCredits: nil,
        recipeID: nil
    )
}

enum OrderStatusCategory: Hashable {
    case open
    case inProgress
    case submitted
    case completed
    case expired
    case unknown

    init(status: String?) {
        switch status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_") {
        case "open", "created", "pending":
            self = .open
        case "claimed", "processing", "in_progress", "working", "running":
            self = .inProgress
        case "submitted", "pending_review", "review":
            self = .submitted
        case "completed", "accepted", "settled", "done", "resolved":
            self = .completed
        case "expired", "cancelled", "canceled", "failed", "rejected":
            self = .expired
        default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .open:
            return AppLocalization.string("order.status.open", fallback: "Open")
        case .inProgress:
            return AppLocalization.string("order.status.in_progress", fallback: "In Progress")
        case .submitted:
            return AppLocalization.string("order.status.submitted", fallback: "Submitted")
        case .completed:
            return AppLocalization.string("order.status.completed", fallback: "Completed")
        case .expired:
            return AppLocalization.string("order.status.expired", fallback: "Expired")
        case .unknown:
            return AppLocalization.string("order.status.unknown", fallback: "Unknown")
        }
    }

    var tintName: String {
        switch self {
        case .open:
            return "blue"
        case .inProgress:
            return "orange"
        case .submitted:
            return "purple"
        case .completed:
            return "green"
        case .expired:
            return "secondary"
        case .unknown:
            return "secondary"
        }
    }
}

enum OrderTimelineStage: String, Hashable {
    case created
    case claimed
    case processing
    case submitted
    case completed
    case expired

    var title: String {
        switch self {
        case .created:
            return AppLocalization.string("order.timeline.created", fallback: "Created")
        case .claimed:
            return AppLocalization.string("order.timeline.claimed", fallback: "Claimed")
        case .processing:
            return AppLocalization.string("order.timeline.processing", fallback: "Processing")
        case .submitted:
            return AppLocalization.string("order.timeline.submitted", fallback: "Submitted")
        case .completed:
            return AppLocalization.string("order.timeline.completed", fallback: "Completed")
        case .expired:
            return AppLocalization.string("order.timeline.expired", fallback: "Expired")
        }
    }

    var tintName: String {
        switch self {
        case .created:
            return "blue"
        case .claimed, .processing:
            return "orange"
        case .submitted:
            return "purple"
        case .completed:
            return "green"
        case .expired:
            return "secondary"
        }
    }
}

struct OrderTimelineEntry: Identifiable, Hashable {
    let id: String
    var stage: OrderTimelineStage
    var timestamp: Date?
    var detail: String?
}

struct RemoteOrderSubmission: Identifiable, Hashable {
    var submissionID: String
    var title: String
    var summary: String?
    var assetID: String?
    var assetTitle: String?
    var assetURL: String?
    var status: String?
    var submittedAt: Date?
    var acceptedAt: Date?

    var id: String { submissionID }
}

struct TrackedServiceOrder: Identifiable, Codable, Hashable {
    var taskID: String
    var listingID: String?
    var serviceTitle: String
    var question: String
    var requesterNodeID: String
    var providerNodeID: String?
    var providerAlias: String?
    var status: String
    var creditsSpent: Int?
    var organismID: String?
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?
    var latestSubmissionID: String?
    var latestSubmissionAt: Date?
    var finalAssetID: String?
    var finalAssetURL: String?
    var lastRatedAt: Date?
    var lastRating: Int?

    var id: String { taskID }

    var statusCategory: OrderStatusCategory {
        OrderStatusCategory(status: status)
    }
}

struct RemoteOrderPlacement: Decodable, Hashable {
    var taskID: String
    var listingID: String?
    var serviceTitle: String?
    var providerNodeID: String?
    var providerAlias: String?
    var creditsDeducted: Int?
    var organismID: String?
    var status: String?
    var message: String?

    init(from decoder: Decoder) throws {
        let payload = try OrderDecodedPayload(from: decoder)
        taskID = payload.taskID
        listingID = payload.listingID
        serviceTitle = payload.serviceTitle?.nonEmpty
        providerNodeID = payload.providerNodeID
        providerAlias = payload.providerAlias
        creditsDeducted = payload.creditsSpent
        organismID = payload.organismID
        status = payload.status
        message = payload.message
    }
}

struct RemoteOrderDetail: Decodable, Hashable {
    var taskID: String
    var listingID: String?
    var serviceTitle: String
    var question: String?
    var requesterNodeID: String?
    var requesterAlias: String?
    var providerNodeID: String?
    var providerAlias: String?
    var status: String?
    var creditsSpent: Int?
    var organismID: String?
    var recipeID: String?
    var createdAt: Date?
    var claimedAt: Date?
    var processingAt: Date?
    var submittedAt: Date?
    var completedAt: Date?
    var expiredAt: Date?
    var updatedAt: Date?
    var finalAssetID: String?
    var finalAssetTitle: String?
    var finalAssetURL: String?
    var submissions: [RemoteOrderSubmission]
    var timeline: [OrderTimelineEntry]

    init(from decoder: Decoder) throws {
        let payload = try OrderDecodedPayload(from: decoder)
        taskID = payload.taskID
        listingID = payload.listingID
        serviceTitle = payload.serviceTitle?.nonEmpty ?? payload.listingID ?? payload.taskID
        question = payload.question
        requesterNodeID = payload.requesterNodeID
        requesterAlias = payload.requesterAlias
        providerNodeID = payload.providerNodeID
        providerAlias = payload.providerAlias
        status = payload.status
        creditsSpent = payload.creditsSpent
        organismID = payload.organismID
        recipeID = payload.recipeID
        createdAt = payload.createdAt
        claimedAt = payload.claimedAt
        processingAt = payload.processingAt
        submittedAt = payload.submittedAt
        completedAt = payload.completedAt
        expiredAt = payload.expiredAt
        updatedAt = payload.updatedAt
        finalAssetID = payload.finalAssetID
        finalAssetTitle = payload.finalAssetTitle
        finalAssetURL = payload.finalAssetURL
        submissions = payload.submissions
        timeline = payload.timeline
    }
}

struct BountyAnswerDraft: Identifiable, Codable, Hashable {
    var taskKey: String
    var taskID: String?
    var bountyID: String?
    var questionID: String?
    var title: String
    var body: String?
    var implementationNotes: String
    var answerText: String
    var verificationNotes: String
    var followupQuestion: String
    var generatedAt: Date?
    var updatedAt: Date
    var publishedAssetID: String?
    var submissionID: String?
    var submissionStatus: String?
    var patchCourierRequestID: String?
    var patchCourierTaskID: String?
    var patchCourierStatus: String?
    var patchCourierThreadToken: String?
    var patchCourierSentAt: Date?
    var patchCourierReceivedAt: Date?
    var patchCourierMessageID: String?
    var patchCourierConfidence: String?
    var patchCourierRiskFlags: String?

    var id: String { taskKey }

    var hasAnswer: Bool {
        answerText.nonEmpty != nil
    }

    static let empty = BountyAnswerDraft(
        taskKey: "",
        taskID: nil,
        bountyID: nil,
        questionID: nil,
        title: "",
        body: nil,
        implementationNotes: "",
        answerText: "",
        verificationNotes: "",
        followupQuestion: "",
        generatedAt: nil,
        updatedAt: Date(),
        publishedAssetID: nil,
        submissionID: nil,
        submissionStatus: nil,
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

enum BountyAutopilotRunStatus: String, Codable, Hashable {
    case queued
    case scanning
    case claiming
    case executing
    case needsReview
    case submitting
    case completed
    case failed

    var title: String {
        switch self {
        case .queued:
            return AppLocalization.string("bounties.autopilot.status.queued", fallback: "Queued")
        case .scanning:
            return AppLocalization.string("bounties.autopilot.status.scanning", fallback: "Scanning")
        case .claiming:
            return AppLocalization.string("bounties.autopilot.status.claiming", fallback: "Claiming")
        case .executing:
            return AppLocalization.string("bounties.autopilot.status.executing", fallback: "Executing")
        case .needsReview:
            return AppLocalization.string("bounties.autopilot.status.needs_review", fallback: "Needs review")
        case .submitting:
            return AppLocalization.string("bounties.autopilot.status.submitting", fallback: "Submitting")
        case .completed:
            return AppLocalization.string("bounties.autopilot.status.completed", fallback: "Completed")
        case .failed:
            return AppLocalization.string("bounties.autopilot.status.failed", fallback: "Failed")
        }
    }

    var tintName: String {
        switch self {
        case .queued, .scanning:
            return "blue"
        case .claiming, .executing, .submitting:
            return "orange"
        case .needsReview:
            return "purple"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
}

struct BountyAutopilotEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var timestamp: Date
    var title: String
    var detail: String
    var status: BountyAutopilotRunStatus

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String,
        detail: String,
        status: BountyAutopilotRunStatus
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.status = status
    }
}

struct BountyAutopilotRun: Identifiable, Codable, Hashable {
    var id: UUID
    var startedAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var status: BountyAutopilotRunStatus
    var taskID: String?
    var bountyID: String?
    var title: String
    var rewardCredits: Int?
    var score: Int?
    var executor: BountyExecutionProvider
    var autoSubmitEnabled: Bool
    var prompt: String?
    var rawExecutorOutput: String?
    var finalAnswerPreview: String?
    var submissionID: String?
    var publishedAssetID: String?
    var errorMessage: String?
    var events: [BountyAutopilotEvent]

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        status: BountyAutopilotRunStatus,
        taskID: String?,
        bountyID: String?,
        title: String,
        rewardCredits: Int?,
        score: Int?,
        executor: BountyExecutionProvider,
        autoSubmitEnabled: Bool,
        prompt: String? = nil,
        rawExecutorOutput: String? = nil,
        finalAnswerPreview: String? = nil,
        submissionID: String? = nil,
        publishedAssetID: String? = nil,
        errorMessage: String? = nil,
        events: [BountyAutopilotEvent] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.status = status
        self.taskID = taskID
        self.bountyID = bountyID
        self.title = title
        self.rewardCredits = rewardCredits
        self.score = score
        self.executor = executor
        self.autoSubmitEnabled = autoSubmitEnabled
        self.prompt = prompt
        self.rawExecutorOutput = rawExecutorOutput
        self.finalAnswerPreview = finalAnswerPreview
        self.submissionID = submissionID
        self.publishedAssetID = publishedAssetID
        self.errorMessage = errorMessage
        self.events = events
    }
}

struct BountyAutopilotCandidate: Identifiable, Hashable {
    var task: EvoMapBountyTask
    var score: Int
    var reasons: [String]
    var risks: [String]

    var id: String { task.id }
}

enum BountyExecutionProvider: String, CaseIterable, Identifiable, Codable {
    case openClaw
    case codexCLI
    case claudeCode
    case directModel
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openClaw:
            return AppLocalization.string("bounties.executor.openclaw", fallback: "OpenClaw")
        case .codexCLI:
            return AppLocalization.string("bounties.executor.codex", fallback: "Codex CLI")
        case .claudeCode:
            return AppLocalization.string("bounties.executor.claude", fallback: "Claude Code")
        case .directModel:
            return AppLocalization.string("bounties.executor.direct_model", fallback: "Direct model")
        case .manual:
            return AppLocalization.string("bounties.executor.manual", fallback: "Manual")
        }
    }

    var note: String {
        switch self {
        case .openClaw:
            return AppLocalization.string(
                "bounties.executor.openclaw.note",
                fallback: "Recommended: let OpenClaw do the work, then paste the reviewed result back into Final answer. EvoMap submission still stays manual."
            )
        case .codexCLI:
            return AppLocalization.string(
                "bounties.executor.codex.note",
                fallback: "Recommended here: runs locally, can use your Codex skills, and keeps execution separate from final EvoMap submission."
            )
        case .claudeCode:
            return AppLocalization.string(
                "bounties.executor.claude.note",
                fallback: "Good alternative for code-heavy work. Use the generated brief and review its answer before submitting."
            )
        case .directModel:
            return AppLocalization.string(
                "bounties.executor.direct_model.note",
                fallback: "Best later for fully automated text-only jobs, but it needs explicit API-key, cost, and skill-runtime controls."
            )
        case .manual:
            return AppLocalization.string(
                "bounties.executor.manual.note",
                fallback: "Use the brief as a checklist and write the final answer yourself."
            )
        }
    }
}

struct SkillRecord: Identifiable, Hashable {
    let id: UUID
    var skillID: String
    var name: String
    var summary: String
    var category: SkillPublishCategory
    var tags: [String]
    var state: SkillState
    var localCharacterCount: Int
    var bundledFiles: [SkillBundledFile]
    var remoteVersion: String?
    var updatedAt: Date
    var sourcePath: String?
    var content: String
    var validationIssues: [SkillValidationIssue]
    var remoteStatus: String? = nil
    var lastPublishedAt: Date? = nil
    var lastPublishedBySenderID: String? = nil
    var lastPublishMessage: String? = nil
    var lastPublishErrorMessage: String? = nil
    var storeSnapshotVersion: String? = nil
    var downloadedFromStoreAt: Date? = nil
    var downloadedFromStoreAuthorNodeID: String? = nil
    var downloadedStoreDirectoryPath: String? = nil
    var downloadedCreditCost: Int? = nil
    var isSampleData: Bool = false

    var bundledFileCount: Int {
        bundledFiles.filter(\.isIncluded).count
    }

    var excludedBundledFileCount: Int {
        bundledFiles.filter { !$0.isIncluded }.count
    }

    var bundledCharacterCount: Int {
        bundledFiles.compactMap(\.content).reduce(0) { $0 + $1.count }
    }

    var errorCount: Int {
        validationIssues.filter { $0.severity == .error }.count
    }

    var warningCount: Int {
        validationIssues.filter { $0.severity == .warning }.count
    }

    var includedBundledFiles: [SkillBundledFile] {
        bundledFiles.filter(\.isIncluded)
    }

    var excludedBundledFiles: [SkillBundledFile] {
        bundledFiles.filter { !$0.isIncluded }
    }

    var suggestedVersion: String {
        guard let remoteVersion else { return "1.0.0" }
        let components = remoteVersion.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return remoteVersion }
        return "\(components[0]).\(components[1]).\(components[2] + 1)"
    }

    var isPublishReady: Bool {
        errorCount == 0
    }

    var readinessTitle: String {
        isPublishReady ? AppLocalization.phrase("Ready") : AppLocalization.phrase("Needs Fixes")
    }

    var readinessTintName: String {
        isPublishReady ? "green" : "red"
    }
}

struct OverviewMetric: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let systemImage: String
}

struct CreditSprintStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let tintName: String
    let isComplete: Bool
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ServiceDecodedPayload {
    let listingID: String
    let title: String
    let description: String
    let capabilities: [String]
    let useCases: [String]
    let pricePerTask: Int?
    let rating: Double?
    let completionRate: Double?
    let averageResponseTime: String?
    let tasksCompleted: Int?
    let activeTasks: Int?
    let maxConcurrent: Int?
    let status: String?
    let recipeID: String?
    let providerNodeID: String?
    let providerAlias: String?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case listingID = "listing_id"
        case id
        case serviceID = "service_id"
        case title
        case name
        case description
        case summary
        case capabilities
        case tags
        case useCases = "use_cases"
        case pricePerTask = "price_per_task"
        case price
        case rating
        case avgRating = "avg_rating"
        case completionRate = "completion_rate"
        case successRate = "success_rate"
        case averageResponseTime = "avg_response_time"
        case averageResponseTimeSeconds = "avg_response_time_seconds"
        case averageResponseTimeMS = "avg_response_time_ms"
        case tasksCompleted = "tasks_completed"
        case completedTasks = "completed_tasks"
        case totalCompletedTasks = "total_completed_tasks"
        case activeTasks = "active_tasks"
        case maxConcurrent = "max_concurrent"
        case status
        case recipeID = "recipe_id"
        case recipeLink = "recipe_link"
        case provider
        case owner
        case author
        case nodeID = "node_id"
        case senderID = "sender_id"
        case alias
        case createdAt
        case updatedAt
        case data
        case service
        case listing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let rootServiceContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .service)
        let dataServiceContainer = try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .service)
        let serviceContainer = rootServiceContainer ?? dataServiceContainer
        let rootListingContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .listing)
        let dataListingContainer = try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .listing)
        let nestedListingContainer = try? serviceContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .listing)
        let listingContainer = rootListingContainer ?? dataListingContainer ?? nestedListingContainer

        let containers = [container, dataContainer, serviceContainer, listingContainer].compactMap { $0 }

        func decodeString(_ keys: [CodingKeys]) -> String? {
            for container in containers {
                for key in keys {
                    if let value = container.decodeLossyStringIfPresent(forKey: key)?.nonEmpty {
                        return value
                    }
                }
            }
            return nil
        }

        func decodeInt(_ keys: [CodingKeys]) -> Int? {
            for container in containers {
                for key in keys {
                    if let value = container.decodeLossyIntIfPresent(forKey: key) {
                        return value
                    }
                }
            }
            return nil
        }

        func decodeDouble(_ keys: [CodingKeys]) -> Double? {
            for container in containers {
                for key in keys {
                    if let value = container.decodeLossyDoubleIfPresent(forKey: key) {
                        return value
                    }
                }
            }
            return nil
        }

        func decodeStringArray(_ keys: [CodingKeys]) -> [String] {
            for container in containers {
                for key in keys {
                    if let values = container.decodeLossyStringArrayIfPresent(forKey: key),
                       values.isEmpty == false {
                        return values
                    }
                }
            }
            return []
        }

        func decodeDate(_ keys: [CodingKeys]) -> Date? {
            for container in containers {
                for key in keys {
                    if let value = try? container.decodeIfPresent(Date.self, forKey: key) {
                        return value
                    }
                }
            }
            return nil
        }

        func nestedProviderContainers() -> [KeyedDecodingContainer<CodingKeys>] {
            containers.flatMap { container in
                [
                    try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .provider),
                    try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .owner),
                    try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .author),
                ]
                .compactMap { $0 }
            }
        }

        let providerContainers = nestedProviderContainers()

        func decodeProviderString(_ keys: [CodingKeys]) -> String? {
            for container in providerContainers {
                for key in keys {
                    if let value = container.decodeLossyStringIfPresent(forKey: key)?.nonEmpty {
                        return value
                    }
                }
            }
            return decodeString(keys)
        }

        guard let resolvedListingID = decodeString([.listingID, .id, .serviceID]) else {
            throw DecodingError.dataCorruptedError(
                forKey: .listingID,
                in: container,
                debugDescription: "Missing service listing identifier."
            )
        }

        listingID = resolvedListingID
        title = decodeString([.title, .name]) ?? resolvedListingID
        description = decodeString([.description, .summary]) ?? AppLocalization.phrase("No description is available for this service.")
        capabilities = decodeStringArray([.capabilities, .tags])
        useCases = decodeStringArray([.useCases])
        pricePerTask = decodeInt([.pricePerTask, .price])
        rating = decodeDouble([.rating, .avgRating])
        completionRate = decodeDouble([.completionRate, .successRate])
        tasksCompleted = decodeInt([.tasksCompleted, .completedTasks, .totalCompletedTasks])
        activeTasks = decodeInt([.activeTasks])
        maxConcurrent = decodeInt([.maxConcurrent])
        status = decodeString([.status])
        recipeID = decodeString([.recipeID, .recipeLink])
        providerNodeID = decodeProviderString([.nodeID, .senderID, .id])
        providerAlias = decodeProviderString([.alias, .title, .name])
        createdAt = decodeDate([.createdAt])
        updatedAt = decodeDate([.updatedAt])

        if let label = decodeString([.averageResponseTime]) {
            averageResponseTime = label
        } else if let seconds = decodeDouble([.averageResponseTimeSeconds]) {
            averageResponseTime = Self.formatDuration(seconds: seconds)
        } else if let milliseconds = decodeDouble([.averageResponseTimeMS]) {
            averageResponseTime = Self.formatDuration(seconds: milliseconds / 1000)
        } else {
            averageResponseTime = nil
        }
    }

    private static func formatDuration(seconds: Double) -> String {
        guard seconds.isFinite else { return AppLocalization.unknown }
        if seconds < 60 {
            return "\(Int(seconds.rounded()))s"
        }
        if seconds < 3600 {
            return "\(Int((seconds / 60).rounded()))m"
        }
        return String(format: "%.1fh", seconds / 3600)
    }
}

private struct OrderDecodedPayload {
    let taskID: String
    let listingID: String?
    let serviceTitle: String?
    let question: String?
    let requesterNodeID: String?
    let requesterAlias: String?
    let providerNodeID: String?
    let providerAlias: String?
    let status: String?
    let creditsSpent: Int?
    let organismID: String?
    let recipeID: String?
    let createdAt: Date?
    let claimedAt: Date?
    let processingAt: Date?
    let submittedAt: Date?
    let completedAt: Date?
    let expiredAt: Date?
    let updatedAt: Date?
    let finalAssetID: String?
    let finalAssetTitle: String?
    let finalAssetURL: String?
    let submissions: [RemoteOrderSubmission]
    let timeline: [OrderTimelineEntry]
    let message: String?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let primary = Self.pickPrimaryContainer(from: root)
        let containers = Self.uniqueObjects(
            [
                primary,
                root.value(at: ["data"]),
                root.value(at: ["task"]),
                root.value(at: ["order"]),
                root.value(at: ["data", "task"]),
                root.value(at: ["data", "order"]),
                root,
            ]
        )

        let serviceContainers = Self.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["service"]),
                    container.value(at: ["listing"]),
                    container.value(at: ["market_service"]),
                ]
            }
        )

        let providerContainers = Self.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["provider"]),
                    container.value(at: ["owner"]),
                    container.value(at: ["assignee"]),
                    container.value(at: ["worker"]),
                ]
            } + serviceContainers.flatMap { container in
                [
                    container.value(at: ["provider"]),
                    container.value(at: ["owner"]),
                    container.value(at: ["author"]),
                ]
            }
        )

        let requesterContainers = Self.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["buyer"]),
                    container.value(at: ["requester"]),
                    container.value(at: ["sender"]),
                    container.value(at: ["creator"]),
                ]
            }
        )

        let finalAssetContainers = Self.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["final_asset"]),
                    container.value(at: ["asset"]),
                    container.value(at: ["deliverable"]),
                    container.value(at: ["result"]),
                ]
            }
        )

        guard let resolvedTaskID = Self.string(
            keys: ["task_id", "order_id", "id"],
            preferred: containers,
            recursive: containers
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing order task identifier.")
            )
        }

        taskID = resolvedTaskID
        listingID = Self.string(
            keys: ["listing_id", "service_id"],
            preferred: serviceContainers + containers,
            recursive: containers
        )
        serviceTitle = Self.string(
            keys: ["title", "name", "service_title", "listing_title"],
            preferred: serviceContainers,
            recursive: containers
        )
        question = Self.string(keys: ["question", "prompt", "description", "task_description"], preferred: containers, recursive: containers)
        requesterNodeID = Self.string(keys: ["node_id", "sender_id", "buyer_node_id"], preferred: requesterContainers, recursive: containers)
        requesterAlias = Self.string(keys: ["alias", "name", "title"], preferred: requesterContainers, recursive: requesterContainers)
        providerNodeID = Self.string(keys: ["node_id", "sender_id", "provider_node_id"], preferred: providerContainers, recursive: containers)
        providerAlias = Self.string(keys: ["alias", "name", "title"], preferred: providerContainers, recursive: providerContainers)
        status = Self.string(keys: ["status", "task_status", "order_status"], preferred: containers, recursive: containers)
        creditsSpent = Self.int(
            keys: ["credits_deducted", "credit_cost", "amount", "order_amount", "price_per_task", "price"],
            preferred: containers,
            recursive: containers
        )
        organismID = Self.string(keys: ["organism_id", "organism"], preferred: containers, recursive: containers)
        recipeID = Self.string(keys: ["recipe_id", "recipe_link"], preferred: serviceContainers + containers, recursive: containers)
        createdAt = Self.date(keys: ["created_at", "ordered_at"], preferred: containers, recursive: containers)
        claimedAt = Self.date(keys: ["claimed_at"], preferred: containers, recursive: containers)
        processingAt = Self.date(keys: ["processing_at", "started_at"], preferred: containers, recursive: containers)
        submittedAt = Self.date(keys: ["submitted_at"], preferred: containers, recursive: containers)
        completedAt = Self.date(keys: ["completed_at", "accepted_at", "settled_at"], preferred: containers, recursive: containers)
        expiredAt = Self.date(keys: ["expired_at"], preferred: containers, recursive: containers)
        updatedAt = Self.date(keys: ["updated_at"], preferred: containers, recursive: containers)
        finalAssetID = Self.string(keys: ["asset_id", "id"], preferred: finalAssetContainers, recursive: finalAssetContainers)
        finalAssetTitle = Self.string(keys: ["title", "name"], preferred: finalAssetContainers, recursive: finalAssetContainers)
        finalAssetURL = Self.string(keys: ["asset_url", "url", "href"], preferred: finalAssetContainers, recursive: finalAssetContainers)
        submissions = Self.decodeSubmissions(from: containers)
        timeline = Self.decodeTimeline(
            from: containers,
            createdAt: createdAt,
            claimedAt: claimedAt,
            processingAt: processingAt,
            submittedAt: submittedAt,
            completedAt: completedAt,
            expiredAt: expiredAt
        )
        message = Self.string(keys: ["message"], preferred: containers, recursive: containers)
    }

    fileprivate static func decodeSubmissions(from containers: [JSONValue]) -> [RemoteOrderSubmission] {
        let submissionArrays = containers.flatMap { container in
            [
                container.value(at: ["submissions"]),
                container.value(at: ["results"]),
                container.value(at: ["deliverables"]),
            ]
            .compactMap { $0?.arrayValue }
        }

        let values = submissionArrays.first(where: { $0.isEmpty == false }) ?? []
        return values.enumerated().compactMap { index, value in
            let asset = Self.uniqueObjects(
                [
                    value.value(at: ["asset"]),
                    value.value(at: ["deliverable"]),
                    value.value(at: ["result"]),
                    value,
                ]
            )

            let submissionID = Self.string(keys: ["submission_id", "id"], preferred: [value], recursive: [value])
                ?? Self.string(keys: ["asset_id", "id"], preferred: asset, recursive: asset)
                ?? "submission-\(index + 1)"

            let title = Self.string(keys: ["title", "name"], preferred: asset + [value], recursive: [value])
                ?? submissionID

            return RemoteOrderSubmission(
                submissionID: submissionID,
                title: title,
                summary: Self.string(keys: ["summary", "description", "note"], preferred: [value], recursive: [value]),
                assetID: Self.string(keys: ["asset_id", "id"], preferred: asset, recursive: asset),
                assetTitle: Self.string(keys: ["title", "name"], preferred: asset, recursive: asset),
                assetURL: Self.string(keys: ["asset_url", "url", "href"], preferred: asset, recursive: asset),
                status: Self.string(keys: ["status"], preferred: [value], recursive: [value]),
                submittedAt: Self.date(keys: ["submitted_at", "created_at"], preferred: [value], recursive: [value]),
                acceptedAt: Self.date(keys: ["accepted_at"], preferred: [value], recursive: [value])
            )
        }
    }

    fileprivate static func decodeTimeline(
        from containers: [JSONValue],
        createdAt: Date?,
        claimedAt: Date?,
        processingAt: Date?,
        submittedAt: Date?,
        completedAt: Date?,
        expiredAt: Date?
    ) -> [OrderTimelineEntry] {
        let timelineArrays = containers.flatMap { container in
            [
                container.value(at: ["timeline"]),
                container.value(at: ["events"]),
                container.value(at: ["status_history"]),
                container.value(at: ["history"]),
            ]
            .compactMap { $0?.arrayValue }
        }

        if let values = timelineArrays.first(where: { $0.isEmpty == false }) {
            let decoded = values.enumerated().compactMap { index, value -> OrderTimelineEntry? in
                guard let stage = Self.stage(
                    from: Self.string(keys: ["stage", "status", "type", "name"], preferred: [value], recursive: [value])
                ) else {
                    return nil
                }
                let detail = Self.string(keys: ["detail", "summary", "message"], preferred: [value], recursive: [value])
                let timestamp = Self.date(keys: ["timestamp", "created_at", "updated_at"], preferred: [value], recursive: [value])
                return OrderTimelineEntry(
                    id: Self.string(keys: ["id", "event_id"], preferred: [value], recursive: [value]) ?? "timeline-\(index + 1)",
                    stage: stage,
                    timestamp: timestamp,
                    detail: detail
                )
            }
            if decoded.isEmpty == false {
                return decoded
            }
        }

        let derived: [(OrderTimelineStage, Date?, String?)] = [
            (.created, createdAt, AppLocalization.phrase("Order created")),
            (.claimed, claimedAt, AppLocalization.phrase("Provider claimed the task")),
            (.processing, processingAt, AppLocalization.phrase("Work began")),
            (.submitted, submittedAt, AppLocalization.phrase("Submission received")),
            (.completed, completedAt, AppLocalization.phrase("Order completed")),
            (.expired, expiredAt, AppLocalization.phrase("Order expired")),
        ]

        return derived.compactMap { stage, timestamp, detail in
            guard timestamp != nil else { return nil }
            return OrderTimelineEntry(id: stage.rawValue, stage: stage, timestamp: timestamp, detail: detail)
        }
    }

    fileprivate static func stage(from rawValue: String?) -> OrderTimelineStage? {
        switch rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_") {
        case "created", "open", "pending":
            return .created
        case "claimed":
            return .claimed
        case "processing", "in_progress", "working", "running":
            return .processing
        case "submitted", "review", "pending_review":
            return .submitted
        case "completed", "accepted", "settled", "done":
            return .completed
        case "expired", "failed", "cancelled", "canceled":
            return .expired
        default:
            return nil
        }
    }

    fileprivate static func uniqueObjects(_ values: [JSONValue?]) -> [JSONValue] {
        var seen = Set<JSONValue>()
        var result: [JSONValue] = []

        for value in values.compactMap({ $0 }) {
            guard case .object = value else { continue }
            if seen.insert(value).inserted {
                result.append(value)
            }
        }

        return result
    }

    fileprivate static func pickPrimaryContainer(from root: JSONValue) -> JSONValue {
        let candidates = uniqueObjects(
            [
                root.value(at: ["data", "task"]),
                root.value(at: ["task"]),
                root.value(at: ["data", "order"]),
                root.value(at: ["order"]),
                root.value(at: ["data"]),
                root,
            ]
        )

        let taskKeys = ["task_id", "order_id", "submissions", "question", "status", "listing_id"]
        return candidates.first(where: { candidate in
            taskKeys.contains { candidate.value(at: [$0]) != nil }
        }) ?? root
    }

    fileprivate static func string(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> String? {
        for container in preferred {
            if let value = container.directString(forKeys: keys)?.nonEmpty {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveString(forKeys: keys)?.nonEmpty {
                return value
            }
        }
        return nil
    }

    fileprivate static func int(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> Int? {
        for container in preferred {
            if let value = container.directInt(forKeys: keys) {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveInt(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    fileprivate static func date(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> Date? {
        for container in preferred {
            if let value = container.directDate(forKeys: keys) {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveDate(forKeys: keys) {
                return value
            }
        }
        return nil
    }
}

private struct ServiceRatingDecodedPayload {
    let ratingID: String
    let rating: Int
    let comment: String?
    let taskID: String?
    let authorNodeID: String?
    let authorAlias: String?
    let createdAt: Date?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let primary = OrderDecodedPayload.uniqueObjects(
            [
                root.value(at: ["data", "rating"]),
                root.value(at: ["rating"]),
                root.value(at: ["data", "review"]),
                root.value(at: ["review"]),
                root.value(at: ["data"]),
                root,
            ]
        ).first ?? root

        let containers = OrderDecodedPayload.uniqueObjects(
            [
                primary,
                root.value(at: ["data"]),
                root.value(at: ["rating"]),
                root.value(at: ["review"]),
                root,
            ]
        )

        let authorContainers = OrderDecodedPayload.uniqueObjects(
            containers.flatMap { container in
                [
                    container.value(at: ["author"]),
                    container.value(at: ["user"]),
                    container.value(at: ["rater"]),
                    container.value(at: ["buyer"]),
                    container.value(at: ["sender"]),
                ]
            }
        )

        let resolvedRatingID = OrderDecodedPayload.string(
            keys: ["rating_id", "id", "task_id"],
            preferred: containers,
            recursive: containers
        )
        let resolvedRating = OrderDecodedPayload.int(
            keys: ["rating", "score", "stars", "value"],
            preferred: containers,
            recursive: containers
        )

        guard let ratingID = resolvedRatingID?.nonEmpty,
              let rating = resolvedRating else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing service rating identifier or score.")
            )
        }

        self.ratingID = ratingID
        self.rating = rating
        comment = OrderDecodedPayload.string(
            keys: ["comment", "review", "feedback", "content"],
            preferred: containers,
            recursive: containers
        )
        taskID = OrderDecodedPayload.string(keys: ["task_id", "order_id"], preferred: containers, recursive: containers)
        authorNodeID = OrderDecodedPayload.string(keys: ["node_id", "sender_id"], preferred: authorContainers, recursive: containers)
        authorAlias = OrderDecodedPayload.string(keys: ["alias", "name", "title"], preferred: authorContainers, recursive: authorContainers)
        createdAt = OrderDecodedPayload.date(keys: ["created_at", "rated_at", "updated_at"], preferred: containers, recursive: containers)
    }
}

private enum KnowledgeGraphDecodingSupport {
    static func containers(from root: JSONValue, preferredPaths: [[String]]) -> [JSONValue] {
        let values = preferredPaths.map { path -> JSONValue? in
            path.isEmpty ? root : root.value(at: path)
        }
        return OrderDecodedPayload.uniqueObjects(values + [root])
    }

    static func decodeArray<T: Decodable>(of type: T.Type, from containers: [JSONValue], candidateKeys: [String]) -> [T] {
        for container in containers {
            for key in candidateKeys {
                guard let values = container.value(at: [key])?.arrayValue else {
                    continue
                }
                let decoded = values.compactMap { value -> T? in
                    guard let data = try? JSONSerialization.data(withJSONObject: value.foundationObject) else {
                        return nil
                    }
                    return try? JSONDecoder.graphDecoder.decode(T.self, from: data)
                }
                if decoded.isEmpty == false {
                    return decoded
                }
            }
        }
        return []
    }

    static func properties(from containers: [JSONValue], excluding keys: Set<String>) -> [KnowledgeGraphPropertyLine] {
        var merged: [String: KnowledgeGraphPropertyLine] = [:]

        for container in containers {
            guard let object = container.objectValue else {
                continue
            }
            for key in object.keys.sorted() where keys.contains(key) == false {
                let value = object[key]
                let rendered = value?.compactDescription.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard rendered.isEmpty == false else {
                    continue
                }
                merged[key] = KnowledgeGraphPropertyLine(key: key, value: rendered)
            }
        }

        return merged.values.sorted { $0.key < $1.key }
    }

    static func stringArray(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> [String] {
        for container in preferred {
            if let values = container.directStringArray(forKeys: keys), values.isEmpty == false {
                return values
            }
        }
        for container in recursive {
            if let values = container.recursiveStringArray(forKeys: keys), values.isEmpty == false {
                return values
            }
        }
        return []
    }

    static func double(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> Double? {
        for container in preferred {
            if let value = container.directDouble(forKeys: keys) {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveDouble(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    static func bool(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> Bool? {
        for container in preferred {
            if let value = container.directBool(forKeys: keys) {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveBool(forKeys: keys) {
                return value
            }
        }
        return nil
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    func value(at path: [String]) -> JSONValue? {
        guard path.isEmpty == false else { return self }
        var current: JSONValue? = self
        for key in path {
            guard let object = current?.objectValue else { return nil }
            current = object[key]
        }
        return current
    }

    func directString(forKeys keys: [String]) -> String? {
        for key in keys {
            if let value = value(at: [key])?.lossyString {
                return value
            }
        }
        return nil
    }

    func recursiveString(forKeys keys: [String]) -> String? {
        if let direct = directString(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveString(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    func directStringArray(forKeys keys: [String]) -> [String]? {
        for key in keys {
            guard let value = value(at: [key]) else { continue }
            switch value {
            case .array(let items):
                let strings = items.compactMap(\.lossyString).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let filtered = strings.filter { $0.isEmpty == false }
                if filtered.isEmpty == false {
                    return filtered
                }
            case .string(let item):
                let values = item
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                if values.isEmpty == false {
                    return values
                }
            default:
                continue
            }
        }
        return nil
    }

    func recursiveStringArray(forKeys keys: [String]) -> [String]? {
        if let direct = directStringArray(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveStringArray(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    func directInt(forKeys keys: [String]) -> Int? {
        for key in keys {
            if let value = value(at: [key])?.lossyInt {
                return value
            }
        }
        return nil
    }

    func directDouble(forKeys keys: [String]) -> Double? {
        for key in keys {
            if let value = value(at: [key])?.lossyDouble {
                return value
            }
        }
        return nil
    }

    func recursiveDouble(forKeys keys: [String]) -> Double? {
        if let direct = directDouble(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveDouble(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    func directBool(forKeys keys: [String]) -> Bool? {
        for key in keys {
            if let value = value(at: [key])?.lossyBool {
                return value
            }
        }
        return nil
    }

    func recursiveBool(forKeys keys: [String]) -> Bool? {
        if let direct = directBool(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveBool(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    func recursiveInt(forKeys keys: [String]) -> Int? {
        if let direct = directInt(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveInt(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    func directDate(forKeys keys: [String]) -> Date? {
        for key in keys {
            if let value = value(at: [key])?.lossyDate {
                return value
            }
        }
        return nil
    }

    func recursiveDate(forKeys keys: [String]) -> Date? {
        if let direct = directDate(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveDate(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    var childValues: [JSONValue] {
        switch self {
        case .object(let value):
            return Array(value.values)
        case .array(let value):
            return value
        default:
            return []
        }
    }

    var lossyString: String? {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        default:
            return nil
        }
    }

    var lossyInt: Int? {
        switch self {
        case .integer(let value):
            return value
        case .double(let value):
            return Int(value.rounded())
        case .string(let value):
            return Int(value)
        default:
            return nil
        }
    }

    var lossyDouble: Double? {
        switch self {
        case .integer(let value):
            return Double(value)
        case .double(let value):
            return value
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var lossyBool: Bool? {
        switch self {
        case .boolean(let value):
            return value
        case .integer(let value):
            return value != 0
        case .double(let value):
            return value != 0
        case .string(let value):
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "enabled", "available", "allowed":
                return true
            case "false", "no", "0", "disabled", "unavailable", "denied":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    var lossyDate: Date? {
        switch self {
        case .string(let value):
            return OrderDateParser.parse(value)
        case .integer(let value):
            return OrderDateParser.parse(epoch: Double(value))
        case .double(let value):
            return OrderDateParser.parse(epoch: value)
        default:
            return nil
        }
    }
}

private extension JSONValue {
    var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .boolean(let value):
            return value
        case .object(let value):
            return value.mapValues(\.foundationObject)
        case .array(let value):
            return value.map(\.foundationObject)
        case .null:
            return NSNull()
        }
    }
}

private extension JSONDecoder {
    static let graphDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let value = try? container.decode(String.self),
               let parsed = OrderDateParser.parse(value) {
                return parsed
            }
            if let value = try? container.decode(Double.self),
               let parsed = OrderDateParser.parse(epoch: value) {
                return parsed
            }
            if let value = try? container.decode(Int.self),
               let parsed = OrderDateParser.parse(epoch: Double(value)) {
                return parsed
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported graph date value.")
        }
        return decoder
    }()
}

private enum OrderDateParser {
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        iso8601Fractional.date(from: value) ?? iso8601.date(from: value)
    }

    static func parse(epoch rawValue: Double) -> Date? {
        guard rawValue.isFinite else { return nil }
        let seconds = rawValue > 10_000_000_000 ? rawValue / 1000 : rawValue
        return Date(timeIntervalSince1970: seconds)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value.rounded())
        }
        if let value = try? decodeIfPresent(String.self, forKey: key)?.nonEmpty {
            return Int(value)
        }
        return nil
    }

    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key)?.nonEmpty {
            if value.hasSuffix("%") {
                return Double(value.dropLast())
            }
            return Double(value)
        }
        return nil
    }

    func decodeLossyStringArrayIfPresent(forKey key: Key) -> [String]? {
        if let value = try? decodeIfPresent([String].self, forKey: key) {
            return value
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let value = try? decodeIfPresent(String.self, forKey: key)?.nonEmpty {
            return value
                .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return nil
    }
}
