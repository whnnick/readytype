import Foundation
import Security

protocol APIKeyStoring {
    func saveAPIKey(_ apiKey: String, account: String) throws
    func loadAPIKey(account: String) throws -> String?
    func hasAPIKey(account: String) throws -> Bool
    func deleteAPIKey(account: String) throws
}

extension APIKeyStoring {
    func saveAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, account: "deepseek")
    }

    func loadAPIKey() throws -> String? {
        try loadAPIKey(account: "deepseek")
    }

    func hasAPIKey() throws -> Bool {
        try hasAPIKey(account: "deepseek")
    }

    func deleteAPIKey() throws {
        try deleteAPIKey(account: "deepseek")
    }
}

final class KeychainService: APIKeyStoring {
    private let service: String

    init(service: String = "com.readytype.app") {
        self.service = service
    }

    func saveAPIKey(_ apiKey: String, account: String = "deepseek") throws {
        let data = Data(apiKey.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw keychainError(addStatus)
            }
        default:
            throw keychainError(updateStatus)
        }
    }

    func loadAPIKey(account: String = "deepseek") throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let apiKey = String(data: data, encoding: .utf8)
            else {
                throw ReadyTypeError.keychainOperationFailed("Stored API Key is not valid UTF-8.")
            }
            return apiKey
        case errSecItemNotFound:
            return nil
        default:
            throw keychainError(status)
        }
    }

    func hasAPIKey(account: String = "deepseek") throws -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw keychainError(status)
        }
    }

    func deleteAPIKey(account: String = "deepseek") throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw keychainError(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> ReadyTypeError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return .keychainOperationFailed(message)
    }
}
