import Foundation

/// Repository が使う設定値の読み書き。OS の API と保存形式を呼び出し元に出さない。
public final class PreferencesManager: Sendable {
    private let storage: any PreferencesStorage
    private let lock = NSLock()

    public init(storage: any PreferencesStorage) { self.storage = storage }

    public func value(forKey key: PreferencesKey) -> String? {
        lock.withLock { storage.value(forKey: key) }
    }

    public func setValue(_ value: String, forKey key: PreferencesKey) {
        lock.withLock { storage.setValue(value, forKey: key) }
    }

    public func integers(forKey key: PreferencesKey) -> [Int] {
        lock.withLock { Self.integers(storage.value(forKey: key)) }
    }

    public func setIntegers(_ values: [Int], forKey key: PreferencesKey) {
        lock.withLock { storage.setValue(values.map(String.init).joined(separator: ","), forKey: key) }
    }

    /// 終了時の後片づけなど、複数の実行元からの更新でも追加・削除を取りこぼさない。
    public func updateIntegers(forKey key: PreferencesKey, _ update: (inout [Int]) -> Void) {
        lock.withLock {
            var values = Self.integers(storage.value(forKey: key))
            update(&values)
            storage.setValue(values.map(String.init).joined(separator: ","), forKey: key)
        }
    }

    private static func integers(_ value: String?) -> [Int] {
        (value ?? "").split(separator: ",").compactMap { Int($0) }
    }
}
