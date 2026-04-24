import Foundation
import Security

protocol KnowledgeGraphAPIKeyStoring {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

enum KnowledgeGraphAPIKeyStoreError: LocalizedError {
    case invalidAPIKeyEncoding
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKeyEncoding:
            return "The Knowledge Graph API key could not be encoded for secure storage."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain operation failed with status \(status)."
        }
    }
}

struct KeychainKnowledgeGraphAPIKeyStore: KnowledgeGraphAPIKeyStoring {
    private let service = "dev.evomapconsole.kg-api-key"
    private let account = "default"

    func loadAPIKey() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KnowledgeGraphAPIKeyStoreError.unhandledStatus(status)
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KnowledgeGraphAPIKeyStoreError.invalidAPIKeyEncoding
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var createQuery = query
            createQuery[kSecValueData] = data
            createQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KnowledgeGraphAPIKeyStoreError.unhandledStatus(addStatus)
            }
        default:
            throw KnowledgeGraphAPIKeyStoreError.unhandledStatus(status)
        }
    }

    func deleteAPIKey() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KnowledgeGraphAPIKeyStoreError.unhandledStatus(status)
        }
    }
}
