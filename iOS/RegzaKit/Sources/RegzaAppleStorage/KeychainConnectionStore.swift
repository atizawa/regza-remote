#if canImport(Security)
import Foundation
import RegzaApp
import Security

/// ホストとユーザー名は UserDefaults、パスワードと PIN 登録用のユーザー ID はキーチェーンに保存する。
/// キーチェーンはアプリを削除しても残るので、入れ直しても同じ ID で登録し直せる。
public struct KeychainConnectionStore: RegzaConnectionStore {
    private static let hostKey = "regza.host"
    private static let userKey = "regza.user"
    private static let guideHostKey = "mirakurun.host"
    private static let streamHostKey = "epgstation.host"
    private static let ownStreamsKey = "epgstation.ownStreams"
    private static let passwordAccount = "regza.password"
    private static let pairingUserIDAccount = "regza.pairingUserID"
    private static let service = "RegzaRemote"

    public init() {}

    public func load() -> RegzaConnection {
        let defaults = UserDefaults.standard
        return RegzaConnection(
            host: defaults.string(forKey: Self.hostKey) ?? "",
            user: defaults.string(forKey: Self.userKey) ?? "",
            password: read(account: Self.passwordAccount) ?? ""
        )
    }

    public func save(_ connection: RegzaConnection) {
        let defaults = UserDefaults.standard
        defaults.set(connection.host.trimmingCharacters(in: .whitespaces), forKey: Self.hostKey)
        defaults.set(connection.user, forKey: Self.userKey)
        write(connection.password, account: Self.passwordAccount)
    }

    public var guideHost: String {
        get { UserDefaults.standard.string(forKey: Self.guideHostKey) ?? "" }
        nonmutating set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.guideHostKey)
        }
    }

    public var streamHost: String {
        get { UserDefaults.standard.string(forKey: Self.streamHostKey) ?? "" }
        nonmutating set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.streamHostKey)
        }
    }

    public var ownStreamIDs: [Int] {
        get { UserDefaults.standard.array(forKey: Self.ownStreamsKey) as? [Int] ?? [] }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: Self.ownStreamsKey) }
    }

    public func pairingUserID() -> String {
        if let id = read(account: Self.pairingUserIDAccount) { return id }
        // 以前のバージョンは UserDefaults に保存していた。テレビの登録をそのまま使えるよう引き継ぐ
        let defaults = UserDefaults.standard
        let id =
            defaults.string(forKey: Self.pairingUserIDAccount).flatMap { $0.isEmpty ? nil : $0 }
            ?? PairingUserID.make()
        write(id, account: Self.pairingUserIDAccount)
        defaults.removeObject(forKey: Self.pairingUserIDAccount)
        return id
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: account,
        ]
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        var attributes = baseQuery(account: account)
        attributes[kSecValueData] = Data(value.utf8)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
#endif
