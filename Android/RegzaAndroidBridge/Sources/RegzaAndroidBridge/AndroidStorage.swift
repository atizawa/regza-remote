import Foundation
import RegzaApp

/// Android の保存先。Kotlin が実装し、パスワードは Android Keystore の鍵で暗号化して SharedPreferences に置く
/// (iOS のキーチェーンに当たる)。swift-java で Java のインターフェースになり、Kotlin のクラスが実装する。
/// Java を呼ぶのはメインスレッドからだけにする (AndroidConnectionStore)
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

/// 接続情報の保存先 (RegzaConnectionStore) を、Kotlin の保存先 (RegzaAndroidStorage) で作る。
/// 作るときに全部読んでメモリに持ち、変わったらメインスレッドで Kotlin の保存先に書く
/// (Android では、メインスレッド以外から Java を呼ぶと、アプリのクラスが見つからないことがある)
final class AndroidConnectionStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private let storage: MainActorStorage
    private var connection: RegzaConnection
    private let userID: String
    private var values: (guideHost: String, streamHost: String, ownStreamIDs: [Int])

    /// メインスレッドから作る
    @MainActor init(storage: any RegzaAndroidStorage) {
        func value(_ key: String) -> String { storage.value(forKey: key) ?? "" }
        connection = RegzaConnection(
            host: value(AndroidStorageKey.host), user: value(AndroidStorageKey.user), password: value(AndroidStorageKey.password)
        )
        // PIN 登録に使う ID は、初めて使うときに作って保存する (ただし iOS のキーチェーンと違い、アプリを削除すると消える)
        if let userID = storage.value(forKey: AndroidStorageKey.pairingUserID) {
            self.userID = userID
        } else {
            userID = PairingUserID.make()
            storage.setValue(userID, forKey: AndroidStorageKey.pairingUserID)
        }
        values = (
            value(AndroidStorageKey.guideHost), value(AndroidStorageKey.streamHost),
            value(AndroidStorageKey.ownStreamIDs).split(separator: ",").compactMap { Int($0) }
        )
        self.storage = MainActorStorage(storage)
    }

    func load() -> RegzaConnection { lock.withLock { connection } }
    func save(_ connection: RegzaConnection) {
        lock.withLock { self.connection = connection }
        storage.set([
            AndroidStorageKey.host: connection.host, AndroidStorageKey.user: connection.user,
            AndroidStorageKey.password: connection.password,
        ])
    }
    func pairingUserID() -> String { userID }

    var guideHost: String {
        get { lock.withLock { values.guideHost } }
        set {
            lock.withLock { values.guideHost = newValue }
            storage.set([AndroidStorageKey.guideHost: newValue])
        }
    }

    var streamHost: String {
        get { lock.withLock { values.streamHost } }
        set {
            lock.withLock { values.streamHost = newValue }
            storage.set([AndroidStorageKey.streamHost: newValue])
        }
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { values.ownStreamIDs } }
        set {
            lock.withLock { values.ownStreamIDs = newValue }
            storage.set([AndroidStorageKey.ownStreamIDs: newValue.map(String.init).joined(separator: ",")])
        }
    }
}

/// Kotlin の保存先に、メインスレッドで書く (書いた順に書く)
private final class MainActorStorage: @unchecked Sendable {
    private let storage: any RegzaAndroidStorage

    init(_ storage: any RegzaAndroidStorage) {
        self.storage = storage
    }

    func set(_ values: [String: String]) {
        Task { @MainActor in
            for (key, value) in values { self.storage.setValue(value, forKey: key) }
        }
    }
}
