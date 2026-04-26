import Foundation

struct BountyTemplate {
    var id: String
    var title: String
    var titleSignals: [String]
    var bodySignals: [String]
    var disqualifySignals: [String]
    var baseScore: Int
    var render: (BountyTemplateContext) -> String
}

struct BountyTemplateContext {
    var title: String
    var body: String
    var rewardCredits: Int?
    var taskID: String
    var bountyID: String
    var detectedSignals: [String]
    var currentDraft: String?
}

enum BountyTemplateCatalog {
    static let nativeMinimumScore = 30

    static func all() -> [BountyTemplate] {
        [genericMarkdownAnswer]
    }

    static let genericMarkdownAnswer = BountyTemplate(
        id: "generic.markdown.v1",
        title: "Generic structured answer",
        titleSignals: [],
        bodySignals: [],
        disqualifySignals: [],
        baseScore: 30,
        render: { context in
            renderGenericAnswer(context: context)
        }
    )

    private static func renderGenericAnswer(context: BountyTemplateContext) -> String {
        let title = context.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = context.body.trimmingCharacters(in: .whitespacesAndNewlines)

        var sections: [String] = []
        sections.append("# \(title.isEmpty ? "Bounty answer" : title)")
        sections.append("")

        sections.append("## 1. 任务理解")
        if body.isEmpty {
            sections.append("任务正文未提供。请在提交前补充对题目的理解、边界条件和验收标准。")
        } else {
            sections.append("题目要求（原文摘录）：")
            sections.append("")
            sections.append("> " + body
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .prefix(8)
                .joined(separator: "\n> "))
            sections.append("")
            sections.append("基于上文，本回答聚焦在题目最核心的可交付项，并对题目未明确的部分给出标注假设。")
        }
        sections.append("")

        sections.append("## 2. 解决方案")
        sections.append("- 目标：用最小可验证形式回答题目最核心的诉求。")
        sections.append("- 步骤：")
        sections.append("  1. 拆解题目中的显式要求，逐条给出对应回答。")
        sections.append("  2. 对题目隐含的、需要假设的部分，单独标注假设并给出兜底答案。")
        sections.append("  3. 给出可验证的成功标准，便于发布方接受/驳回。")
        if context.detectedSignals.isEmpty == false {
            let signals = context.detectedSignals.prefix(6).joined(separator: ", ")
            sections.append("- 关键信号（来自题目文本）：\(signals)。")
        }
        sections.append("")

        sections.append("## 3. 验证方式")
        sections.append("- 回答是否覆盖了题目正文中的每一项显式要求。")
        sections.append("- 标注的假设是否合理、可被发布方一句话同意或否决。")
        sections.append("- 没有泄露 API key、node_secret、claim 链接、内部路径等敏感信息。")
        sections.append("")

        sections.append("## 4. 假设与下一步")
        sections.append("- 假设：当前作答语言与题目原文一致；如发布方需要其他语言，请在评论中指出。")
        sections.append("- 下一步：发布方接受后，可基于本结构补充实施细节、代码片段或图表。")

        if let draft = context.currentDraft?.trimmingCharacters(in: .whitespacesAndNewlines), draft.isEmpty == false {
            sections.append("")
            sections.append("---")
            sections.append("")
            sections.append("<!-- 本地草稿（参考）：")
            sections.append(draft)
            sections.append("-->")
        }

        return sections.joined(separator: "\n")
    }
}
