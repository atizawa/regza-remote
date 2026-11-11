import Foundation
import RegzaApp

/// Android の保存先。Kotlin が実装し、パスワードは Android Keystore の鍵で暗号化して SharedPreferences に置く
/// (iOS のキーチェーンに当たる)。swift-java で Java のインターフェースになり、Kotlin のクラスが実装する。
/// Java を呼ぶのはメインスレッドからだけにする (AndroidStorageAdapter)
public protocol RegzaAndroidStorage {
    /// 保存してある値。なければ (パスワードを復号できなかったときも) nil
    func value(forKey key: String) -> String?
    func setValue(_ value: String, forKey key: String)
}

/// 保存する値のキー (Kotlin の保存先と同じ名前。前の版で保存した値もそのまま読める)
enum AndroidStorageKey {
    static let host = "host"
    static let user = "user"
    /// Kotlin の保存先が暗号化する
    static let password = "password"
    static let pairingUserID = "pairingUserID"
    static let guideHost = "guideHost"
    static let streamHost = "streamHost"
    /// 「1,2」のようにつなぐ
    static let ownStreamIDs = "ownStreamIDs"
}

/// Kotlin の保存先を共通 Manager のプロトコルに接続する。
/// 同期の読み取りはキャッシュを使い、Java への書き込みは MainActor 上で順に処理する。
final class AndroidStorageAdapter: SecureStorage, PreferencesStorage, @unchecked Sendable {
    private let storage: any RegzaAndroidStorage
    private let lock = NSLock()
    private var values: [String: String]
    private var pending: [(key: String, value: String)] = []
    private var isDraining = false

    @MainActor init(storage: any RegzaAndroidStorage) {
        self.storage = storage
        let keys = SecureStorageKey.allCases.map(\.rawValue) + PreferencesKey.allCases.map(\.rawValue)
        values = Dictionary(uniqueKeysWithValues: keys.compactMap { key in storage.value(forKey: key).map { (key, $0) } })
    }

    func value(forKey key: SecureStorageKey) -> String? { value(key.rawValue) }
    func value(forKey key: PreferencesKey) -> String? { value(key.rawValue) }
    func setValue(_ value: String, forKey key: SecureStorageKey) { set(value, key: key.rawValue) }
    func setValue(_ value: String, forKey key: PreferencesKey) { set(value, key: key.rawValue) }

    private func value(_ key: String) -> String? { lock.withLock { values[key] } }

    private func set(_ value: String, key: String) {
        let shouldDrain = lock.withLock {
            values[key] = value
            pending.append((key, value))
            if isDraining { return false }
            isDraining = true
            return true
        }
        if shouldDrain { Task { @MainActor in self.drain() } }
    }

    @MainActor private func drain() {
        while let entry = nextWrite() {
            storage.setValue(entry.value, forKey: entry.key)
        }
    }

    private func nextWrite() -> (key: String, value: String)? {
        lock.withLock {
            guard !pending.isEmpty else {
                isDraining = false
                return nil
            }
            return pending.removeFirst()
        }
    }
}

@MainActor
func makeStorageManagers(_ storage: any RegzaAndroidStorage) -> (
    secureStorageManager: SecureStorageManager, preferencesManager: PreferencesManager
) {
    let adapter = AndroidStorageAdapter(storage: storage)
    return (SecureStorageManager(storage: adapter), PreferencesManager(storage: adapter))
}
