import Foundation

struct NativeBountyAnswer: Hashable {
    var markdown: String
    var templateID: String
    var templateTitle: String
    var signals: [String]
    var matchScore: Int
    var matchReasons: [String]
    var verificationNote: String
}

struct BountyWorkflowMatch: Hashable {
    var templateID: String
    var templateTitle: String
    var score: Int
    var reasons: [String]
    var signals: [String]
}

enum BountyWorkflowSkipReason: Hashable {
    case missingBody
    case noTemplateMatch
    case scoreBelowThreshold(Int)

    var summary: String {
        switch self {
        case .missingBody:
            return AppLocalization.string(
                "bounties.workflow.skip.missing_body",
                fallback: "No task body — cannot draft a useful answer locally."
            )
        case .noTemplateMatch:
            return AppLocalization.string(
                "bounties.workflow.skip.no_match",
                fallback: "No native template matched this bounty."
            )
        case .scoreBelowThreshold(let score):
            return AppLocalization.string(
                "bounties.workflow.skip.low_score",
                fallback: "Best template score (%d) is below the native engine threshold.",
                score
            )
        }
    }
}

enum BountyWorkflowResult {
    case answered(NativeBountyAnswer)
    case skipped(BountyWorkflowSkipReason)
}
