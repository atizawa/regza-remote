import Foundation
import Testing
@testable import RegzaPresentation
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// 設定の ViewModel
@MainActor
@Suite struct SetupViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func serverAddressSplitsPort() {
        #expect(ServerAddress(" 192.0.2.2:40772 ") == ServerAddress(address: "192.0.2.2", port: "40772"))
        #expect(ServerAddress("192.0.2.2").saved == "192.0.2.2")
        // アドレスが空ならポートだけ入っていても連携しない
        #expect(ServerAddress(address: "", port: "8888").saved == "")
        #expect(ServerAddress(address: "", port: "8888").combined == ":8888")
        #expect(!ServerAddress("192.0.2.2:70000").isValid)
        #expect(ServerAddress("192.0.2.2:").isValid)
    }

    @Test func tvStatusAsksForPIN() {
        let live = LiveModels(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        let remote = live.remote
        let tv = TVSetupViewModel(remote: remote, setup: live.setup)
        // 保存済みの接続から始める
        #expect(tv.state.draft == remote.connection)
        #expect(tv.state.status == .init(text: "192.0.2.10", needsAttention: false))
        // このアプリの ID で登録していないので、登録済みではない
        #expect(!tv.state.isRegistered)

        tv.send(.setPassword(""))
        #expect(tv.state.status == .init(text: "PIN の登録が必要", needsAttention: true))
        tv.send(.setHost(" "))
        #expect(tv.state.status == .init(text: "未設定", needsAttention: true))
        #expect(!tv.state.canSave)
        // CLI に見せる状態には、パスワードを出さない
        tv.send(.setPassword("secret"))
        #expect(!JSONValue(reflecting: tv.introspectionValue).json.contains("secret"))
    }

    @Test func unlinkingGuideAlsoUnlinksStream() async {
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10"))
        // Repository は、作ったときに保存済みのアドレスを読む
        store.guideHost = "192.0.2.2"
        store.streamHost = "192.0.2.2:8888"
        let live = LiveModels(store: store, transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        let servers = ServerSetupViewModel(setup: live.setup)
        #expect(servers.state.guide.status == "192.0.2.2")
        #expect(servers.state.stream.isLinked)

        await fixtures.send(servers) { $0.send(.unlink(.guide)) }

        // EPGStation は Mirakurun から放送を受け取るので、一緒に外す
        #expect(servers.state.guide.status == "未設定")
        #expect(servers.state.stream.status == "未設定")
        #expect(!servers.state.stream.isLinked)
        #expect(store.guideHost == "")
        #expect(store.streamHost == "")
    }

    @Test func suggestsEPGStationOnMirakurunServer() async {
        let live = LiveModels(transport: FakeTransport { request in
            request.url.path == "/api/version" ? ViewModelFixtures.status(200, #"{"version":"2.0.0"}"#) : ViewModelFixtures.status(404)
        })
        let servers = ServerSetupViewModel(setup: live.setup)
        servers.send(.setHost(.guide, "192.0.2.2:40772"))

        await servers.suggestStreamHost()

        #expect(servers.state.stream.host == "192.0.2.2")
        #expect(servers.state.stream.hosts == ["192.0.2.2"])
        #expect(servers.state.stream.message != nil)
        // 保存するまでは入れない
        #expect(live.store.streamHost == "")
    }
}
