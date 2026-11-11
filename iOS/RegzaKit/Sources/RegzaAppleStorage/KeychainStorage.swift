#if canImport(Security)
import Foundation
import RegzaInfrastructure
import Security

/// 既存の service・account を使う Keychain のアダプター。
public final class KeychainStorage: SecureStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let service: String

    public init(defaults: UserDefaults = .standard, service: String = "RegzaRemote") {
        self.defaults = defaults
        self.service = service
    }

    public func value(forKey key: SecureStorageKey) -> String? {
        let account = account(key)
        if let value = read(account: account) { return value }
        // 以前 UserDefaults に保存していた登録 ID を引き継ぐ。
        guard key == .pairingUserID, let legacy = defaults.string(forKey: account), !legacy.isEmpty else { return nil }
        if write(legacy, account: account) { defaults.removeObject(forKey: account) }
        return legacy
    }

    public func setValue(_ value: String, forKey key: SecureStorageKey) {
        _ = write(value, account: account(key))
    }

    private func account(_ key: SecureStorageKey) -> String {
        switch key {
        case .password: "regza.password"
        case .pairingUserID: "regza.pairingUserID"
        }
    }

    private func query(account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    private func read(account: String) -> String? {
        var query = query(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) -> Bool {
        let query = query(account: account)
        let attributes: [CFString: Any] = [kSecValueData: Data(value.utf8), kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return status == errSecSuccess }
        return SecItemAdd(query.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary, nil) == errSecSuccess
    }
}
#endif
