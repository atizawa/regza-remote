#if canImport(Security)
import Foundation
import RegzaCore
import Security

/// ホストとユーザー名は UserDefaults、パスワードはキーチェーンに保存する。
public struct KeychainConnectionStore: RegzaConnectionStore {
    private static let hostKey = "regza.host"
    private static let userKey = "regza.user"
    private static let passwordAccount = "regza.password"
    private static let service = "RegzaRemote"

    public init() {}

    public func load() -> RegzaConnection {
        let defaults = UserDefaults.standard
        return RegzaConnection(
            host: defaults.string(forKey: Self.hostKey) ?? "",
            user: defaults.string(forKey: Self.userKey) ?? "",
            password: readPassword() ?? ""
        )
    }

    public func save(_ connection: RegzaConnection) {
        let defaults = UserDefaults.standard
        defaults.set(connection.host.trimmingCharacters(in: .whitespaces), forKey: Self.hostKey)
        defaults.set(connection.user, forKey: Self.userKey)
        writePassword(connection.password)
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.passwordAccount,
        ]
    }

    private func readPassword() -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writePassword(_ password: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData] = Data(password.utf8)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
#endif
