import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
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
        #expect(tv.state.host == remote.connection.host)
        #expect(tv.state.user == remote.connection.user)
        #expect(tv.state.hasAddress)
        #expect(tv.state.status == .init(text: "192.0.2.10", needsAttention: false))
        // このアプリの ID で登録していないので、登録済みではない
        #expect(!tv.state.isRegistered)

        tv.send(.setPassword(""))
        #expect(tv.state.status == .init(text: "PIN の登録が必要", needsAttention: true))
        tv.send(.setHost(" "))
        #expect(tv.state.status == .init(text: "未設定", needsAttention: true))
        #expect(!tv.state.canSave)
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

        servers.send(.unlink(.guide))
        while servers.isBusy { try? await Task.sleep(for: .milliseconds(10)) }

        // EPGStation は Mirakurun から放送を受け取るので、一緒に外す
        #expect(servers.state.guide.status == "未設定")
        #expect(servers.state.stream.status == "未設定")
        #expect(!servers.state.stream.isLinked)
        #expect(store.guideHost == "")
        #expect(store.streamHost == "")
    }

    @Test func suggestsEPGStationOnMirakurunServer() async {
        let live = LiveModels(
            transport: FakeTransport { request in
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

    // MARK: - 設定の画面 (SettingsViewModel)

    /// 設定の画面と、閉じた回数
    func makeSettings(store: MemoryStore = MemoryStore(connection: RegzaConnection(host: "192.0.2.10")), transport: FakeTransport)
        -> (SettingsViewModel, LiveModels, () -> Int)
    {
        let live = LiveModels(store: store, transport: transport)
        var closed = 0
        let settings = SettingsViewModel(remote: live.remote, setup: live.setup) { closed += 1 }
        return (settings, live, { closed })
    }

    @Test func settingsCombineSaveConditions() {
        let (settings, _, _) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        #expect(settings.state.path.isEmpty)
        #expect(settings.state.canSave)
        // 録画サーバーのポートが正しくなければ保存できない
        settings.send(.server(.setHost(.guide, "192.0.2.2:70000")))
        #expect(!settings.state.canSave)
        settings.send(.server(.setHost(.guide, "192.0.2.2")))
        // テレビのアドレスがなければ保存できない
        settings.send(.tv(.setHost(" ")))
        #expect(!settings.state.canSave)
    }

    /// CLI と振る舞いのテストに見せる状態には、パスワードを出さない (部品の操作は「tv.〜」で送る)
    @Test func settingsHidePassword() throws {
        let (settings, _, _) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        try settings.perform("tv.setPassword", ["password": .string("secret")])
        #expect(settings.state.tv.password == "secret")
        #expect(!settings.introspectionState.json.contains("secret"))
    }

    @Test func settingsSaveThenClose() async {
        let (settings, live, closed) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        settings.send(.server(.setHost(.guide, "192.0.2.2")))
        await fixtures.send(settings) { $0.send(.save) }
        #expect(live.store.guideHost == "192.0.2.2")
        #expect(closed() == 1)
    }

    @Test func unlinkingClosesItsPage() async {
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10"))
        store.guideHost = "192.0.2.2"
        let (settings, _, _) = makeSettings(store: store, transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        settings.send(.openPage(.guide))
        #expect(settings.state.path == [.guide])

        await fixtures.send(settings) { $0.send(.server(.unlink(.guide))) }
        #expect(settings.state.path.isEmpty)
        #expect(!settings.state.servers.guide.isLinked)
    }

    @Test func openingStreamPageSuggestsEPGStation() async {
        let (settings, _, _) = makeSettings(
            transport: FakeTransport { request in
                request.url.path == "/api/version" ? ViewModelFixtures.status(200, #"{"version":"2.0.0"}"#) : ViewModelFixtures.status(404)
            })
        settings.send(.server(.setHost(.guide, "192.0.2.2:40772")))
        await fixtures.send(settings) { $0.send(.openPage(.stream)) }
        #expect(settings.state.path == [.stream])
        #expect(settings.state.servers.stream.host == "192.0.2.2")
    }
}
