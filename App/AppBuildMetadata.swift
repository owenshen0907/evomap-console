import Foundation

enum AppBuildMetadata {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    static let updatedAt = Bundle.main.object(forInfoDictionaryKey: "AppLastUpdatedAt") as? String ?? "2026-04-23 10:41 UTC"
}
