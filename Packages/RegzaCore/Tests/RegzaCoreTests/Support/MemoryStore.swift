import Foundation

@testable import RegzaDomain
@testable import RegzaInfrastructure

/// テストの組み立てで使う Manager のセット。
final class MemoryStore: Sendable {
    let secureStorage: SecureStorageManager
    let preferences: PreferencesManager

    init(connection: ConnectionData) {
        secureStorage = SecureStorageManager(
            storage: MemorySecureStorage(values: [
                .password: connection.password, .pairingUserID: "00:00:5e:00:53:00",
            ]))
        preferences = PreferencesManager(storage: MemoryPreferencesStorage(values: [.host: connection.host, .user: connection.user]))
    }

    func load() -> ConnectionData {
        RegzaTVRepository.loadConnection(secureStorage: secureStorage, preferences: preferences)
    }

    var guideHost: String {
        get { preferences.value(forKey: .guideHost) ?? "" }
        set { preferences.setValue(newValue.trimmingCharacters(in: .whitespaces), forKey: .guideHost) }
    }

    var streamHost: String {
        get { preferences.value(forKey: .streamHost) ?? "" }
        set { preferences.setValue(newValue, forKey: .streamHost) }
    }

    var ownStreamIDs: [Int] {
        get { preferences.integers(forKey: .ownStreamIDs) }
        set { preferences.setIntegers(newValue, forKey: .ownStreamIDs) }
    }
}
