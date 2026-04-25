import Foundation

protocol EvoMapClientProtocol {
    func hello(request: EvoMapHelloRequest) async throws -> EvoMapHelloResponse
    func heartbeat(request: EvoMapHeartbeatRequest) async throws -> EvoMapHeartbeatResponse
    func nodeProfile(request: EvoMapNodeProfileRequest) async throws -> EvoMapNodeProfileResponse
    func accountBalance(request: EvoMapAccountBalanceRequest) async throws -> EvoMapAccountBalanceResponse
    func listBountyTasks(request: EvoMapBountyTaskListRequest) async throws -> EvoMapBountyTaskListResponse
    func listPublicBountyTasks(request: EvoMapPublicBountyTaskListRequest) async throws -> EvoMapBountyTaskListResponse
    func bountyDetail(request: EvoMapBountyDetailRequest) async throws -> EvoMapBountyDetailResponse
    func claimBountyTask(request: EvoMapBountyTaskClaimRequest) async throws -> EvoMapTaskMutationResponse
    func myBountyTasks(request: EvoMapMyBountyTasksRequest) async throws -> EvoMapMyBountyTasksResponse
    func publishAssetBundle(request: EvoMapPublishBundleRequest) async throws -> EvoMapPublishBundleResponse
    func completeBountyTask(request: EvoMapBountyTaskCompleteRequest) async throws -> EvoMapTaskMutationResponse
    func publishSkill(request: EvoMapSkillStoreMutationRequest) async throws -> EvoMapSkillStoreMutationResponse
    func updateSkill(request: EvoMapSkillStoreMutationRequest) async throws -> EvoMapSkillStoreMutationResponse
    func setSkillVisibility(request: EvoMapSkillStoreVisibilityRequest) async throws -> EvoMapSkillStoreMutationResponse
    func rollbackSkill(request: EvoMapSkillStoreRollbackRequest) async throws -> EvoMapSkillStoreMutationResponse
    func deleteSkillVersion(request: EvoMapSkillStoreDeleteVersionRequest) async throws -> EvoMapSkillStoreMutationResponse
    func deleteSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse
    func restoreSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse
    func permanentlyDeleteSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse
    func recycleBin(request: EvoMapSkillStoreRecycleBinRequest) async throws -> EvoMapSkillStoreRecycleBinResponse
    func skillStoreStatus(baseURL: String) async throws -> EvoMapSkillStorePublicStatusResponse
    func listSkills(request: EvoMapSkillStoreListRequest) async throws -> EvoMapSkillStoreListResponse
    func skillDetail(request: EvoMapSkillStoreDetailRequest) async throws -> RemoteSkillDetail
    func skillVersions(request: EvoMapSkillStoreVersionsRequest) async throws -> EvoMapSkillStoreVersionsResponse
    func downloadSkill(request: EvoMapSkillStoreDownloadRequest) async throws -> EvoMapSkillStoreDownloadResponse
    func listServices(request: EvoMapServiceListRequest) async throws -> EvoMapServiceListResponse
    func searchServices(request: EvoMapServiceSearchRequest) async throws -> EvoMapServiceListResponse
    func serviceDetail(request: EvoMapServiceDetailRequest) async throws -> RemoteServiceDetail
    func publishService(request: EvoMapServicePublishRequest) async throws -> EvoMapServiceMutationResponse
    func updateService(request: EvoMapServiceUpdateRequest) async throws -> EvoMapServiceMutationResponse
    func archiveService(request: EvoMapServiceArchiveRequest) async throws -> EvoMapServiceMutationResponse
    func serviceRatings(request: EvoMapServiceRatingsRequest) async throws -> EvoMapServiceRatingsResponse
    func rateService(request: EvoMapServiceRateRequest) async throws -> EvoMapServiceRateResponse
    func placeServiceOrder(request: EvoMapServiceOrderRequest) async throws -> RemoteOrderPlacement
    func orderDetail(request: EvoMapTaskDetailRequest) async throws -> RemoteOrderDetail
    func acceptOrderSubmission(request: EvoMapTaskAcceptSubmissionRequest) async throws -> EvoMapTaskMutationResponse
    func knowledgeGraphStatus(request: EvoMapKnowledgeGraphStatusRequest) async throws -> KnowledgeGraphStatusSnapshot
    func knowledgeGraphMyGraph(request: EvoMapKnowledgeGraphMyGraphRequest) async throws -> KnowledgeGraphSnapshot
    func queryKnowledgeGraph(request: EvoMapKnowledgeGraphQueryRequest) async throws -> KnowledgeGraphSearchResult
    func ingestKnowledgeGraph(request: EvoMapKnowledgeGraphIngestRequest) async throws -> EvoMapKnowledgeGraphIngestResponse
}

struct EvoMapHelloRequest {
    let baseURL: String
    let senderID: String
    let payload: EvoMapHelloPayload
}

struct EvoMapHelloPayload: Encodable {
    let capabilities: [String: Bool]
    let model: String
    let geneCount: Int
    let capsuleCount: Int
    let envFingerprint: [String: String]
    let referrer: String?
    let identityDoc: String?
    let constitution: String?
}

struct EvoMapHeartbeatRequest {
    let baseURL: String
    let senderID: String
    let nodeSecret: String
    let payload: EvoMapHeartbeatPayload
}

struct EvoMapHeartbeatPayload: Encodable {
    let nodeID: String
    let senderID: String
    let geneCount: Int
    let capsuleCount: Int
    let envFingerprint: [String: String]
    let fingerprint: [String: String]
    let workerEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case senderID = "sender_id"
        case geneCount = "gene_count"
        case capsuleCount = "capsule_count"
        case envFingerprint = "env_fingerprint"
        case fingerprint
        case workerEnabled = "worker_enabled"
    }
}

struct EvoMapAccountBalanceRequest {
    let baseURL: String
    let apiKey: String
}

struct EvoMapNodeProfileRequest {
    let baseURL: String
    let nodeID: String
}

struct EvoMapBountyTaskListRequest {
    let baseURL: String
    let nodeSecret: String
    let minBounty: Int
    let limit: Int
}

struct EvoMapPublicBountyTaskListRequest {
    let baseURL: String
    let limit: Int
    let page: Int
    let hasBounty: Bool
}

struct EvoMapBountyDetailRequest {
    let baseURL: String
    let bountyID: String
}

struct EvoMapBountyTaskClaimRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapBountyTaskClaimPayload
}

struct EvoMapMyBountyTasksRequest {
    let baseURL: String
    let nodeID: String
    let nodeSecret: String?
}

struct EvoMapPublishBundleRequest {
    let baseURL: String
    let senderID: String
    let nodeSecret: String
    let payload: EvoMapPublishBundlePayload
}

struct EvoMapBountyTaskCompleteRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapBountyTaskCompletePayload
}

struct EvoMapSkillStoreMutationRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreMutationPayload
}

struct EvoMapSkillStoreListRequest {
    let baseURL: String
    let keyword: String?
    let page: Int
    let limit: Int
    let sort: String?
    let featured: Bool?
}

struct EvoMapSkillStoreDetailRequest {
    let baseURL: String
    let skillID: String
}

struct EvoMapSkillStoreVersionsRequest {
    let baseURL: String
    let skillID: String
}

struct EvoMapSkillStoreDownloadRequest {
    let baseURL: String
    let skillID: String
    let senderID: String
    let nodeSecret: String
}

struct EvoMapSkillStoreVisibilityRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreVisibilityPayload
}

struct EvoMapSkillStoreRollbackRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreRollbackPayload
}

struct EvoMapSkillStoreDeleteVersionRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreDeleteVersionPayload
}

struct EvoMapSkillStoreDeleteRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreDeletePayload
}

struct EvoMapSkillStoreRecycleBinRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapSkillStoreRecycleBinPayload
}

struct EvoMapServiceListRequest {
    let baseURL: String
}

struct EvoMapServiceSearchRequest {
    let baseURL: String
    let query: String
}

struct EvoMapServiceDetailRequest {
    let baseURL: String
    let listingID: String
}

struct EvoMapServicePublishRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapServicePublishPayload
}

struct EvoMapServiceUpdateRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapServiceUpdatePayload
}

struct EvoMapServiceArchiveRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapServiceArchivePayload
}

struct EvoMapServiceRatingsRequest {
    let baseURL: String
    let listingID: String
    let page: Int?
    let limit: Int?
}

struct EvoMapServiceRateRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapServiceRatePayload
}

struct EvoMapServiceOrderRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapServiceOrderPayload
}

struct EvoMapTaskDetailRequest {
    let baseURL: String
    let taskID: String
    let nodeSecret: String
}

struct EvoMapTaskAcceptSubmissionRequest {
    let baseURL: String
    let nodeSecret: String
    let payload: EvoMapTaskAcceptSubmissionPayload
}

struct EvoMapKnowledgeGraphStatusRequest {
    let baseURL: String
    let apiKey: String
}

struct EvoMapKnowledgeGraphMyGraphRequest {
    let baseURL: String
    let apiKey: String
}

struct EvoMapKnowledgeGraphQueryRequest {
    let baseURL: String
    let apiKey: String
    let payload: EvoMapKnowledgeGraphQueryPayload
}

struct EvoMapKnowledgeGraphIngestRequest {
    let baseURL: String
    let apiKey: String
    let payload: EvoMapKnowledgeGraphIngestPayload
}

struct EvoMapSkillStoreMutationPayload: Encodable {
    struct BundledFile: Encodable {
        let name: String
        let content: String
    }

    let senderID: String
    let skillID: String
    let content: String
    let category: String?
    let tags: [String]
    let bundledFiles: [BundledFile]?
    let changelog: String?

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case skillID = "skill_id"
        case content
        case category
        case tags
        case bundledFiles = "bundled_files"
        case changelog
    }
}

struct EvoMapSkillStoreDownloadPayload: Encodable {
    let senderID: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
    }
}

struct EvoMapSkillStoreVisibilityPayload: Encodable {
    let senderID: String
    let skillID: String
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case skillID = "skill_id"
        case visibility
    }
}

struct EvoMapSkillStoreRollbackPayload: Encodable {
    let senderID: String
    let skillID: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case skillID = "skill_id"
        case version
    }
}

struct EvoMapSkillStoreDeleteVersionPayload: Encodable {
    let senderID: String
    let skillID: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case skillID = "skill_id"
        case version
    }
}

struct EvoMapSkillStoreDeletePayload: Encodable {
    let senderID: String
    let skillID: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case skillID = "skill_id"
    }
}

struct EvoMapSkillStoreRecycleBinPayload: Encodable {
    let senderID: String
    let page: Int?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case page
        case limit
    }
}

struct EvoMapServicePublishPayload: Encodable {
    let senderID: String
    let title: String
    let description: String
    let capabilities: [String]
    let pricePerTask: Int
    let maxConcurrent: Int
    let useCases: [String]
    let recipeID: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case title
        case description
        case capabilities
        case pricePerTask = "price_per_task"
        case maxConcurrent = "max_concurrent"
        case useCases = "use_cases"
        case recipeID = "recipe_id"
        case status
    }
}

struct EvoMapServiceUpdatePayload: Encodable {
    let senderID: String
    let listingID: String
    let title: String?
    let description: String?
    let capabilities: [String]?
    let pricePerTask: Int?
    let maxConcurrent: Int?
    let useCases: [String]?
    let recipeID: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case listingID = "listing_id"
        case title
        case description
        case capabilities
        case pricePerTask = "price_per_task"
        case maxConcurrent = "max_concurrent"
        case useCases = "use_cases"
        case recipeID = "recipe_id"
        case status
    }
}

struct EvoMapServiceArchivePayload: Encodable {
    let senderID: String
    let listingID: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case listingID = "listing_id"
    }
}

struct EvoMapServiceRatePayload: Encodable {
    let senderID: String
    let listingID: String
    let rating: Int
    let taskID: String?
    let comment: String?

    private enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case listingID = "listing_id"
        case rating
        case taskID = "task_id"
        case comment
        case review
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(senderID, forKey: .senderID)
        try container.encode(listingID, forKey: .listingID)
        try container.encode(rating, forKey: .rating)
        try container.encodeIfPresent(taskID, forKey: .taskID)
        if let comment {
            try container.encode(comment, forKey: .comment)
            try container.encode(comment, forKey: .review)
        }
    }
}

struct EvoMapServiceOrderPayload: Encodable {
    let senderID: String
    let listingID: String
    let question: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case listingID = "listing_id"
        case question
    }
}

struct EvoMapTaskAcceptSubmissionPayload: Encodable {
    let senderID: String
    let taskID: String
    let submissionID: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case taskID = "task_id"
        case submissionID = "submission_id"
    }
}

struct EvoMapBountyTaskClaimPayload: Encodable {
    let senderID: String
    let nodeID: String
    let taskID: String

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case nodeID = "node_id"
        case taskID = "task_id"
    }
}

struct EvoMapBountyTaskCompletePayload: Encodable {
    let senderID: String
    let nodeID: String
    let taskID: String
    let assetID: String
    let followupQuestion: String?

    enum CodingKeys: String, CodingKey {
        case senderID = "sender_id"
        case nodeID = "node_id"
        case taskID = "task_id"
        case assetID = "asset_id"
        case followupQuestion = "followup_question"
    }
}

struct EvoMapPublishBundlePayload: Encodable, Hashable {
    var assets: [EvoMapPublishAsset]
}

struct EvoMapPublishAsset: Encodable, Hashable {
    var type: String
    var schemaVersion: String?
    var id: String?
    var category: String?
    var signalsMatch: [String]?
    var summary: String
    var preconditions: [String]?
    var strategy: [String]?
    var constraints: EvoMapPublishAssetConstraints?
    var validation: [String]?
    var trigger: [String]?
    var gene: String?
    var confidence: Double?
    var blastRadius: EvoMapPublishAssetBlastRadius?
    var outcome: EvoMapPublishAssetOutcome?
    var successStreak: Int?
    var envFingerprint: [String: String]?
    var modelName: String?
    var domain: String?
    var assetID: String?

    enum CodingKeys: String, CodingKey {
        case type
        case schemaVersion = "schema_version"
        case id
        case category
        case signalsMatch = "signals_match"
        case summary
        case preconditions
        case strategy
        case constraints
        case validation
        case trigger
        case gene
        case confidence
        case blastRadius = "blast_radius"
        case outcome
        case successStreak = "success_streak"
        case envFingerprint = "env_fingerprint"
        case modelName = "model_name"
        case domain
        case assetID = "asset_id"
    }
}

struct EvoMapPublishAssetConstraints: Encodable, Hashable {
    var maxFiles: Int
    var forbiddenPaths: [String]

    enum CodingKeys: String, CodingKey {
        case maxFiles = "max_files"
        case forbiddenPaths = "forbidden_paths"
    }
}

struct EvoMapPublishAssetBlastRadius: Encodable, Hashable {
    var files: Int
    var lines: Int
}

struct EvoMapPublishAssetOutcome: Encodable, Hashable {
    var status: String
    var score: Double
}

struct EvoMapKnowledgeGraphQueryPayload: Encodable {
    let query: String
    let type: String
}

struct EvoMapKnowledgeGraphIngestPayload: Encodable {
    struct Entity: Encodable {
        let name: String
        let type: String
        let description: String

        private enum CodingKeys: String, CodingKey {
            case name
            case type
            case entityType = "entity_type"
            case description
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(type, forKey: .type)
            try container.encode(type, forKey: .entityType)
            try container.encode(description, forKey: .description)
        }
    }

    struct Relationship: Encodable {
        let sourceName: String
        let relation: String
        let targetName: String

        private enum CodingKeys: String, CodingKey {
            case source
            case from
            case sourceName = "source_name"
            case target
            case to
            case targetName = "target_name"
            case relation
            case relationship
            case type
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sourceName, forKey: .source)
            try container.encode(sourceName, forKey: .from)
            try container.encode(sourceName, forKey: .sourceName)
            try container.encode(targetName, forKey: .target)
            try container.encode(targetName, forKey: .to)
            try container.encode(targetName, forKey: .targetName)
            try container.encode(relation, forKey: .relation)
            try container.encode(relation, forKey: .relationship)
            try container.encode(relation, forKey: .type)
        }
    }

    let entities: [Entity]
    let relationships: [Relationship]

    private enum CodingKeys: String, CodingKey {
        case entities
        case relationships
        case relations
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if entities.isEmpty == false {
            try container.encode(entities, forKey: .entities)
        }
        if relationships.isEmpty == false {
            try container.encode(relationships, forKey: .relationships)
            try container.encode(relationships, forKey: .relations)
        }
    }
}

struct A2AMessageEnvelope<Payload: Encodable>: Encodable {
    let protocolName = "gep-a2a"
    let protocolVersion = "1.0.0"
    let messageType: String
    let messageID: String
    let senderID: String
    let timestamp: String
    let payload: Payload

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion = "protocol_version"
        case messageType = "message_type"
        case messageID = "message_id"
        case senderID = "sender_id"
        case timestamp
        case payload
    }
}

struct EvoMapHelloResponse: Decodable {
    let status: String
    let yourNodeID: String
    let hubNodeID: String?
    let nodeSecret: String?
    let nodeSecretStatus: String?
    let claimCode: String?
    let claimURL: String?
    let claimed: Bool?
    let claimState: String?
    let claimStatus: String?
    let bindingStatus: String?
    let claimedAt: String?
    let creditBalance: Int?
    let survivalStatus: String?
    let referralCode: String?
    let recommendedTasks: [EvoMapTaskSummary]?
    let networkManifest: EvoMapNetworkManifest?
    let migratedFrom: String?
    let mergeHint: String?
    let heartbeatIntervalMS: Int?
    let heartbeatEndpoint: String?

    enum CodingKeys: String, CodingKey {
        case status
        case yourNodeID = "your_node_id"
        case hubNodeID = "hub_node_id"
        case nodeSecret = "node_secret"
        case nodeSecretStatus = "node_secret_status"
        case claimCode = "claim_code"
        case claimURL = "claim_url"
        case claimed
        case claimState = "claim_state"
        case claimStatus = "claim_status"
        case bindingStatus = "binding_status"
        case claimedAt = "claimed_at"
        case creditBalance = "credit_balance"
        case survivalStatus = "survival_status"
        case referralCode = "referral_code"
        case recommendedTasks = "recommended_tasks"
        case networkManifest = "network_manifest"
        case migratedFrom = "migrated_from"
        case mergeHint = "merge_hint"
        case heartbeatIntervalMS = "heartbeat_interval_ms"
        case heartbeatEndpoint = "heartbeat_endpoint"
    }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let payload = Self.responsePayload(from: root)
        let preferred = payload == root ? [payload] : [payload, root]

        status = Self.string(keys: ["status", "state"], preferred: preferred) ?? "acknowledged"
        guard let nodeID = Self.string(
            keys: ["your_node_id", "yourNodeID", "node_id", "nodeID", "sender_id", "senderID", "id"],
            preferred: [payload]
        ) else {
            let shape = Self.responseShapeDescription(root)
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "EvoMap hello response is missing your_node_id. \(shape)"
                )
            )
        }

        yourNodeID = nodeID
        hubNodeID = Self.string(keys: ["hub_node_id", "hubNodeID"], preferred: preferred)
        nodeSecret = Self.string(keys: ["node_secret", "nodeSecret"], preferred: preferred)
        nodeSecretStatus = Self.string(keys: ["node_secret_status", "nodeSecretStatus"], preferred: preferred)
        claimCode = Self.string(keys: ["claim_code", "claimCode"], preferred: preferred)
        claimURL = Self.string(keys: ["claim_url", "claimURL"], preferred: preferred)
        claimed = Self.bool(
            keys: [
                "claimed", "is_claimed", "isClaimed",
                "account_claimed", "accountClaimed",
                "account_bound", "accountBound",
                "bound", "node_claimed", "nodeClaimed",
            ],
            preferred: preferred
        )
        claimState = Self.string(
            keys: ["claim_state", "claimState", "node_claim_state", "nodeClaimState"],
            preferred: preferred
        )
        claimStatus = Self.string(
            keys: ["claim_status", "claimStatus", "account_claim_status", "accountClaimStatus"],
            preferred: preferred
        )
        bindingStatus = Self.string(
            keys: ["binding_status", "bindingStatus", "account_binding_status", "accountBindingStatus"],
            preferred: preferred
        )
        claimedAt = Self.string(keys: ["claimed_at", "claimedAt"], preferred: preferred)
        creditBalance = Self.int(keys: ["credit_balance", "creditBalance", "balance", "credits"], preferred: preferred)
        survivalStatus = Self.string(keys: ["survival_status", "survivalStatus"], preferred: preferred)
        referralCode = Self.string(keys: ["referral_code", "referralCode"], preferred: preferred)
        recommendedTasks = Self.taskSummaries(from: Self.array(
            keys: ["recommended_tasks", "recommendedTasks", "available_tasks", "available_work", "tasks"],
            preferred: preferred
        ))
        networkManifest = Self.networkManifest(from: Self.value(
            keys: ["network_manifest", "networkManifest"],
            preferred: preferred
        ))
        migratedFrom = Self.string(keys: ["migrated_from", "migratedFrom"], preferred: preferred)
        mergeHint = Self.string(keys: ["merge_hint", "mergeHint"], preferred: preferred)
        heartbeatIntervalMS = Self.int(keys: ["heartbeat_interval_ms", "heartbeatIntervalMS"], preferred: preferred)
        heartbeatEndpoint = Self.string(keys: ["heartbeat_endpoint", "heartbeatEndpoint"], preferred: preferred)
    }

    private static func responsePayload(from root: JSONValue) -> JSONValue {
        for path in [
            ["payload"],
            ["data", "payload"],
            ["result", "payload"],
            ["data"],
            ["result"],
        ] {
            if let value = root.value(at: path) {
                return value
            }
        }
        return root
    }

    private static func string(keys: [String], preferred containers: [JSONValue]) -> String? {
        for container in containers {
            if let value = container.directString(forKeys: keys)?.nonEmpty {
                return value
            }
        }
        return nil
    }

    private static func int(keys: [String], preferred containers: [JSONValue]) -> Int? {
        for container in containers {
            if let value = container.directInt(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func bool(keys: [String], preferred containers: [JSONValue]) -> Bool? {
        for container in containers {
            if let value = container.directBool(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func array(keys: [String], preferred containers: [JSONValue]) -> [JSONValue]? {
        for container in containers {
            if let value = container.directArray(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func value(keys: [String], preferred containers: [JSONValue]) -> JSONValue? {
        for container in containers {
            for key in keys {
                if let value = container.value(at: [key]) {
                    return value
                }
            }
        }
        return nil
    }

    private static func taskSummaries(from values: [JSONValue]?) -> [EvoMapTaskSummary]? {
        let summaries = values?.compactMap { value -> EvoMapTaskSummary? in
            guard value.objectValue != nil else { return nil }
            return EvoMapTaskSummary(
                taskID: value.recursiveString(forKeys: ["task_id", "taskID", "id"]),
                title: value.recursiveString(forKeys: ["title", "name", "question"]),
                summary: value.recursiveString(forKeys: ["summary", "description", "body", "prompt"]),
                bountyCredits: value.recursiveInt(forKeys: ["bounty_credits", "bountyCredits", "bounty"]),
                rewardCredits: value.recursiveInt(forKeys: ["reward_credits", "rewardCredits", "reward"]),
                domain: value.recursiveString(forKeys: ["domain", "category", "topic"]),
                kind: value.recursiveString(forKeys: ["kind", "type"])
            )
        } ?? []
        return summaries.isEmpty ? nil : summaries
    }

    private static func networkManifest(from value: JSONValue?) -> EvoMapNetworkManifest? {
        guard let value else { return nil }
        if value.objectValue != nil {
            return EvoMapNetworkManifest(
                name: value.recursiveString(forKeys: ["name", "title"]),
                connect: value.recursiveString(forKeys: ["connect", "url", "endpoint"])
            )
        }
        return value.lossyString.map { EvoMapNetworkManifest(name: $0, connect: nil) }
    }

    private static func responseShapeDescription(_ root: JSONValue) -> String {
        var parts: [String] = []
        if let object = root.objectValue {
            parts.append("top-level keys: \(object.keys.sorted().joined(separator: ", "))")
        }
        if let payload = root.value(at: ["payload"])?.objectValue {
            parts.append("payload keys: \(payload.keys.sorted().joined(separator: ", "))")
        }
        return parts.isEmpty ? "response: \(root.compactDescription)" : parts.joined(separator: "; ")
    }
}

struct EvoMapTaskSummary: Decodable, Hashable {
    let taskID: String?
    let title: String?
    let summary: String?
    let bountyCredits: Int?
    let rewardCredits: Int?
    let domain: String?
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case title
        case summary
        case bountyCredits = "bounty_credits"
        case rewardCredits = "reward_credits"
        case domain
        case kind
    }

    init(
        taskID: String?,
        title: String?,
        summary: String?,
        bountyCredits: Int?,
        rewardCredits: Int?,
        domain: String?,
        kind: String?
    ) {
        self.taskID = taskID
        self.title = title
        self.summary = summary
        self.bountyCredits = bountyCredits
        self.rewardCredits = rewardCredits
        self.domain = domain
        self.kind = kind
    }

    fileprivate init(value: JSONValue) {
        self.init(
            taskID: value.recursiveString(forKeys: ["task_id", "taskID", "id"]),
            title: value.recursiveString(forKeys: ["title", "name", "question"]),
            summary: value.recursiveString(forKeys: ["summary", "description", "body", "prompt"]),
            bountyCredits: value.recursiveInt(forKeys: ["bounty_credits", "bountyCredits", "bounty"]),
            rewardCredits: value.recursiveInt(forKeys: ["reward_credits", "rewardCredits", "reward", "credits"]),
            domain: value.recursiveString(forKeys: ["domain", "category", "topic"]),
            kind: value.recursiveString(forKeys: ["kind", "type"])
        )
    }
}

struct EvoMapNetworkManifest: Decodable, Hashable {
    let name: String?
    let connect: String?
}

struct EvoMapHeartbeatResponse: Decodable {
    let status: String?
    let creditBalance: Int?
    let survivalStatus: String?
    let claimed: Bool?
    let claimState: String?
    let claimStatus: String?
    let bindingStatus: String?
    let claimedAt: String?
    let nextHeartbeatMS: Int?
    let availableTasks: [EvoMapTaskSummary]?
    let availableWork: [EvoMapTaskSummary]?
    let overdueTasks: [EvoMapOverdueTask]?
    let pendingEvents: [EvoMapPendingEvent]?
    let peers: [EvoMapPeer]?
    let accountability: EvoMapAccountability?
    let skillStore: EvoMapSkillStoreStatus?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case creditBalance = "credit_balance"
        case survivalStatus = "survival_status"
        case claimed
        case claimState = "claim_state"
        case claimStatus = "claim_status"
        case bindingStatus = "binding_status"
        case claimedAt = "claimed_at"
        case nextHeartbeatMS = "next_heartbeat_ms"
        case availableTasks = "available_tasks"
        case availableWork = "available_work"
        case overdueTasks = "overdue_tasks"
        case pendingEvents = "pending_events"
        case peers
        case accountability
        case skillStore = "skill_store"
        case message
    }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let payload = Self.responsePayload(from: root)
        let preferred = payload == root ? [payload] : [payload, root]

        status = Self.string(keys: ["status", "state"], preferred: preferred)
        creditBalance = Self.int(keys: ["credit_balance", "creditBalance", "balance", "credits"], preferred: preferred)
        survivalStatus = Self.string(keys: ["survival_status", "survivalStatus"], preferred: preferred)
        claimed = Self.bool(
            keys: [
                "claimed", "is_claimed", "isClaimed",
                "account_claimed", "accountClaimed",
                "account_bound", "accountBound",
                "bound", "node_claimed", "nodeClaimed",
            ],
            preferred: preferred
        )
        claimState = Self.string(
            keys: ["claim_state", "claimState", "node_claim_state", "nodeClaimState"],
            preferred: preferred
        )
        claimStatus = Self.string(
            keys: ["claim_status", "claimStatus", "account_claim_status", "accountClaimStatus"],
            preferred: preferred
        )
        bindingStatus = Self.string(
            keys: ["binding_status", "bindingStatus", "account_binding_status", "accountBindingStatus"],
            preferred: preferred
        )
        claimedAt = Self.string(keys: ["claimed_at", "claimedAt"], preferred: preferred)
        nextHeartbeatMS = Self.int(keys: ["next_heartbeat_ms", "nextHeartbeatMS", "nextHeartbeatMs"], preferred: preferred)
        availableTasks = Self.taskSummaries(from: Self.array(
            keys: ["available_tasks", "availableTasks", "tasks", "recommended_tasks"],
            preferred: preferred
        ))
        availableWork = Self.taskSummaries(from: Self.array(
            keys: ["available_work", "availableWork", "work"],
            preferred: preferred
        ))
        overdueTasks = Self.overdueTasks(from: Self.array(
            keys: ["overdue_tasks", "overdueTasks"],
            preferred: preferred
        ))
        pendingEvents = Self.pendingEvents(from: Self.array(
            keys: ["pending_events", "pendingEvents", "events"],
            preferred: preferred
        ))
        peers = Self.peers(from: Self.array(keys: ["peers", "nodes"], preferred: preferred))
        accountability = Self.accountability(from: Self.value(keys: ["accountability"], preferred: preferred))
        skillStore = Self.skillStore(from: Self.value(keys: ["skill_store", "skillStore"], preferred: preferred))
        message = Self.string(keys: ["message", "detail", "reason"], preferred: preferred)
    }

    private static func responsePayload(from root: JSONValue) -> JSONValue {
        for path in [
            ["payload"],
            ["data", "payload"],
            ["result", "payload"],
            ["data"],
            ["result"],
        ] {
            if let value = root.value(at: path) {
                return value
            }
        }
        return root
    }

    private static func string(keys: [String], preferred containers: [JSONValue]) -> String? {
        for container in containers {
            if let value = container.directString(forKeys: keys)?.nonEmpty {
                return value
            }
        }
        return nil
    }

    private static func int(keys: [String], preferred containers: [JSONValue]) -> Int? {
        for container in containers {
            if let value = container.directInt(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func bool(keys: [String], preferred containers: [JSONValue]) -> Bool? {
        for container in containers {
            if let value = container.directBool(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func array(keys: [String], preferred containers: [JSONValue]) -> [JSONValue]? {
        for container in containers {
            if let value = container.directArray(forKeys: keys) {
                return value
            }
        }
        return nil
    }

    private static func value(keys: [String], preferred containers: [JSONValue]) -> JSONValue? {
        for container in containers {
            for key in keys {
                if let value = container.value(at: [key]) {
                    return value
                }
            }
        }
        return nil
    }

    private static func taskSummaries(from values: [JSONValue]?) -> [EvoMapTaskSummary]? {
        let summaries = values?.compactMap { value -> EvoMapTaskSummary? in
            guard value.objectValue != nil else { return nil }
            return EvoMapTaskSummary(value: value)
        } ?? []
        return summaries.isEmpty ? nil : summaries
    }

    private static func overdueTasks(from values: [JSONValue]?) -> [EvoMapOverdueTask]? {
        let tasks = values?.compactMap { value -> EvoMapOverdueTask? in
            guard value.objectValue != nil else { return nil }
            return EvoMapOverdueTask(value: value)
        } ?? []
        return tasks.isEmpty ? nil : tasks
    }

    private static func pendingEvents(from values: [JSONValue]?) -> [EvoMapPendingEvent]? {
        let events = values?.compactMap { value -> EvoMapPendingEvent? in
            guard value.objectValue != nil else { return nil }
            return EvoMapPendingEvent(value: value)
        } ?? []
        return events.isEmpty ? nil : events
    }

    private static func peers(from values: [JSONValue]?) -> [EvoMapPeer]? {
        let peers = values?.compactMap { value -> EvoMapPeer? in
            guard value.objectValue != nil else { return nil }
            return EvoMapPeer(value: value)
        } ?? []
        return peers.isEmpty ? nil : peers
    }

    private static func accountability(from value: JSONValue?) -> EvoMapAccountability? {
        guard let value, value.objectValue != nil else { return nil }
        return EvoMapAccountability(value: value)
    }

    private static func skillStore(from value: JSONValue?) -> EvoMapSkillStoreStatus? {
        guard let value, value.objectValue != nil else { return nil }
        return EvoMapSkillStoreStatus(value: value)
    }
}

struct EvoMapAccountBalanceResponse: Decodable, Hashable {
    let balance: Int?
    let availableCredits: Int?
    let pendingCredits: Int?
    let totalEarnedCredits: Int?
    let planName: String?
    let status: String?
    let message: String?
    let updatedAt: String?

    var bestBalance: Int? {
        balance ?? availableCredits
    }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        balance = root.recursiveInt(forKeys: [
            "balance", "credit_balance", "credits", "current_balance", "account_balance",
        ])
        availableCredits = root.recursiveInt(forKeys: [
            "available_credits", "available", "available_balance", "spendable_credits",
        ])
        pendingCredits = root.recursiveInt(forKeys: [
            "pending_credits", "pending", "pending_balance",
        ])
        totalEarnedCredits = root.recursiveInt(forKeys: [
            "total_earned_credits", "earned_credits", "total_earned", "lifetime_credits",
        ])
        planName = root.recursiveString(forKeys: ["plan", "plan_name", "tier", "membership"])
        status = root.recursiveString(forKeys: ["status"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
        updatedAt = root.recursiveString(forKeys: ["updated_at", "synced_at", "timestamp"])
    }
}

struct EvoMapNodeProfileResponse: Decodable, Hashable {
    let nodeID: String?
    let reputationScore: Double?
    let reputationPenalty: Int?
    let quarantineStrikes: Int?
    let totalPublished: Int?
    let status: String?
    let online: Bool?
    let lastSeenAt: String?
    let survivalStatus: String?
    let message: String?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        nodeID = root.recursiveString(forKeys: ["node_id", "nodeID", "id"])
        reputationScore = root.recursiveDouble(forKeys: ["reputation_score", "reputationScore", "reputation"])
        reputationPenalty = root.recursiveInt(forKeys: ["reputation_penalty", "reputationPenalty"])
        quarantineStrikes = root.recursiveInt(forKeys: ["quarantine_strikes", "quarantineStrikes"])
        totalPublished = root.recursiveInt(forKeys: ["total_published", "totalPublished"])
        status = root.recursiveString(forKeys: ["status"])
        online = root.recursiveBool(forKeys: ["online"])
        lastSeenAt = root.recursiveString(forKeys: ["last_seen_at", "lastSeenAt"])
        survivalStatus = root.recursiveString(forKeys: ["survival_status", "survivalStatus"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
    }
}

struct EvoMapBountyTaskListResponse: Decodable {
    let tasks: [EvoMapBountyTask]
    let total: Int?
    let openCount: Int?
    let matchedCount: Int?
    let totalBountyAmount: Int?
    let status: String?
    let message: String?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let taskValues = root.recursiveArray(forKeys: [
            "tasks", "available_tasks", "bounties", "items", "results", "data",
        ]) ?? root.arrayValue ?? []

        tasks = taskValues.enumerated().map { index, value in
            EvoMapBountyTask(value: value, fallbackIndex: index)
        }
        total = root.recursiveInt(forKeys: ["total", "count_total", "total_count"])
        openCount = root.recursiveInt(forKeys: ["open_count", "openCount"])
        matchedCount = root.recursiveInt(forKeys: ["matched_count", "matchedCount"])
        totalBountyAmount = root.recursiveInt(forKeys: ["total_bounty_amount", "totalBountyAmount"])
        status = root.recursiveString(forKeys: ["status"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
    }
}

struct EvoMapBountyTask: Identifiable, Hashable {
    let taskID: String
    let claimTaskID: String?
    let bountyID: String?
    let questionID: String?
    let title: String
    let summary: String?
    let bountyCredits: Int?
    let rewardCredits: Int?
    let domain: String?
    let kind: String?
    let status: String?
    let createdAt: String?
    let deadline: String?
    let minReputation: Int?
    let submissionCount: Int?

    var id: String {
        claimTaskID ?? bountyID ?? questionID ?? taskID
    }

    var displayCredits: Int? {
        bountyCredits ?? rewardCredits
    }

    var claimableTaskID: String? {
        claimTaskID?.nonEmpty
    }

    fileprivate init(value: JSONValue, fallbackIndex: Int) {
        let resolvedClaimTaskID = value.recursiveString(forKeys: ["task_id", "taskID"])
        let resolvedBountyID = value.recursiveString(forKeys: ["bounty_id", "bountyID"])
        let resolvedQuestionID = value.recursiveString(forKeys: ["question_id", "questionID"])
        claimTaskID = resolvedClaimTaskID
        bountyID = resolvedBountyID
        questionID = resolvedQuestionID
        taskID = resolvedClaimTaskID
            ?? resolvedQuestionID
            ?? resolvedBountyID
            ?? value.recursiveString(forKeys: ["id"])
            ?? "bounty-task-\(fallbackIndex + 1)"
        title = value.recursiveString(forKeys: ["title", "question", "name"])
            ?? taskID
        summary = value.recursiveString(forKeys: ["summary", "description", "body", "prompt"])
        bountyCredits = value.recursiveInt(forKeys: ["bounty_credits", "bounty", "bountyCredits", "bounty_amount"])
        rewardCredits = value.recursiveInt(forKeys: ["reward_credits", "reward", "credits", "price"])
        domain = value.recursiveString(forKeys: ["domain", "category", "topic"])
        kind = value.recursiveString(forKeys: ["kind", "type", "intent"])
        status = value.recursiveString(forKeys: ["status", "state", "bounty_status", "task_status"])
        createdAt = value.recursiveString(forKeys: ["created_at", "createdAt"])
        deadline = value.recursiveString(forKeys: ["deadline", "due_at", "expires_at", "commitment_deadline"])
        minReputation = value.recursiveInt(forKeys: ["min_reputation", "minReputation"])
        submissionCount = value.recursiveInt(forKeys: ["submission_count", "submissionCount"])
    }

    init(claimedTask: EvoMapClaimedBountyTask, fallbackIndex: Int = 0) {
        claimTaskID = claimedTask.taskID
        bountyID = claimedTask.bountyID
        questionID = claimedTask.questionID
        taskID = claimedTask.taskID
        title = claimedTask.title.nonEmpty ?? claimedTask.taskID
        summary = claimedTask.body
        bountyCredits = claimedTask.bountyCredits
        rewardCredits = claimedTask.rewardCredits
        domain = nil
        kind = "bounty"
        status = claimedTask.status
        createdAt = nil
        deadline = claimedTask.expiresAt
        minReputation = claimedTask.minReputation
        submissionCount = nil
    }
}

struct EvoMapBountyDetailResponse: Decodable {
    let bountyID: String?
    let questionID: String?
    let taskID: String?
    let title: String?
    let status: String?
    let amount: Int?
    let message: String?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        bountyID = root.recursiveString(forKeys: ["bounty_id", "bountyID", "id"])
        questionID = root.recursiveString(forKeys: ["question_id", "questionID"])
        taskID = root.recursiveString(forKeys: ["task_id", "taskID"])
        title = root.recursiveString(forKeys: ["title", "question", "name"])
        status = root.recursiveString(forKeys: ["status", "task_status", "bounty_status"])
        amount = root.recursiveInt(forKeys: ["amount", "bounty_amount", "bounty"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
    }
}

struct EvoMapMyBountyTasksResponse: Decodable {
    let tasks: [EvoMapClaimedBountyTask]
    let count: Int?
    let status: String?
    let message: String?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let taskValues = root.recursiveArray(forKeys: [
            "tasks", "claimed_tasks", "items", "results", "data",
        ]) ?? root.arrayValue ?? []

        tasks = taskValues.enumerated().map { index, value in
            EvoMapClaimedBountyTask(value: value, fallbackIndex: index)
        }
        count = root.recursiveInt(forKeys: ["count", "total", "total_count"])
        status = root.recursiveString(forKeys: ["status"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
    }
}

struct EvoMapClaimedBountyTask: Identifiable, Hashable {
    let taskID: String
    let bountyID: String?
    let questionID: String?
    let title: String
    let body: String?
    let status: String?
    let minReputation: Int?
    let expiresAt: String?
    let bountyCredits: Int?
    let rewardCredits: Int?
    let mySubmissionID: String?
    let mySubmissionStatus: String?
    let mySubmissionAssetID: String?

    var id: String { taskID }

    fileprivate init(value: JSONValue, fallbackIndex: Int) {
        let resolvedTaskID = value.recursiveString(forKeys: ["task_id", "taskID", "id"])
            ?? "claimed-bounty-task-\(fallbackIndex + 1)"
        let submissionAssetContainers = [
            value.value(at: ["my_submission_asset"]),
            value.value(at: ["mySubmissionAsset"]),
            value.value(at: ["submission_asset"]),
            value.value(at: ["asset"]),
        ]
        .compactMap { $0 }

        taskID = resolvedTaskID
        bountyID = value.recursiveString(forKeys: ["bounty_id", "bountyID"])
        questionID = value.recursiveString(forKeys: ["question_id", "questionID"])
        title = value.recursiveString(forKeys: ["title", "question", "name"])
            ?? resolvedTaskID
        body = value.recursiveString(forKeys: ["body", "summary", "description", "prompt"])
        status = value.recursiveString(forKeys: ["status", "state", "task_status"])
        minReputation = value.recursiveInt(forKeys: ["min_reputation", "minReputation"])
        expiresAt = value.recursiveString(forKeys: ["expires_at", "expiresAt", "deadline", "due_at"])
        bountyCredits = value.recursiveInt(forKeys: ["bounty_credits", "bounty", "bountyCredits", "bounty_amount"])
        rewardCredits = value.recursiveInt(forKeys: ["reward_credits", "reward", "credits", "price"])
        mySubmissionID = value.recursiveString(forKeys: ["my_submission_id", "mySubmissionID", "submission_id"])
        mySubmissionStatus = value.recursiveString(forKeys: ["my_submission_status", "mySubmissionStatus", "submission_status"])
        mySubmissionAssetID = submissionAssetContainers
            .compactMap { $0.recursiveString(forKeys: ["asset_id", "assetID", "id"]) }
            .first
            ?? value.recursiveString(forKeys: ["my_submission_asset_id", "mySubmissionAssetID", "asset_id"])
    }
}

struct EvoMapPublishBundleResponse: Decodable {
    let status: String?
    let message: String?
    let bundleID: String?
    let assetIDs: [String]

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let assetValues = root.recursiveArray(forKeys: ["assets", "published_assets", "items"]) ?? []

        status = root.recursiveString(forKeys: ["status"])
        message = root.recursiveString(forKeys: ["message", "detail", "reason"])
        bundleID = root.recursiveString(forKeys: ["bundle_id", "bundleID", "bundleId"])
        assetIDs = assetValues.compactMap { $0.recursiveString(forKeys: ["asset_id", "assetID", "id"]) }
    }
}

struct EvoMapSkillStoreStatus: Decodable, Hashable {
    let eligible: Bool?
    let publishedSkills: Int?
    let publishEndpoint: String?
    let hint: String?

    enum CodingKeys: String, CodingKey {
        case eligible
        case publishedSkills = "published_skills"
        case publishEndpoint = "publish_endpoint"
        case hint
    }

    fileprivate init(value: JSONValue) {
        eligible = value.recursiveBool(forKeys: ["eligible", "enabled"])
        publishedSkills = value.recursiveInt(forKeys: ["published_skills", "publishedSkills", "count"])
        publishEndpoint = value.recursiveString(forKeys: ["publish_endpoint", "publishEndpoint", "endpoint"])
        hint = value.recursiveString(forKeys: ["hint", "message", "detail"])
    }
}

struct EvoMapSkillStorePublicStatusResponse: Decodable {
    let enabled: Bool
}

struct EvoMapSkillStoreListResponse: Decodable {
    let skills: [RemoteSkillSummary]
    let total: Int
    let totalDownloads: Int?
    let page: Int
    let limit: Int
}

struct EvoMapSkillStoreVersionsResponse: Decodable {
    let skillId: String
    let versions: [RemoteSkillVersion]
}

struct EvoMapSkillStoreMutationResponse: Decodable {
    let status: String?
    let message: String?
    let skillID: String?
    let version: String?
    let name: String?
    let moderationStatus: String?
    let visibility: String?

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case skillID = "skill_id"
        case version
        case name
        case moderationStatus = "moderation_status"
        case visibility
        case data
        case skill
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let skillContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .skill)

        func decode(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> String? {
            guard let container else { return nil }
            return try? container.decodeIfPresent(String.self, forKey: key)
        }

        func decode(_ key: CodingKeys) -> String? {
            (try? container.decodeIfPresent(String.self, forKey: key))
                ?? decode(key, from: dataContainer)
                ?? decode(key, from: skillContainer)
        }

        status = decode(.status)
        message = decode(.message)
        skillID = decode(.skillID)
        version = decode(.version)
        name = decode(.name)
        moderationStatus = decode(.moderationStatus)
        visibility = decode(.visibility)
    }
}

struct EvoMapSkillStoreDownloadResponse: Decodable {
    struct BundledFile: Decodable, Hashable {
        let name: String
        let content: String
    }

    let skillID: String
    let name: String?
    let version: String?
    let description: String?
    let category: String?
    let tags: [String]
    let content: String
    let bundledFiles: [BundledFile]
    let creditCost: Int?
    let alreadyPurchased: Bool

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case name
        case version
        case description
        case category
        case tags
        case content
        case bundledFiles = "bundled_files"
        case creditCost = "credit_cost"
        case alreadyPurchased = "already_purchased"
        case data
        case skill
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let skillContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .skill)

        func decodeString(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> String? {
            guard let container else { return nil }
            return try? container.decodeIfPresent(String.self, forKey: key)
        }

        func decodeString(_ key: CodingKeys) -> String? {
            (try? container.decodeIfPresent(String.self, forKey: key))
                ?? decodeString(key, from: dataContainer)
                ?? decodeString(key, from: skillContainer)
        }

        func decodeStrings(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> [String]? {
            guard let container else { return nil }
            return try? container.decodeIfPresent([String].self, forKey: key)
        }

        func decodeStrings(_ key: CodingKeys) -> [String]? {
            (try? container.decodeIfPresent([String].self, forKey: key))
                ?? decodeStrings(key, from: dataContainer)
                ?? decodeStrings(key, from: skillContainer)
        }

        func decodeBundledFiles(from container: KeyedDecodingContainer<CodingKeys>?) -> [BundledFile]? {
            guard let container else { return nil }
            return try? container.decodeIfPresent([BundledFile].self, forKey: .bundledFiles)
        }

        func decodeBundledFiles() -> [BundledFile]? {
            (try? container.decodeIfPresent([BundledFile].self, forKey: .bundledFiles))
                ?? decodeBundledFiles(from: dataContainer)
                ?? decodeBundledFiles(from: skillContainer)
        }

        func decodeInt(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> Int? {
            guard let container else { return nil }
            return try? container.decodeIfPresent(Int.self, forKey: key)
        }

        func decodeInt(_ key: CodingKeys) -> Int? {
            (try? container.decodeIfPresent(Int.self, forKey: key))
                ?? decodeInt(key, from: dataContainer)
                ?? decodeInt(key, from: skillContainer)
        }

        func decodeBool(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> Bool? {
            guard let container else { return nil }
            return try? container.decodeIfPresent(Bool.self, forKey: key)
        }

        func decodeBool(_ key: CodingKeys) -> Bool? {
            (try? container.decodeIfPresent(Bool.self, forKey: key))
                ?? decodeBool(key, from: dataContainer)
                ?? decodeBool(key, from: skillContainer)
        }

        guard let resolvedSkillID = decodeString(.skillID)?.nonEmpty,
              let resolvedContent = decodeString(.content) else {
            throw DecodingError.dataCorruptedError(
                forKey: .content,
                in: container,
                debugDescription: "The Skill Store download response is missing `skill_id` or `content`."
            )
        }

        skillID = resolvedSkillID
        name = decodeString(.name)
        version = decodeString(.version)
        description = decodeString(.description)
        category = decodeString(.category)
        tags = decodeStrings(.tags) ?? []
        content = resolvedContent
        bundledFiles = decodeBundledFiles() ?? []
        creditCost = decodeInt(.creditCost)
        alreadyPurchased = decodeBool(.alreadyPurchased) ?? false
    }
}

struct EvoMapSkillStoreRecycleBinResponse: Decodable {
    let skills: [RecycledSkillSummary]
    let total: Int?
    let page: Int?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case skills
        case items
        case entries
        case total
        case page
        case limit
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        func decodeSkills(from container: KeyedDecodingContainer<CodingKeys>?) -> [RecycledSkillSummary]? {
            guard let container else { return nil }
            return (try? container.decodeIfPresent([RecycledSkillSummary].self, forKey: .skills))
                ?? (try? container.decodeIfPresent([RecycledSkillSummary].self, forKey: .items))
                ?? (try? container.decodeIfPresent([RecycledSkillSummary].self, forKey: .entries))
        }

        func decodeInt(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> Int? {
            guard let container else { return nil }
            return try? container.decodeIfPresent(Int.self, forKey: key)
        }

        skills = decodeSkills(from: container) ?? decodeSkills(from: dataContainer) ?? []
        total = decodeInt(.total, from: container) ?? decodeInt(.total, from: dataContainer)
        page = decodeInt(.page, from: container) ?? decodeInt(.page, from: dataContainer)
        limit = decodeInt(.limit, from: container) ?? decodeInt(.limit, from: dataContainer)
    }
}

struct EvoMapServiceListResponse: Decodable {
    let services: [RemoteServiceSummary]
    let total: Int?

    private enum CodingKeys: String, CodingKey {
        case services
        case items
        case listings
        case results
        case data
        case total
        case count
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let services = try? singleValue.decode([RemoteServiceSummary].self) {
            self.services = services
            total = services.count
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        func decodeServices(from container: KeyedDecodingContainer<CodingKeys>?) -> [RemoteServiceSummary]? {
            guard let container else { return nil }
            if let value = try? container.decodeIfPresent([RemoteServiceSummary].self, forKey: .services) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceSummary].self, forKey: .items) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceSummary].self, forKey: .listings) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceSummary].self, forKey: .results) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceSummary].self, forKey: .data) {
                return value
            }
            return nil
        }

        services = decodeServices(from: container)
            ?? decodeServices(from: dataContainer)
            ?? []

        let rootTotal = try? container.decodeIfPresent(Int.self, forKey: .total)
        let rootCount = try? container.decodeIfPresent(Int.self, forKey: .count)
        let dataTotal = try? dataContainer?.decodeIfPresent(Int.self, forKey: .total)
        let dataCount = try? dataContainer?.decodeIfPresent(Int.self, forKey: .count)
        total = rootTotal ?? rootCount ?? dataTotal ?? dataCount ?? services.count
    }
}

struct EvoMapServiceMutationResponse: Decodable {
    let status: String?
    let message: String?
    let listingID: String?
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case listingID = "listing_id"
        case id
        case title
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

        func decode(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> String? {
            guard let container else { return nil }
            return (try? container.decodeIfPresent(String.self, forKey: key))
                ?? (key == .listingID ? (try? container.decodeIfPresent(String.self, forKey: .id)) : nil)
        }

        func decode(_ key: CodingKeys) -> String? {
            decode(key, from: container)
                ?? decode(key, from: dataContainer)
                ?? decode(key, from: serviceContainer)
                ?? decode(key, from: listingContainer)
        }

        status = decode(.status)
        message = decode(.message)
        listingID = decode(.listingID)
        title = decode(.title)
    }
}

struct EvoMapServiceRatingsResponse: Decodable {
    let ratings: [RemoteServiceRating]
    let total: Int?

    private enum CodingKeys: String, CodingKey {
        case ratings
        case items
        case results
        case reviews
        case data
        case total
        case count
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let ratings = try? singleValue.decode([RemoteServiceRating].self) {
            self.ratings = ratings
            total = ratings.count
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        func decodeRatings(from container: KeyedDecodingContainer<CodingKeys>?) -> [RemoteServiceRating]? {
            guard let container else { return nil }
            if let value = try? container.decodeIfPresent([RemoteServiceRating].self, forKey: .ratings) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceRating].self, forKey: .items) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceRating].self, forKey: .results) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceRating].self, forKey: .reviews) {
                return value
            }
            if let value = try? container.decodeIfPresent([RemoteServiceRating].self, forKey: .data) {
                return value
            }
            return nil
        }

        ratings = decodeRatings(from: container)
            ?? decodeRatings(from: dataContainer)
            ?? []

        let rootTotal = try? container.decodeIfPresent(Int.self, forKey: .total)
        let rootCount = try? container.decodeIfPresent(Int.self, forKey: .count)
        let dataTotal = try? dataContainer?.decodeIfPresent(Int.self, forKey: .total)
        let dataCount = try? dataContainer?.decodeIfPresent(Int.self, forKey: .count)
        total = rootTotal ?? rootCount ?? dataTotal ?? dataCount ?? ratings.count
    }
}

struct EvoMapServiceRateResponse: Decodable {
    let status: String?
    let message: String?
    let listingID: String?
    let ratingID: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case listingID = "listing_id"
        case ratingID = "rating_id"
        case id
        case data
        case rating
        case review
        case service
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let ratingContainer = (try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .rating))
            ?? (try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .rating))
            ?? (try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .review))
            ?? (try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .review))

        func decode(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> String? {
            guard let container else { return nil }
            return (try? container.decodeIfPresent(String.self, forKey: key))
                ?? (key == .ratingID ? (try? container.decodeIfPresent(String.self, forKey: .id)) : nil)
        }

        func decode(_ key: CodingKeys) -> String? {
            decode(key, from: container)
                ?? decode(key, from: dataContainer)
                ?? decode(key, from: ratingContainer)
        }

        status = decode(.status)
        message = decode(.message)
        listingID = decode(.listingID)
        ratingID = decode(.ratingID)
    }
}

struct EvoMapTaskMutationResponse: Decodable {
    let status: String?
    let message: String?
    let taskID: String?
    let submissionID: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case taskID = "task_id"
        case submissionID = "submission_id"
        case id
        case data
        case task
        case order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        let taskContainer = (try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .task))
            ?? (try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .task))
            ?? (try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .order))
            ?? (try? dataContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .order))

        func decode(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>?) -> String? {
            guard let container else { return nil }
            return (try? container.decodeIfPresent(String.self, forKey: key))
                ?? (key == .taskID ? (try? container.decodeIfPresent(String.self, forKey: .id)) : nil)
        }

        func decode(_ key: CodingKeys) -> String? {
            decode(key, from: container)
                ?? decode(key, from: dataContainer)
                ?? decode(key, from: taskContainer)
        }

        status = decode(.status)
        message = decode(.message)
        taskID = decode(.taskID)
        submissionID = decode(.submissionID)
    }
}

struct EvoMapKnowledgeGraphIngestResponse: Decodable {
    let status: String?
    let message: String?
    let entitiesWritten: Int?
    let relationshipsWritten: Int?

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let containers = [
            root.value(at: ["data"]),
            root.value(at: ["result"]),
            root,
        ]
        .compactMap { $0 }

        status = KnowledgeGraphFieldDecoder.string(
            keys: ["status"],
            preferred: containers,
            recursive: containers
        )
        message = KnowledgeGraphFieldDecoder.string(
            keys: ["message", "detail", "note"],
            preferred: containers,
            recursive: containers
        )
        entitiesWritten = KnowledgeGraphFieldDecoder.int(
            keys: ["entities_written", "entity_count", "entities", "written_entities"],
            preferred: containers,
            recursive: containers
        )
        relationshipsWritten = KnowledgeGraphFieldDecoder.int(
            keys: ["relationships_written", "relation_count", "relations_written", "written_relations"],
            preferred: containers,
            recursive: containers
        )
    }
}

private enum KnowledgeGraphFieldDecoder {
    static func string(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> String? {
        for container in preferred {
            if let value = container.directString(forKeys: keys)?.trimmingCharacters(in: .whitespacesAndNewlines),
               value.isEmpty == false {
                return value
            }
        }
        for container in recursive {
            if let value = container.recursiveString(forKeys: keys)?.trimmingCharacters(in: .whitespacesAndNewlines),
               value.isEmpty == false {
                return value
            }
        }
        return nil
    }

    static func int(keys: [String], preferred: [JSONValue], recursive: [JSONValue]) -> Int? {
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

    func directInt(forKeys keys: [String]) -> Int? {
        for key in keys {
            if let value = value(at: [key])?.lossyInt {
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

    func directArray(forKeys keys: [String]) -> [JSONValue]? {
        for key in keys {
            if let value = value(at: [key])?.arrayValue {
                return value
            }
        }
        return nil
    }

    func recursiveArray(forKeys keys: [String]) -> [JSONValue]? {
        if let direct = directArray(forKeys: keys) {
            return direct
        }
        for child in childValues {
            if let value = child.recursiveArray(forKeys: keys) {
                return value
            }
        }
        return nil
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

    var lossyDate: Date? {
        guard case .string(let value) = self else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return fractional.date(from: trimmed) ?? standard.date(from: trimmed)
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
            let normalized = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
            if ["true", "yes", "y", "1", "claimed", "bound", "active", "verified", "completed", "complete", "confirmed"].contains(normalized) {
                return true
            }
            if ["false", "no", "n", "0", "unclaimed", "unbound", "pending", "waiting", "inactive", "failed"].contains(normalized) {
                return false
            }
            return nil
        default:
            return nil
        }
    }
}

struct EvoMapOverdueTask: Decodable, Hashable {
    let taskID: String?
    let title: String?
    let commitmentDeadline: Date?
    let overdueMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case title
        case commitmentDeadline = "commitment_deadline"
        case overdueMinutes = "overdue_minutes"
    }

    fileprivate init(value: JSONValue) {
        taskID = value.recursiveString(forKeys: ["task_id", "taskID", "id"])
        title = value.recursiveString(forKeys: ["title", "name", "summary"])
        commitmentDeadline = value.recursiveDate(forKeys: ["commitment_deadline", "commitmentDeadline", "deadline", "due_at"])
        overdueMinutes = value.recursiveInt(forKeys: ["overdue_minutes", "overdueMinutes", "minutes"])
    }
}

struct EvoMapPendingEvent: Decodable, Hashable {
    let eventID: String?
    let type: String?
    let createdAt: Date?
    let priority: Int?
    let payload: JSONValue?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case type
        case createdAt = "created_at"
        case priority
        case payload
    }

    fileprivate init(value: JSONValue) {
        eventID = value.recursiveString(forKeys: ["event_id", "eventID", "id"])
        type = value.recursiveString(forKeys: ["type", "event_type", "eventType"])
        createdAt = value.recursiveDate(forKeys: ["created_at", "createdAt", "timestamp"])
        priority = value.recursiveInt(forKeys: ["priority"])
        payload = value.value(at: ["payload"]) ?? value.value(at: ["data"])
    }
}

struct EvoMapPeer: Decodable, Hashable {
    let nodeID: String?
    let alias: String?
    let online: Bool?
    let reputation: Double?
    let workload: Int?

    enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case alias
        case online
        case reputation
        case workload
    }

    fileprivate init(value: JSONValue) {
        nodeID = value.recursiveString(forKeys: ["node_id", "nodeID", "id", "sender_id", "senderID"])
        alias = value.recursiveString(forKeys: ["alias", "name", "display_name"])
        online = value.recursiveBool(forKeys: ["online", "is_online", "isOnline"])
        reputation = value.recursiveDouble(forKeys: ["reputation", "score"])
        workload = value.recursiveInt(forKeys: ["workload", "load", "pending"])
    }
}

struct EvoMapAccountability: Decodable, Hashable {
    let reputationPenalty: Int?
    let quarantineStrikes: Int?
    let publishCooldownUntil: Date?
    let recommendation: String?
    let topPatterns: [EvoMapErrorPattern]?

    enum CodingKeys: String, CodingKey {
        case reputationPenalty = "reputation_penalty"
        case quarantineStrikes = "quarantine_strikes"
        case publishCooldownUntil = "publish_cooldown_until"
        case recommendation
        case topPatterns = "top_patterns"
        case errorPatterns = "error_patterns"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reputationPenalty = try container.decodeIfPresent(Int.self, forKey: .reputationPenalty)
        quarantineStrikes = try container.decodeIfPresent(Int.self, forKey: .quarantineStrikes)
        publishCooldownUntil = try container.decodeIfPresent(Date.self, forKey: .publishCooldownUntil)
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
        topPatterns = try container.decodeIfPresent([EvoMapErrorPattern].self, forKey: .topPatterns)
            ?? (try container.decodeIfPresent([EvoMapErrorPattern].self, forKey: .errorPatterns))
    }

    fileprivate init(value: JSONValue) {
        reputationPenalty = value.recursiveInt(forKeys: ["reputation_penalty", "reputationPenalty"])
        quarantineStrikes = value.recursiveInt(forKeys: ["quarantine_strikes", "quarantineStrikes"])
        publishCooldownUntil = value.recursiveDate(forKeys: ["publish_cooldown_until", "publishCooldownUntil"])
        recommendation = value.recursiveString(forKeys: ["recommendation", "message", "hint"])
        let patternValues = value.recursiveArray(forKeys: ["top_patterns", "topPatterns", "error_patterns", "errorPatterns"])
        let patterns = patternValues?.compactMap { pattern -> EvoMapErrorPattern? in
            guard pattern.objectValue != nil else { return nil }
            return EvoMapErrorPattern(value: pattern)
        } ?? []
        topPatterns = patterns.isEmpty ? nil : patterns
    }
}

struct EvoMapErrorPattern: Decodable, Hashable {
    let fingerprint: String?
    let count: Int?
    let escalation: String?
    let reason: String?

    fileprivate init(value: JSONValue) {
        fingerprint = value.recursiveString(forKeys: ["fingerprint", "id", "key"])
        count = value.recursiveInt(forKeys: ["count", "total"])
        escalation = value.recursiveString(forKeys: ["escalation", "severity", "level"])
        reason = value.recursiveString(forKeys: ["reason", "message", "detail"])
    }
}

indirect enum JSONValue: Decodable, Hashable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON payload value.")
        }
    }

    var compactDescription: String {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .object(let value):
            let renderedKeys = value.keys.sorted().joined(separator: ", ")
            return renderedKeys.isEmpty ? "{}" : "keys: \(renderedKeys)"
        case .array(let value):
            return "\(value.count) item(s)"
        case .null:
            return "null"
        }
    }
}

struct EvoMapErrorResponse: Decodable {
    let error: String?
    let code: String?
    let message: String?
    let reason: String?
    let detail: String?
}

enum EvoMapClientError: LocalizedError {
    case invalidBaseURL(String)
    case invalidResponse
    case httpStatus(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let baseURL):
            return "The EvoMap base URL is invalid: \(baseURL)"
        case .invalidResponse:
            return "The EvoMap server returned an invalid response."
        case .httpStatus(let status, let message):
            return message.isEmpty ? "The EvoMap server returned HTTP \(status)." : "HTTP \(status): \(message)"
        case .decodingFailed(let message):
            return "The EvoMap server returned JSON that this app could not decode. \(message)"
        }
    }
}

struct EvoMapClient: EvoMapClientProtocol {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let parsed = Self.iso8601Fractional.date(from: value) ?? Self.iso8601.date(from: value) {
                return parsed
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date value: \(value)")
        }
        self.decoder = decoder
    }

    func hello(request: EvoMapHelloRequest) async throws -> EvoMapHelloResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/hello")
        let envelope = A2AMessageEnvelope(
            messageType: "hello",
            messageID: Self.makeMessageID(),
            senderID: request.senderID,
            timestamp: Self.timestampString(),
            payload: request.payload
        )

        return try await performRequest(endpoint: endpoint, body: envelope, bearerToken: nil)
    }

    func heartbeat(request: EvoMapHeartbeatRequest) async throws -> EvoMapHeartbeatResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/heartbeat")
        return try await performRequest(endpoint: endpoint, body: request.payload, bearerToken: request.nodeSecret)
    }

    func accountBalance(request: EvoMapAccountBalanceRequest) async throws -> EvoMapAccountBalanceResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/account/balance")
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.apiKey)
    }

    func listBountyTasks(request: EvoMapBountyTaskListRequest) async throws -> EvoMapBountyTaskListResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/a2a/task/list",
            queryItems: [
                URLQueryItem(name: "min_bounty", value: String(request.minBounty)),
                URLQueryItem(name: "limit", value: String(request.limit)),
            ]
        )
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.nodeSecret)
    }

    func nodeProfile(request: EvoMapNodeProfileRequest) async throws -> EvoMapNodeProfileResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/nodes/\(request.nodeID)")
        return try await performGetRequest(endpoint: endpoint)
    }

    func listPublicBountyTasks(request: EvoMapPublicBountyTaskListRequest) async throws -> EvoMapBountyTaskListResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/api/hub/bounty/questions",
            queryItems: [
                URLQueryItem(name: "limit", value: String(request.limit)),
                URLQueryItem(name: "page", value: String(request.page)),
                URLQueryItem(name: "has_bounty", value: request.hasBounty ? "true" : "false"),
            ]
        )
        return try await performGetRequest(endpoint: endpoint)
    }

    func bountyDetail(request: EvoMapBountyDetailRequest) async throws -> EvoMapBountyDetailResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/api/hub/bounty/\(request.bountyID)"
        )
        return try await performGetRequest(endpoint: endpoint)
    }

    func claimBountyTask(request: EvoMapBountyTaskClaimRequest) async throws -> EvoMapTaskMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/task/claim")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func myBountyTasks(request: EvoMapMyBountyTasksRequest) async throws -> EvoMapMyBountyTasksResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/a2a/task/my",
            queryItems: [URLQueryItem(name: "node_id", value: request.nodeID)]
        )
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.nodeSecret)
    }

    func publishAssetBundle(request: EvoMapPublishBundleRequest) async throws -> EvoMapPublishBundleResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/publish")
        let envelope = A2AMessageEnvelope(
            messageType: "publish",
            messageID: Self.makeMessageID(),
            senderID: request.senderID,
            timestamp: Self.timestampString(),
            payload: request.payload
        )
        return try await performRequest(endpoint: endpoint, method: "POST", body: envelope, bearerToken: request.nodeSecret)
    }

    func completeBountyTask(request: EvoMapBountyTaskCompleteRequest) async throws -> EvoMapTaskMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/task/complete")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func publishSkill(request: EvoMapSkillStoreMutationRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/publish")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func updateSkill(request: EvoMapSkillStoreMutationRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/update")
        return try await performRequest(endpoint: endpoint, method: "PUT", body: request.payload, bearerToken: request.nodeSecret)
    }

    func setSkillVisibility(request: EvoMapSkillStoreVisibilityRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/visibility")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func rollbackSkill(request: EvoMapSkillStoreRollbackRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/rollback")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func deleteSkillVersion(request: EvoMapSkillStoreDeleteVersionRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/delete-version")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func deleteSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/delete")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func restoreSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/restore")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func permanentlyDeleteSkill(request: EvoMapSkillStoreDeleteRequest) async throws -> EvoMapSkillStoreMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/permanent-delete")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func recycleBin(request: EvoMapSkillStoreRecycleBinRequest) async throws -> EvoMapSkillStoreRecycleBinResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/recycle-bin")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func skillStoreStatus(baseURL: String) async throws -> EvoMapSkillStorePublicStatusResponse {
        let endpoint = try makeEndpoint(baseURL: baseURL, path: "/a2a/skill/store/status")
        return try await performGetRequest(endpoint: endpoint)
    }

    func listSkills(request: EvoMapSkillStoreListRequest) async throws -> EvoMapSkillStoreListResponse {
        let queryItems = [
            URLQueryItem(name: "keyword", value: request.keyword?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty),
            URLQueryItem(name: "page", value: String(request.page)),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "sort", value: request.sort?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty),
            URLQueryItem(name: "featured", value: request.featured.map { $0 ? "true" : "false" }),
        ]
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/list", queryItems: queryItems)
        return try await performGetRequest(endpoint: endpoint)
    }

    func skillDetail(request: EvoMapSkillStoreDetailRequest) async throws -> RemoteSkillDetail {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/\(request.skillID)")
        return try await performGetRequest(endpoint: endpoint)
    }

    func skillVersions(request: EvoMapSkillStoreVersionsRequest) async throws -> EvoMapSkillStoreVersionsResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/\(request.skillID)/versions")
        return try await performGetRequest(endpoint: endpoint)
    }

    func downloadSkill(request: EvoMapSkillStoreDownloadRequest) async throws -> EvoMapSkillStoreDownloadResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/skill/store/\(request.skillID)/download")
        let payload = EvoMapSkillStoreDownloadPayload(senderID: request.senderID)
        return try await performRequest(endpoint: endpoint, method: "POST", body: payload, bearerToken: request.nodeSecret)
    }

    func listServices(request: EvoMapServiceListRequest) async throws -> EvoMapServiceListResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/list")
        return try await performGetRequest(endpoint: endpoint)
    }

    func searchServices(request: EvoMapServiceSearchRequest) async throws -> EvoMapServiceListResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/a2a/service/search",
            queryItems: [URLQueryItem(name: "q", value: request.query.nonEmpty)]
        )
        return try await performGetRequest(endpoint: endpoint)
    }

    func serviceDetail(request: EvoMapServiceDetailRequest) async throws -> RemoteServiceDetail {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/\(request.listingID)")
        return try await performGetRequest(endpoint: endpoint)
    }

    func publishService(request: EvoMapServicePublishRequest) async throws -> EvoMapServiceMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/publish")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func updateService(request: EvoMapServiceUpdateRequest) async throws -> EvoMapServiceMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/update")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func archiveService(request: EvoMapServiceArchiveRequest) async throws -> EvoMapServiceMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/archive")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func serviceRatings(request: EvoMapServiceRatingsRequest) async throws -> EvoMapServiceRatingsResponse {
        let endpoint = try makeEndpoint(
            baseURL: request.baseURL,
            path: "/a2a/service/\(request.listingID)/ratings",
            queryItems: [
                URLQueryItem(name: "page", value: request.page.map(String.init)),
                URLQueryItem(name: "limit", value: request.limit.map(String.init)),
            ]
        )
        return try await performGetRequest(endpoint: endpoint)
    }

    func rateService(request: EvoMapServiceRateRequest) async throws -> EvoMapServiceRateResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/rate")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func placeServiceOrder(request: EvoMapServiceOrderRequest) async throws -> RemoteOrderPlacement {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/a2a/service/order")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func orderDetail(request: EvoMapTaskDetailRequest) async throws -> RemoteOrderDetail {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/task/\(request.taskID)")
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.nodeSecret)
    }

    func acceptOrderSubmission(request: EvoMapTaskAcceptSubmissionRequest) async throws -> EvoMapTaskMutationResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/task/accept-submission")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.nodeSecret)
    }

    func knowledgeGraphStatus(request: EvoMapKnowledgeGraphStatusRequest) async throws -> KnowledgeGraphStatusSnapshot {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/kg/status")
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.apiKey)
    }

    func knowledgeGraphMyGraph(request: EvoMapKnowledgeGraphMyGraphRequest) async throws -> KnowledgeGraphSnapshot {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/kg/my-graph")
        return try await performGetRequest(endpoint: endpoint, bearerToken: request.apiKey)
    }

    func queryKnowledgeGraph(request: EvoMapKnowledgeGraphQueryRequest) async throws -> KnowledgeGraphSearchResult {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/kg/query")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.apiKey)
    }

    func ingestKnowledgeGraph(request: EvoMapKnowledgeGraphIngestRequest) async throws -> EvoMapKnowledgeGraphIngestResponse {
        let endpoint = try makeEndpoint(baseURL: request.baseURL, path: "/kg/ingest")
        return try await performRequest(endpoint: endpoint, method: "POST", body: request.payload, bearerToken: request.apiKey)
    }

    private func performRequest<Response: Decodable, Body: Encodable>(
        endpoint: URL,
        method: String = "POST",
        body: Body,
        bearerToken: String?
    ) async throws -> Response {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = method
        urlRequest.httpBody = try encoder.encode(body)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(Self.makeCorrelationID(), forHTTPHeaderField: "x-correlation-id")
        if let bearerToken, !bearerToken.isEmpty {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EvoMapClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EvoMapClientError.httpStatus(httpResponse.statusCode, parseErrorMessage(from: data))
        }

        return try decodeResponse(Response.self, from: data)
    }

    private func performGetRequest<Response: Decodable>(
        endpoint: URL,
        bearerToken: String? = nil
    ) async throws -> Response {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(Self.makeCorrelationID(), forHTTPHeaderField: "x-correlation-id")
        if let bearerToken, !bearerToken.isEmpty {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EvoMapClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EvoMapClientError.httpStatus(httpResponse.statusCode, parseErrorMessage(from: data))
        }

        return try decodeResponse(Response.self, from: data)
    }

    private func decodeResponse<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw EvoMapClientError.decodingFailed(Self.decodingDiagnostic(for: error, data: data))
        }
    }

    private func makeEndpoint(baseURL: String, path: String) throws -> URL {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme,
              !scheme.isEmpty else {
            throw EvoMapClientError.invalidBaseURL(baseURL)
        }

        components.path = normalizedPath(basePath: components.path, append: path)
        guard let url = components.url else {
            throw EvoMapClientError.invalidBaseURL(baseURL)
        }

        return url
    }

    private func makeEndpoint(baseURL: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme,
              !scheme.isEmpty else {
            throw EvoMapClientError.invalidBaseURL(baseURL)
        }

        components.path = normalizedPath(basePath: components.path, append: path)
        let filteredItems = queryItems.filter { $0.value?.isEmpty == false }
        components.queryItems = filteredItems.isEmpty ? nil : filteredItems

        guard let url = components.url else {
            throw EvoMapClientError.invalidBaseURL(baseURL)
        }

        return url
    }

    private func normalizedPath(basePath: String, append: String) -> String {
        let lhs = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        let rhs = append.hasPrefix("/") ? append : "/\(append)"
        return lhs + rhs
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let decoded = try? decoder.decode(EvoMapErrorResponse.self, from: data) {
            return [decoded.error, decoded.code, decoded.message, decoded.reason, decoded.detail]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func decodingDiagnostic(for error: Error, data: Data) -> String {
        var parts = [String(describing: error)]
        if let root = try? JSONDecoder().decode(JSONValue.self, from: data) {
            if let object = root.objectValue {
                parts.append("top-level keys: \(object.keys.sorted().joined(separator: ", "))")
            }
            if let payload = root.value(at: ["payload"])?.objectValue {
                parts.append("payload keys: \(payload.keys.sorted().joined(separator: ", "))")
            }
        } else {
            parts.append("non-JSON response, \(data.count) bytes")
        }
        return parts.joined(separator: " · ")
    }

    private static func makeMessageID() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return "msg_\(timestamp)_\(suffix)"
    }

    private static func makeCorrelationID() -> String {
        "evomap-console-\(UUID().uuidString.lowercased())"
    }

    private static func timestampString() -> String {
        iso8601.string(from: Date())
    }

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
}
