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
        let remoteViewModel = live.remoteViewModel
        let tvSetupViewModel = TVSetupViewModel(remoteViewModel: remoteViewModel, setupUseCase: live.setupUseCase)
        // 保存済みの接続から始める
        #expect(tvSetupViewModel.state.host == remoteViewModel.connection.host)
        #expect(tvSetupViewModel.state.user == remoteViewModel.connection.user)
        #expect(tvSetupViewModel.state.hasAddress)
        #expect(tvSetupViewModel.state.status == .init(text: "192.0.2.10", needsAttention: false))
        // このアプリの ID で登録していないので、登録済みではない
        #expect(!tvSetupViewModel.state.isRegistered)

        tvSetupViewModel.send(.setPassword(""))
        #expect(tvSetupViewModel.state.status == .init(text: "PIN の登録が必要", needsAttention: true))
        tvSetupViewModel.send(.setHost(" "))
        #expect(tvSetupViewModel.state.status == .init(text: "未設定", needsAttention: true))
        #expect(!tvSetupViewModel.state.canSave)
    }

    @Test func unlinkingGuideAlsoUnlinksStream() async {
        let store = MemoryStore(connection: ConnectionData(host: "192.0.2.10"))
        // Repository は、作ったときに保存済みのアドレスを読む
        store.guideHost = "192.0.2.2"
        store.streamHost = "192.0.2.2:8888"
        let live = LiveModels(store: store, transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        let serverSetupViewModel = ServerSetupViewModel(setupUseCase: live.setupUseCase)
        #expect(serverSetupViewModel.state.guide.status == "192.0.2.2")
        #expect(serverSetupViewModel.state.stream.isLinked)

        serverSetupViewModel.send(.unlink(.guide))
        while serverSetupViewModel.isBusy { try? await Task.sleep(for: .milliseconds(10)) }

        // EPGStation は Mirakurun から放送を受け取るので、一緒に外す
        #expect(serverSetupViewModel.state.guide.status == "未設定")
        #expect(serverSetupViewModel.state.stream.status == "未設定")
        #expect(!serverSetupViewModel.state.stream.isLinked)
        #expect(store.guideHost == "")
        #expect(store.streamHost == "")
    }

    @Test func suggestsEPGStationOnMirakurunServer() async {
        let live = LiveModels(
            transport: FakeTransport { request in
                request.url.path == "/api/version" ? ViewModelFixtures.status(200, #"{"version":"2.0.0"}"#) : ViewModelFixtures.status(404)
            })
        let serverSetupViewModel = ServerSetupViewModel(setupUseCase: live.setupUseCase)
        serverSetupViewModel.send(.setHost(.guide, "192.0.2.2:40772"))

        await serverSetupViewModel.suggestStreamHost()

        #expect(serverSetupViewModel.state.stream.host == "192.0.2.2")
        #expect(serverSetupViewModel.state.stream.hosts == ["192.0.2.2"])
        #expect(serverSetupViewModel.state.stream.message != nil)
        // 保存するまでは入れない
        #expect(live.store.streamHost == "")
    }

    // MARK: - 設定の画面 (SettingsViewModel)

    /// 設定の画面と、閉じた回数
    func makeSettings(store: MemoryStore = MemoryStore(connection: ConnectionData(host: "192.0.2.10")), transport: FakeTransport)
        -> (SettingsViewModel, LiveModels, () -> Int)
    {
        let live = LiveModels(store: store, transport: transport)
        var closed = 0
        let settingsViewModel = SettingsViewModel(remoteViewModel: live.remoteViewModel, setupUseCase: live.setupUseCase) { closed += 1 }
        return (settingsViewModel, live, { closed })
    }

    @Test func settingsCombineSaveConditions() {
        let (settingsViewModel, _, _) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        #expect(settingsViewModel.state.path.isEmpty)
        #expect(settingsViewModel.state.canSave)
        // 録画サーバーのポートが正しくなければ保存できない
        settingsViewModel.send(.server(.setHost(.guide, "192.0.2.2:70000")))
        #expect(!settingsViewModel.state.canSave)
        settingsViewModel.send(.server(.setHost(.guide, "192.0.2.2")))
        // テレビのアドレスがなければ保存できない
        settingsViewModel.send(.tv(.setHost(" ")))
        #expect(!settingsViewModel.state.canSave)
    }

    /// CLI と振る舞いのテストに見せる状態には、パスワードを出さない (部品の操作は「tv.〜」で送る)
    @Test func settingsHidePassword() throws {
        let (settingsViewModel, _, _) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        try settingsViewModel.perform("tv.setPassword", ["password": .string("secret")])
        #expect(settingsViewModel.state.tv.password == "secret")
        #expect(!settingsViewModel.introspectionState.json.contains("secret"))
    }

    @Test func settingsSaveThenClose() async {
        let (settingsViewModel, live, closed) = makeSettings(transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        settingsViewModel.send(.server(.setHost(.guide, "192.0.2.2")))
        await fixtures.send(settingsViewModel) { $0.send(.save) }
        #expect(live.store.guideHost == "192.0.2.2")
        #expect(closed() == 1)
    }

    @Test func unlinkingClosesItsPage() async {
        let store = MemoryStore(connection: ConnectionData(host: "192.0.2.10"))
        store.guideHost = "192.0.2.2"
        let (settingsViewModel, _, _) = makeSettings(store: store, transport: FakeTransport { _ in ViewModelFixtures.status(500) })
        settingsViewModel.send(.openPage(.guide))
        #expect(settingsViewModel.state.path == [.guide])

        await fixtures.send(settingsViewModel) { $0.send(.server(.unlink(.guide))) }
        #expect(settingsViewModel.state.path.isEmpty)
        #expect(!settingsViewModel.state.servers.guide.isLinked)
    }

    @Test func openingStreamPageSuggestsEPGStation() async {
        let (settingsViewModel, _, _) = makeSettings(
            transport: FakeTransport { request in
                request.url.path == "/api/version" ? ViewModelFixtures.status(200, #"{"version":"2.0.0"}"#) : ViewModelFixtures.status(404)
            })
        settingsViewModel.send(.server(.setHost(.guide, "192.0.2.2:40772")))
        await fixtures.send(settingsViewModel) { $0.send(.openPage(.stream)) }
        #expect(settingsViewModel.state.path == [.stream])
        #expect(settingsViewModel.state.servers.stream.host == "192.0.2.2")
    }
}
