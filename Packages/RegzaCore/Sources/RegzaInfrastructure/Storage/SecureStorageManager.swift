import Foundation

/// Repository が使う機密値の読み書き。保存方式は initializer で注入する。
public final class SecureStorageManager: Sendable {
    private let storage: any SecureStorage
    private let lock = NSLock()

    public init(storage: any SecureStorage) { self.storage = storage }

    public func value(forKey key: SecureStorageKey) -> String? {
        lock.withLock { storage.value(forKey: key) }
    }

    public func setValue(_ value: String, forKey key: SecureStorageKey) {
        lock.withLock { storage.setValue(value, forKey: key) }
    }

    /// 同時に呼ばれても、最初に作った値を共有する。
    public func value(forKey key: SecureStorageKey, orCreate makeValue: () -> String) -> String {
        lock.withLock {
            if let value = storage.value(forKey: key), !value.isEmpty { return value }
            let value = makeValue()
            storage.setValue(value, forKey: key)
            return value
        }
    }
}
