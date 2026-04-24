import Foundation
import Security

protocol NodeSecretStoring {
    func loadNodeSecret(for senderID: String) throws -> String?
    func saveNodeSecret(_ secret: String, for senderID: String) throws
    func deleteNodeSecret(for senderID: String) throws
}

enum NodeSecretStoreError: LocalizedError {
    case invalidSecretEncoding
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidSecretEncoding:
            return "The node secret could not be encoded for secure storage."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain operation failed with status \(status)."
        }
    }
}

struct KeychainNodeSecretStore: NodeSecretStoring {
    private let service = "dev.evomapconsole.node-secret"

    func loadNodeSecret(for senderID: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: senderID,
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
            throw NodeSecretStoreError.unhandledStatus(status)
        }
    }

    func saveNodeSecret(_ secret: String, for senderID: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw NodeSecretStoreError.invalidSecretEncoding
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: senderID,
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
                throw NodeSecretStoreError.unhandledStatus(addStatus)
            }
        default:
            throw NodeSecretStoreError.unhandledStatus(status)
        }
    }

    func deleteNodeSecret(for senderID: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: senderID,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NodeSecretStoreError.unhandledStatus(status)
        }
    }
}
