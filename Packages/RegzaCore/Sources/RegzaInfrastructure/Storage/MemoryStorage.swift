import Foundation

/// CLI・見本・テストで使う、プロセス内だけの保存先。
public final class MemorySecureStorage: SecureStorage {
    private let values: StorageValues<SecureStorageKey>
    public init(values: [SecureStorageKey: String] = [:]) { self.values = StorageValues(values) }
    public func value(forKey key: SecureStorageKey) -> String? { values.value(forKey: key) }
    public func setValue(_ value: String, forKey key: SecureStorageKey) { values.setValue(value, forKey: key) }
}

public final class MemoryPreferencesStorage: PreferencesStorage {
    private let values: StorageValues<PreferencesKey>
    public init(values: [PreferencesKey: String] = [:]) { self.values = StorageValues(values) }
    public func value(forKey key: PreferencesKey) -> String? { values.value(forKey: key) }
    public func setValue(_ value: String, forKey key: PreferencesKey) { values.setValue(value, forKey: key) }
}

private final class StorageValues<Key: Hashable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Key: String]
    init(_ values: [Key: String]) { self.values = values }
    func value(forKey key: Key) -> String? { lock.withLock { values[key] } }
    func setValue(_ value: String, forKey key: Key) { lock.withLock { values[key] = value } }
}
