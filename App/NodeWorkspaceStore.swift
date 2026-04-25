import Foundation

protocol NodeWorkspacePersisting {
    func loadNodes() throws -> [NodeRecord]
    func saveNodes(_ nodes: [NodeRecord]) throws
}

enum NodeWorkspaceStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "The macOS Application Support directory is unavailable."
        }
    }
}

struct LocalNodeWorkspaceStore: NodeWorkspacePersisting {
    private let fileManager: FileManager
    private let appDirectoryName = "EvomapConsole"
    private let workspaceDirectoryName = "NodeWorkspace"
    private let nodesFileName = "nodes.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadNodes() throws -> [NodeRecord] {
        let fileURL = try nodesFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard data.isEmpty == false else {
            return []
        }
        return try decoder.decode([NodeRecord].self, from: data)
    }

    func saveNodes(_ nodes: [NodeRecord]) throws {
        let fileURL = try nodesFileURL()
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(nodes.filter { $0.isSampleData == false })
        try data.write(to: fileURL, options: .atomic)
    }

    private func nodesFileURL() throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NodeWorkspaceStoreError.applicationSupportUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent(appDirectoryName, isDirectory: true)
            .appendingPathComponent(workspaceDirectoryName, isDirectory: true)
            .appendingPathComponent(nodesFileName, isDirectory: false)
    }
}
