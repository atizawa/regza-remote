import Foundation

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure

/// 決めた返事を返し、届いた問い合わせを覚えておく
final class FakeHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let respond: @Sendable (HTTPRequest) -> HTTPResponse
    private let lock = NSLock()
    private var requests: [HTTPRequest] = []

    init(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.respond = respond
    }

    static func response(_ status: Int = 200, _ body: String = "") -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests.map(\.url.path)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { requests.append(request) }
        return respond(request)
    }
}

/// テストの組み立てで使う Manager のセット。
final class TestStorage: Sendable {
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

/// 本物の Repository を、偽の通信と保存先でつないだもの (RegzaApp の組み立てと同じつなぎ方)
@MainActor
struct HTTPTestEnvironment {
    let store: TestStorage
    let appViewModel: AppViewModel

    init(
        store: TestStorage = TestStorage(connection: ConnectionData(host: "192.0.2.10", user: "user", password: "password")),
        transport: FakeHTTPTransport
    ) {
        self.store = store
        appViewModel = AppFactory.makeLiveAppViewModel(
            secureStorageManager: store.secureStorageManager, preferencesManager: store.preferencesManager, transport: transport)
    }

}
