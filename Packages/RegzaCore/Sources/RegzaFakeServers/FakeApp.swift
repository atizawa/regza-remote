import Foundation
import RegzaApp
import RegzaDomain
import RegzaInfrastructure

extension FakeScenario {
    /// 偽物のテレビの登録
    public static let connection = ConnectionData(host: FakeServers.Host.tv, user: "fake", password: "fake")
    /// RFC 7042 の例示用の MAC アドレス
    public static let pairingUserID = "00:00:5e:00:53:01"

    /// 場面で登録済みのものを保存先に入れる
    public func register(secureStorageManager: SecureStorageManager, preferencesManager: PreferencesManager) {
        secureStorageManager.setValue(Self.pairingUserID, forKey: .pairingUserID)
        if registersTV {
            preferencesManager.setValue(Self.connection.host, forKey: .host)
            preferencesManager.setValue(Self.connection.user, forKey: .user)
            secureStorageManager.setValue(Self.connection.password, forKey: .password)
        }
        if registersGuide { preferencesManager.setValue(FakeServers.Host.guide, forKey: .guideHost) }
        if registersStream { preferencesManager.setValue(FakeServers.Host.stream, forKey: .streamHost) }
    }
}

public enum FakeApp {
    /// 偽物とプロセス内だけの保存先で、アプリ全体の ViewModel を組み立てる
    @MainActor
    public static func makeAppViewModel(scenario: FakeScenario = .standard) -> AppViewModel {
        let secureStorageManager = SecureStorageManager(storage: MemorySecureStorage())
        let preferencesManager = PreferencesManager(storage: MemoryPreferencesStorage())
        scenario.register(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
        return AppFactory.makeLiveAppViewModel(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager,
            transport: FakeServersTransport(scenario: scenario))
    }
}
