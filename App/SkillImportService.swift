import Foundation

struct SkillImportService {
    private let maxSkillCharacters = 50_000
    private let minSkillCharacters = 500
    private let maxBundledFiles = 10
    private let maxBundledFileCharacters = 20_000
    private let allowedCategoryValues = Set(SkillPublishCategory.allCases.map(\.rawValue))
    private let excludedDirectoryNames: Set<String> = [
        ".git",
        ".github",
        ".idea",
        ".swiftpm",
        ".venv",
        "DerivedData",
        "build",
        "dist",
        "node_modules",
        "__pycache__",
    ]
    private let excludedFileNames: Set<String> = [
        ".DS_Store",
        "Thumbs.db",
    ]
    private let preferredFallbackDirectories = ["agents", "scripts", "references", "templates", "assets"]

    func importSkill(from skillURL: URL) throws -> SkillRecord {
        let scope = SecurityScope(urls: [skillURL.deletingLastPathComponent(), skillURL])
        return try scope.withAccess {
            let normalizedURL = try normalizedSkillURL(from: skillURL)
            let rawContent = try readTextFile(at: normalizedURL)
            let parsed = parseSkillDocument(rawContent)
            let skillDirectory = normalizedURL.deletingLastPathComponent()
            let category = inferredCategory(from: parsed.frontmatter.category, name: parsed.name, summary: parsed.summary, content: rawContent)
            let tags = inferredTags(from: parsed.frontmatter.tags, name: parsed.name, summary: parsed.summary)
            let referencedPaths = referencedBundledPaths(in: rawContent, skillDirectory: skillDirectory)
            let bundledFiles = discoverBundledFiles(skillDirectory: skillDirectory, referencedPaths: referencedPaths)
            let sourcePath = normalizedURL.path
            let skillID = makeSkillID(from: parsed.frontmatter.skillID, name: parsed.name)
            let issues = validateSkill(
                skillID: skillID,
                name: parsed.name,
                summary: parsed.summary,
                category: category,
                content: rawContent,
                bundledFiles: bundledFiles,
                sourcePath: sourcePath,
                hasFrontmatter: parsed.hasFrontmatter
            )

            return SkillRecord(
                id: UUID(),
                skillID: skillID,
                name: parsed.name,
                summary: parsed.summary,
                category: category,
                tags: tags,
                state: .draft,
                localCharacterCount: rawContent.count,
                bundledFiles: bundledFiles,
                remoteVersion: nil,
                updatedAt: fileModificationDate(for: normalizedURL) ?? Date(),
                sourcePath: sourcePath,
                content: rawContent,
                validationIssues: issues
            )
        }
    }

    private func normalizedSkillURL(from selectedURL: URL) throws -> URL {
        if selectedURL.lastPathComponent == "SKILL.md" {
            return selectedURL
        }

        let candidate = selectedURL.deletingLastPathComponent().appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw SkillImportError.invalidSelection("Choose a `SKILL.md` file.")
        }
        return candidate
    }

    private func readTextFile(at url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SkillImportError.unreadableFile("Could not read `\(url.lastPathComponent)` as UTF-8 text.")
        }
    }

    private func parseSkillDocument(_ content: String) -> ParsedSkillDocument {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            return ParsedSkillDocument(
                hasFrontmatter: false,
                frontmatter: .empty,
                name: inferredNameFromBody(content) ?? "Untitled Skill",
                summary: inferredSummary(fromBody: content),
                body: content
            )
        }

        let newlineNormalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        guard newlineNormalized.hasPrefix("---\n") else {
            return ParsedSkillDocument(
                hasFrontmatter: false,
                frontmatter: .empty,
                name: inferredNameFromBody(content) ?? "Untitled Skill",
                summary: inferredSummary(fromBody: content),
                body: content
            )
        }

        guard let closingRange = newlineNormalized.range(of: "\n---\n") else {
            return ParsedSkillDocument(
                hasFrontmatter: false,
                frontmatter: .empty,
                name: inferredNameFromBody(content) ?? "Untitled Skill",
                summary: inferredSummary(fromBody: content),
                body: content
            )
        }

        let frontmatterStart = newlineNormalized.index(newlineNormalized.startIndex, offsetBy: 4)
        let frontmatterBlock = String(newlineNormalized[frontmatterStart..<closingRange.lowerBound])
        let bodyStart = closingRange.upperBound
        let body = String(newlineNormalized[bodyStart...])
        let frontmatter = parseFrontmatter(frontmatterBlock)

        return ParsedSkillDocument(
            hasFrontmatter: true,
            frontmatter: frontmatter,
            name: frontmatter.name?.nonEmpty ?? inferredNameFromBody(body) ?? "Untitled Skill",
            summary: frontmatter.description?.nonEmpty ?? inferredSummary(fromBody: body),
            body: body
        )
    }

    private func parseFrontmatter(_ frontmatter: String) -> ParsedSkillFrontmatter {
        var name: String?
        var description: String?
        var category: String?
        var skillID: String?
        var tags: [String] = []
        var collectingArrayKey: String?
        var collectingMultilineKey: String?
        var multilineBuffer: [String] = []

        func flushMultilineBuffer() {
            guard let collectingMultilineKey else { return }
            let value = multilineBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            switch collectingMultilineKey {
            case "description":
                description = value.nonEmpty
            default:
                break
            }
            multilineBuffer = []
        }

        for rawLine in frontmatter.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if collectingMultilineKey != nil, (rawLine.hasPrefix("  ") || rawLine.hasPrefix("\t")) {
                multilineBuffer.append(rawLine.trimmingCharacters(in: .whitespaces))
                continue
            }

            if collectingMultilineKey != nil {
                flushMultilineBuffer()
                collectingMultilineKey = nil
            }

            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let collectingArrayKey, line.hasPrefix("-") {
                let value = strippedYAMLScalar(from: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                if collectingArrayKey == "tags", let value = value.nonEmpty {
                    tags.append(value)
                }
                continue
            }
            collectingArrayKey = nil

            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces).lowercased()
            let rawValue = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

            if rawValue == "|" || rawValue == ">" {
                collectingMultilineKey = key
                multilineBuffer = []
                continue
            }

            if rawValue.isEmpty {
                collectingArrayKey = key
                continue
            }

            let value = strippedYAMLScalar(from: rawValue)
            switch key {
            case "name", "title":
                name = value.nonEmpty
            case "description", "summary":
                description = value.nonEmpty
            case "category":
                category = value.nonEmpty
            case "skill_id", "skillid", "id":
                skillID = value.nonEmpty
            case "tags":
                tags.append(contentsOf: parseInlineTags(from: rawValue))
            default:
                break
            }
        }

        if collectingMultilineKey != nil {
            flushMultilineBuffer()
        }

        return ParsedSkillFrontmatter(
            name: name,
            description: description,
            category: category,
            skillID: skillID,
            tags: Array(NSOrderedSet(array: tags.compactMap(\.nonEmpty)).array as? [String] ?? [])
        )
    }

    private func parseInlineTags(from rawValue: String) -> [String] {
        let cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
            let inner = cleaned.dropFirst().dropLast()
            return inner.split(separator: ",").map { strippedYAMLScalar(from: String($0).trimmingCharacters(in: .whitespaces)) }
        }
        return [strippedYAMLScalar(from: cleaned)]
    }

    private func strippedYAMLScalar(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func inferredNameFromBody(_ body: String) -> String? {
        for line in body.split(separator: "\n").map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).nonEmpty
            }
        }
        return nil
    }

    private func inferredSummary(fromBody body: String) -> String {
        for line in body.split(separator: "\n").map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("-") || trimmed.hasPrefix("`") {
                continue
            }
            return trimmed
        }
        return "Imported local skill draft."
    }

    private func inferredCategory(from rawCategory: String?, name: String, summary: String, content: String) -> SkillPublishCategory {
        if let rawCategory = rawCategory?.nonEmpty?.lowercased(), allowedCategoryValues.contains(rawCategory), let category = SkillPublishCategory(rawValue: rawCategory) {
            return category
        }

        let signal = [name, summary, content].joined(separator: " ").lowercased()
        let repairKeywords = ["repair", "fix", "debug", "incident", "rollback", "recover", "failure", "bug"]
        let innovateKeywords = ["create", "generate", "design", "bootstrap", "invent", "launch", "prototype", "build a new"]
        let optimizeKeywords = ["optimize", "improve", "refactor", "review", "publish", "validate", "performance", "sync", "audit"]

        if repairKeywords.contains(where: signal.contains) {
            return .repair
        }
        if innovateKeywords.contains(where: signal.contains) {
            return .innovate
        }
        if optimizeKeywords.contains(where: signal.contains) {
            return .optimize
        }
        return .optimize
    }

    private func inferredTags(from rawTags: [String], name: String, summary: String) -> [String] {
        let normalizedFrontmatter = rawTags.compactMap { $0.nonEmpty?.lowercased() }
        guard normalizedFrontmatter.isEmpty else {
            return Array(NSOrderedSet(array: normalizedFrontmatter).array as? [String] ?? normalizedFrontmatter)
        }

        let slugTokens = makeSlug(from: name).split(separator: "-").map(String.init)
        let summaryTokens = summary
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        let combined = Array((slugTokens + summaryTokens).prefix(6))
        return Array(NSOrderedSet(array: combined).array as? [String] ?? combined)
    }

    private func makeSkillID(from rawSkillID: String?, name: String) -> String {
        if let rawSkillID = rawSkillID?.nonEmpty {
            return rawSkillID
        }
        return "skill_\(makeSlug(from: name).replacingOccurrences(of: "-", with: "_"))"
    }

    private func makeSlug(from value: String) -> String {
        let lowered = value.lowercased()
        let replaced = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let slug = String(replaced)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.nonEmpty ?? "untitled_skill"
    }

    private func referencedBundledPaths(in content: String, skillDirectory: URL) -> [String] {
        let pattern = #"(?:`([^`]+)`|(?:(?:[A-Za-z0-9._-]+/)+[A-Za-z0-9._-]+)|(?:/[^\s`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        var orderedPaths: [String] = []
        var seen = Set<String>()

        for match in regex.matches(in: content, options: [], range: nsRange) {
            guard let range = Range(match.range, in: content) else { continue }
            let token = String(content[range]).replacingOccurrences(of: "`", with: "")
            guard let relativePath = normalizedReferencedPath(from: token, skillDirectory: skillDirectory) else { continue }
            if seen.insert(relativePath).inserted {
                orderedPaths.append(relativePath)
            }
        }

        return orderedPaths
    }

    private func normalizedReferencedPath(from token: String, skillDirectory: URL) -> String? {
        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r()[]{}<>,.;:!?\"'"))
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return nil }

        if trimmed.hasPrefix("/") {
            let absoluteURL = URL(fileURLWithPath: trimmed)
            let rootName = skillDirectory.lastPathComponent
            let components = absoluteURL.pathComponents
            guard let rootIndex = components.lastIndex(of: rootName), rootIndex + 1 < components.count else { return nil }
            let suffix = components[(rootIndex + 1)...].joined(separator: "/")
            let candidate = skillDirectory.appendingPathComponent(suffix)
            guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
            return suffix
        }

        let candidate = skillDirectory.appendingPathComponent(trimmed)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        return trimmed
    }

    private func discoverBundledFiles(skillDirectory: URL, referencedPaths: [String]) -> [SkillBundledFile] {
        var candidates = referencedPaths
        if candidates.isEmpty {
            candidates = fallbackBundledPaths(skillDirectory: skillDirectory)
        }

        let sortedCandidates = Array(NSOrderedSet(array: candidates).array as? [String] ?? candidates)
        var files: [SkillBundledFile] = []
        var includedCount = 0

        for relativePath in sortedCandidates {
            let fileURL = skillDirectory.appendingPathComponent(relativePath)
            guard shouldConsiderFile(at: fileURL, skillDirectory: skillDirectory) else { continue }

            do {
                let content = try readTextFile(at: fileURL)
                let characterCount = content.count

                if characterCount > maxBundledFileCharacters {
                    files.append(
                        SkillBundledFile(
                            id: relativePath,
                            relativePath: relativePath,
                            characterCount: characterCount,
                            content: nil,
                            isIncluded: false,
                            note: "Excluded: bundled files must stay under \(maxBundledFileCharacters) characters."
                        )
                    )
                    continue
                }

                if includedCount >= maxBundledFiles {
                    files.append(
                        SkillBundledFile(
                            id: relativePath,
                            relativePath: relativePath,
                            characterCount: characterCount,
                            content: nil,
                            isIncluded: false,
                            note: "Excluded: preview already includes the maximum of \(maxBundledFiles) files."
                        )
                    )
                    continue
                }

                files.append(
                    SkillBundledFile(
                        id: relativePath,
                        relativePath: relativePath,
                        characterCount: characterCount,
                        content: content,
                        isIncluded: true,
                        note: nil
                    )
                )
                includedCount += 1
            } catch {
                files.append(
                    SkillBundledFile(
                        id: relativePath,
                        relativePath: relativePath,
                        characterCount: 0,
                        content: nil,
                        isIncluded: false,
                        note: "Excluded: file is not readable as UTF-8 text."
                    )
                )
            }
        }

        return files
    }

    private func fallbackBundledPaths(skillDirectory: URL) -> [String] {
        var matches: [String] = []
        for directoryName in preferredFallbackDirectories {
            let directoryURL = skillDirectory.appendingPathComponent(directoryName)
            guard FileManager.default.fileExists(atPath: directoryURL.path) else { continue }
            if let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    guard shouldConsiderFile(at: fileURL, skillDirectory: skillDirectory) else { continue }
                    matches.append(fileURL.path.replacingOccurrences(of: skillDirectory.path + "/", with: ""))
                }
            }
        }
        return matches.sorted()
    }

    private func shouldConsiderFile(at fileURL: URL, skillDirectory: URL) -> Bool {
        guard fileURL.lastPathComponent != "SKILL.md" else { return false }
        guard !excludedFileNames.contains(fileURL.lastPathComponent) else { return false }
        let pathComponents = fileURL.pathComponents
        if pathComponents.contains(where: excludedDirectoryNames.contains) {
            return false
        }
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true else {
            return false
        }
        return fileURL.path.hasPrefix(skillDirectory.path)
    }

    private func validateSkill(
        skillID: String,
        name: String,
        summary: String,
        category: SkillPublishCategory,
        content: String,
        bundledFiles: [SkillBundledFile],
        sourcePath: String,
        hasFrontmatter: Bool
    ) -> [SkillValidationIssue] {
        var issues: [SkillValidationIssue] = []

        if !hasFrontmatter {
            issues.append(.init(severity: .warning, title: "Missing frontmatter", detail: "Add YAML frontmatter with at least `name` and `description` before publishing to EvoMap."))
        }

        if content.count < minSkillCharacters {
            issues.append(.init(severity: .error, title: "Skill body too short", detail: "EvoMap Skill Store expects at least \(minSkillCharacters) characters in `content`."))
        }
        if content.count > maxSkillCharacters {
            issues.append(.init(severity: .error, title: "Skill body too large", detail: "EvoMap Skill Store limits `content` to \(maxSkillCharacters) characters."))
        }
        if summary.count < 10 {
            issues.append(.init(severity: .warning, title: "Description is thin", detail: "Provide a clearer one-line description so the publish card is searchable."))
        }
        if summary.count > 1_024 {
            issues.append(.init(severity: .error, title: "Description too long", detail: "Trim the description to roughly 1,024 characters or less."))
        }
        if name.range(of: #"(?:v?\d+\.\d+\.\d+)|(?:20\d{2}[-_/]\d{2}[-_/]\d{2})"#, options: .regularExpression) != nil {
            issues.append(.init(severity: .warning, title: "Version or date in title", detail: "Keep the published title stable; move versions and timestamps into the payload version field instead."))
        }
        if skillID.count < 8 {
            issues.append(.init(severity: .warning, title: "Skill ID is weak", detail: "Use a stable `skill_id` so future updates map to the same remote record."))
        }
        if !allowedCategoryValues.contains(category.rawValue) {
            issues.append(.init(severity: .error, title: "Invalid category", detail: "Use one of `repair`, `optimize`, or `innovate`."))
        }

        let includedFiles = bundledFiles.filter(\.isIncluded)
        if includedFiles.count > maxBundledFiles {
            issues.append(.init(severity: .error, title: "Too many bundled files", detail: "EvoMap Skill Store allows up to \(maxBundledFiles) bundled files per skill."))
        }
        if bundledFiles.contains(where: { !$0.isIncluded }) {
            issues.append(.init(severity: .warning, title: "Some companion files are excluded", detail: "At least one discovered companion file is excluded from the preview payload. Review the bundled file list before publishing."))
        }
        if includedFiles.contains(where: { $0.characterCount > maxBundledFileCharacters }) {
            issues.append(.init(severity: .error, title: "Bundled file too large", detail: "Each bundled file must stay under \(maxBundledFileCharacters) characters."))
        }

        let recommendedSections = ["trigger", "constraint", "validation", "workflow"]
        let lowered = content.lowercased()
        let missingSections = recommendedSections.filter { !lowered.contains($0) }
        if !missingSections.isEmpty {
            issues.append(.init(severity: .info, title: "Recommended sections missing", detail: "Consider adding sections for \(missingSections.joined(separator: ", ")) so the published skill is easier to route and verify."))
        }

        if !sourcePath.hasSuffix("/SKILL.md") {
            issues.append(.init(severity: .warning, title: "Unusual source file", detail: "Import directly from a file named `SKILL.md` to match EvoMap and Codex conventions."))
        }

        return issues
    }

    private func fileModificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

enum SkillImportError: LocalizedError {
    case invalidSelection(String)
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case .invalidSelection(let message), .unreadableFile(let message):
            return message
        }
    }
}

private struct ParsedSkillDocument {
    var hasFrontmatter: Bool
    var frontmatter: ParsedSkillFrontmatter
    var name: String
    var summary: String
    var body: String
}

private struct ParsedSkillFrontmatter {
    static let empty = ParsedSkillFrontmatter(name: nil, description: nil, category: nil, skillID: nil, tags: [])

    var name: String?
    var description: String?
    var category: String?
    var skillID: String?
    var tags: [String]
}

private struct SecurityScope {
    let urls: [URL]

    func withAccess<T>(_ body: () throws -> T) throws -> T {
        let started = urls.map { url in (url, url.startAccessingSecurityScopedResource()) }
        defer {
            for (url, didStart) in started where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
}

extension SkillRecord {
    func skillStorePayload(senderID: String, changelog: String? = nil) -> EvoMapSkillStoreMutationPayload {
        let bundledFiles: [EvoMapSkillStoreMutationPayload.BundledFile] = includedBundledFiles.compactMap { bundledFile in
            guard let content = bundledFile.content else { return nil }
            return EvoMapSkillStoreMutationPayload.BundledFile(name: bundledFile.relativePath, content: content)
        }

        return EvoMapSkillStoreMutationPayload(
            senderID: senderID,
            skillID: skillID,
            content: content,
            category: category.rawValue,
            tags: tags,
            bundledFiles: bundledFiles.isEmpty ? nil : bundledFiles,
            changelog: changelog?.nonEmpty
        )
    }

    func publishPayloadPreview(senderID: String?, changelog: String? = nil) -> String {
        let payload = skillStorePayload(
            senderID: senderID?.nonEmpty ?? "node_preview",
            changelog: changelog
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(payload),
              let rendered = String(data: data, encoding: .utf8) else {
            return "{\n  \"error\": \"Failed to render publish payload preview.\"\n}"
        }

        return rendered
    }
}
