import Foundation

@testable import RegzaDomain
@testable import RegzaInfrastructure

/// テストの組み立てで使う Manager のセット。
final class MemoryStore: Sendable {
    let secureStorageManager: SecureStorageManager
    let preferencesManager: PreferencesManager

    init(connection: ConnectionData) {
        secureStorageManager = SecureStorageManager(
            storage: MemorySecureStorage(values: [
                .password: connection.password, .pairingUserID: "00:00:5e:00:53:00",
            ]))
        preferencesManager = PreferencesManager(
            storage: MemoryPreferencesStorage(values: [.host: connection.host, .user: connection.user]))
    }

    func load() -> ConnectionData {
        RegzaTVRepository.loadConnection(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
    }

    var guideHost: String {
        get { preferencesManager.value(forKey: .guideHost) ?? "" }
        set { preferencesManager.setValue(newValue.trimmingCharacters(in: .whitespaces), forKey: .guideHost) }
    }

    var streamHost: String {
        get { preferencesManager.value(forKey: .streamHost) ?? "" }
        set { preferencesManager.setValue(newValue, forKey: .streamHost) }
    }

    var ownStreamIDs: [Int] {
        get { preferencesManager.integers(forKey: .ownStreamIDs) }
        set { preferencesManager.setIntegers(newValue, forKey: .ownStreamIDs) }
    }
}
