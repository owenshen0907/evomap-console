import Foundation

protocol OrderWorkspacePersisting {
    func loadTrackedOrders() throws -> [TrackedServiceOrder]
    func saveTrackedOrders(_ orders: [TrackedServiceOrder]) throws
}

enum OrderWorkspaceStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "The macOS Application Support directory is unavailable."
        }
    }
}

struct LocalOrderWorkspaceStore: OrderWorkspacePersisting {
    private let fileManager: FileManager
    private let appDirectoryName = "EvomapConsole"
    private let workspaceDirectoryName = "OrderWorkspace"
    private let ordersFileName = "tracked-orders.json"
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

    func loadTrackedOrders() throws -> [TrackedServiceOrder] {
        let fileURL = try ordersFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard data.isEmpty == false else {
            return []
        }
        return try decoder.decode([TrackedServiceOrder].self, from: data)
    }

    func saveTrackedOrders(_ orders: [TrackedServiceOrder]) throws {
        let fileURL = try ordersFileURL()
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(orders)
        try data.write(to: fileURL, options: .atomic)
    }

    private func ordersFileURL() throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw OrderWorkspaceStoreError.applicationSupportUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent(appDirectoryName, isDirectory: true)
            .appendingPathComponent(workspaceDirectoryName, isDirectory: true)
            .appendingPathComponent(ordersFileName, isDirectory: false)
    }
}
