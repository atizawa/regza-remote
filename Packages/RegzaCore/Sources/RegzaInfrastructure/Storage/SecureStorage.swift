/// OS ごとの機密値の保存先。
public protocol SecureStorage: Sendable {
    func value(forKey key: SecureStorageKey) -> String?
    func setValue(_ value: String, forKey key: SecureStorageKey)
}

public enum SecureStorageKey: String, CaseIterable, Sendable {
    case password
    case pairingUserID
}
