import Foundation

struct DownloadedSkillMaterialization {
    let rootDirectoryURL: URL
    let skillFileURL: URL
    let bundledFileURLs: [URL]
    let skippedBundledFileNames: [String]
}

protocol SkillWorkspacePersisting {
    func materializeDownloadedSkill(_ response: EvoMapSkillStoreDownloadResponse) throws -> DownloadedSkillMaterialization
}

enum SkillWorkspaceStoreError: LocalizedError {
    case applicationSupportUnavailable
    case invalidContentEncoding(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "The macOS Application Support directory is unavailable."
        case .invalidContentEncoding(let fileName):
            return "The downloaded file `\(fileName)` could not be written as UTF-8 text."
        }
    }
}

struct LocalSkillWorkspaceStore: SkillWorkspacePersisting {
    private let fileManager: FileManager
    private let appDirectoryName = "EvomapConsole"
    private let downloadsDirectoryName = "SkillStoreDownloads"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func materializeDownloadedSkill(_ response: EvoMapSkillStoreDownloadResponse) throws -> DownloadedSkillMaterialization {
        let rootDirectoryURL = try makeRootDirectoryURL(skillID: response.skillID, version: response.version)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        let skillFileURL = rootDirectoryURL.appendingPathComponent("SKILL.md", isDirectory: false)
        try writeText(response.content, to: skillFileURL, originalName: "SKILL.md")

        var bundledFileURLs: [URL] = []
        var skippedBundledFileNames: [String] = []

        for bundledFile in response.bundledFiles {
            guard let relativePath = sanitizedRelativePath(from: bundledFile.name) else {
                skippedBundledFileNames.append(bundledFile.name)
                continue
            }

            let destinationURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
            let parentDirectoryURL = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)
            try writeText(bundledFile.content, to: destinationURL, originalName: bundledFile.name)
            bundledFileURLs.append(destinationURL)
        }

        return DownloadedSkillMaterialization(
            rootDirectoryURL: rootDirectoryURL,
            skillFileURL: skillFileURL,
            bundledFileURLs: bundledFileURLs,
            skippedBundledFileNames: skippedBundledFileNames
        )
    }

    private func makeRootDirectoryURL(skillID: String, version: String?) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw SkillWorkspaceStoreError.applicationSupportUnavailable
        }

        let appDirectoryURL = applicationSupportURL.appendingPathComponent(appDirectoryName, isDirectory: true)
        let downloadsDirectoryURL = appDirectoryURL.appendingPathComponent(downloadsDirectoryName, isDirectory: true)
        let skillDirectoryURL = downloadsDirectoryURL.appendingPathComponent(safePathComponent(skillID), isDirectory: true)
        let versionDirectoryURL = skillDirectoryURL.appendingPathComponent(safePathComponent(version?.nonEmpty ?? "latest"), isDirectory: true)
        return versionDirectoryURL
    }

    private func writeText(_ content: String, to url: URL, originalName: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw SkillWorkspaceStoreError.invalidContentEncoding(originalName)
        }
        try data.write(to: url, options: .atomic)
    }

    private func sanitizedRelativePath(from rawName: String) -> String? {
        let normalizedSeparators = rawName.replacingOccurrences(of: "\\", with: "/")
        let trimmed = normalizedSeparators.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.hasPrefix("/") == false else {
            return nil
        }

        let rawComponents = trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard rawComponents.isEmpty == false else { return nil }

        let sanitizedComponents = rawComponents.compactMap { component -> String? in
            guard component != ".", component != ".." else { return nil }
            return safePathComponent(component)
        }

        guard sanitizedComponents.count == rawComponents.count else {
            return nil
        }

        guard sanitizedComponents.last != "SKILL.md" else {
            return nil
        }

        return sanitizedComponents.joined(separator: "/")
    }

    private func safePathComponent(_ rawValue: String) -> String {
        let sanitized = rawValue.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]+"#,
            with: "_",
            options: .regularExpression
        )
        return sanitized.nonEmpty ?? "untitled"
    }
}
