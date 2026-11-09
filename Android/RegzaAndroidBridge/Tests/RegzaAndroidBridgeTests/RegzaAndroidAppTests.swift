import Foundation
import Testing
@testable import RegzaAndroidBridge
import RegzaApp
import RegzaSample

/// Android の窓口が、共有の ViewModel の state を Android 向けに詰め直し、Android からの操作を
/// ViewModel の操作に置き換えることを、見本の ViewModel (テレビにつながない) で確かめる
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RegzaAndroidAppTests {
    /// 見本の局 (network 1 の service 1〜2)
    static let channelCodes = [BroadcastID.channelCode(networkId: 1, serviceId: 1), BroadcastID.channelCode(networkId: 1, serviceId: 2)]

    static func channels() throws -> [RegzaChannel] {
        let items = channelCodes.enumerated().map { index, code in
            #"{"channel":"\#(code)","channel_number":\#(11 + index * 10),"rcu_channel_number":\#(index + 1),"name":"テスト局\#(index + 1)","ex_channel_number":"DUV_\#(11 + index * 10)","show_setting":"SHOW_REPRESENT"}"#
        }
        return try JSONDecoder().decode([RegzaChannel].self, from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    /// テスト局１の番組。放送中のもの (id 1) と、明日のもの (id 2)
    static func programs() throws -> [MirakurunProgram] {
        let now = Date().timeIntervalSince1970
        let items = [(1, now - 600, "放送中の番組"), (2, now + 86_400, "明日の番組")].map { id, start, name in
            #"{"id":\#(id),"eventId":\#(id),"networkId":1,"serviceId":1,"startAt":\#(Int(start * 1000)),"duration":1800000,"name":"\#(name)"}"#
        }
        return try JSONDecoder().decode([MirakurunProgram].self, from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    /// 窓口と、その中の ViewModel
    struct Fixture {
        let bridge: RegzaAndroidApp
        let app: AppViewModel
    }

    func make(host: String = "192.0.2.1", guide: Bool = true) throws -> Fixture {
        let app = AppViewModel.sample(
            connection: RegzaConnection(host: host), nowPlaying: nil, channels: try Self.channels(),
            guideHost: guide ? "192.0.2.2" : "", programs: guide ? try Self.programs() : []
        )
        return Fixture(bridge: RegzaAndroidApp(app: app), app: app)
    }

    /// 本物の Repository を偽の通信でつなぎ、ライブ視聴 (EPGStation) も設定してあるものを組み立てる (配信は頼まない)
    func makeWithStream() async throws -> Fixture {
        let store = AndroidConnectionStore(storage: MemoryStorage([
            AndroidStorageKey.host: "192.0.2.1", AndroidStorageKey.guideHost: "192.0.2.2", AndroidStorageKey.streamHost: "192.0.2.30",
        ]))
        let transport = ChannelListTransport()
        let app = AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport), transport: transport)
        // 局を引けるよう、チャンネル一覧を読んでおく
        app.remote.send(.loadChannels(force: false))
        _ = await Introspector(root: app).waitUntilIdle()
        return Fixture(bridge: RegzaAndroidApp(app: app), app: app)
    }

    // MARK: - アプリ全体の状態

    @Test func startsFromTVSettingsWhenNotConfigured() async throws {
        let fixture = try make(host: "")
        #expect(await fixture.bridge.appState(route: nil)?.isShowingSettings == true)
        #expect(await fixture.bridge.settingsState(route: nil)?.path == [.tv])
    }

    // MARK: - 保存先

    /// 保存してある値を読み、PIN 登録に使う ID がなければ作って保存する
    @Test func storeReadsSavedValues() {
        let storage = MemoryStorage([
            AndroidStorageKey.host: "192.0.2.1", AndroidStorageKey.user: "user", AndroidStorageKey.password: "secret",
            AndroidStorageKey.guideHost: "192.0.2.2", AndroidStorageKey.ownStreamIDs: "1,2",
        ])
        let store = AndroidConnectionStore(storage: storage)
        #expect(store.load() == RegzaConnection(host: "192.0.2.1", user: "user", password: "secret"))
        #expect(store.guideHost == "192.0.2.2")
        #expect(store.streamHost == "")
        #expect(store.ownStreamIDs == [1, 2])
        #expect(!store.pairingUserID().isEmpty)
        #expect(storage.values[AndroidStorageKey.pairingUserID] == store.pairingUserID())
        // 作った ID は次に開いたときも同じ
        #expect(AndroidConnectionStore(storage: storage).pairingUserID() == store.pairingUserID())
    }

    /// 変わった値は、メインスレッドで Kotlin の保存先に書く
    @Test func storeWritesChangedValues() async throws {
        let storage = MemoryStorage([:])
        let store = AndroidConnectionStore(storage: storage)
        store.save(RegzaConnection(host: "192.0.2.1", user: "user", password: "secret"))
        store.streamHost = "192.0.2.30"
        store.ownStreamIDs = [3, 4]
        try await waitUntil { storage.values[AndroidStorageKey.ownStreamIDs] == "3,4" }
        #expect(storage.values[AndroidStorageKey.host] == "192.0.2.1")
        #expect(storage.values[AndroidStorageKey.password] == "secret")
        #expect(storage.values[AndroidStorageKey.streamHost] == "192.0.2.30")
    }

    @Test func keysAreSentToTheRemote() async throws {
        let fixture = try make()
        fixture.bridge.perform(RemoteAction.press(.power))
        #expect(fixture.app.remote.state.tapCount == 1)
        #expect(await fixture.bridge.remoteState(route: nil) == fixture.app.remote.state)
    }

    /// いま映っているものの詳細は、開いている間だけ state をそのまま渡す
    @Test func nowPlayingDetailIsPassedWhileShowing() async throws {
        let fixture = try make()
        #expect(await fixture.bridge.nowPlayingState(route: nil) == nil)
        fixture.bridge.perform(AppAction.showNowPlaying)
        fixture.bridge.perform(NowPlayingAction.appear)
        #expect(await fixture.bridge.nowPlayingState(route: nil) == fixture.app.nowPlaying.state)
        fixture.bridge.perform(AppAction.closeNowPlaying)
        #expect(await fixture.bridge.nowPlayingState(route: nil) == nil)
    }

    // MARK: - 見本

    /// 見本の返事で組み立てると、見本のテレビを登録し、チャンネル一覧を見本の返事から読む
    @Test func sampleReadsSampleResponses() async throws {
        let storage = MemoryStorage([:])
        let bridge = try #require(RegzaAndroidApp.sample(storage: storage, fixture: ""))
        #expect(storage.values[AndroidStorageKey.host] == "192.0.2.10")
        #expect(await bridge.appState(route: nil)?.isShowingSettings == false)

        bridge.perform(AppAction.selectTab(.channels))
        bridge.perform(ChannelListAction.appear)
        try await waitUntil { (await bridge.channelListState(route: nil)?.rows.count ?? 0) > 0 }
        #expect(await bridge.channelListState(route: nil)?.rows.first?.name == "テスト局１")
    }

    // MARK: - 画面の state

    /// タブの最初の画面の state は、route を渡さずに型で引く
    @Test func tabRootStatesAreFoundByType() async throws {
        let fixture = try make()
        fixture.bridge.perform(AppAction.selectTab(.channels))
        #expect(await fixture.bridge.appState(route: nil)?.tab == .channels)
        #expect(await fixture.bridge.channelListState(route: nil) == fixture.app.channelList.state)
        #expect(await fixture.bridge.reservationListState(route: nil) == fixture.app.reservationList.state)
        #expect(await fixture.bridge.guideGridState(route: nil)?.hasGuide == true)
    }

    /// path の画面の state は、route で引く
    @Test func opensProgramsAndDetailThenGoesBack() async throws {
        let fixture = try make()
        let code = Self.channelCodes[0]
        let programs = AppRoute.channelPrograms(channelCode: code)
        let detail = AppRoute.programDetail(programID: 1, channelCode: code)
        fixture.bridge.perform(AppAction.selectTab(.channels))

        fixture.bridge.perform(AppAction.push(programs))
        #expect(await fixture.bridge.programListState(route: programs)?.channelName == "テスト局1")
        #expect(await fixture.bridge.appState(route: nil)?.path(of: .channels) == [programs])

        fixture.bridge.perform(AppAction.push(detail))
        let detailState = try #require(await fixture.bridge.programDetailState(route: detail))
        #expect(detailState.program.name == "放送中の番組")
        #expect(detailState.channelName == "テスト局1")

        fixture.bridge.perform(AppAction.pop)
        fixture.bridge.perform(AppAction.pop)
        #expect(await fixture.bridge.appState(route: nil)?.path(of: .channels).isEmpty == true)
    }

    /// 見つからない番組の画面の state は nil
    @Test func unknownProgramHasNoState() async throws {
        let fixture = try make()
        #expect(await fixture.bridge.programDetailState(route: .programDetail(programID: 999, channelCode: Self.channelCodes[0])) == nil)
    }

    /// next は、渡した state から変わるまで待って返す (呼ぶ前に変わっていれば、すぐ返す)
    @Test func nextStateWaitsForChange() async throws {
        let fixture = try make()
        let before = try #require(await fixture.bridge.appState(route: nil))
        async let next = fixture.bridge.nextAppState(route: nil, after: before)
        fixture.bridge.perform(AppAction.selectTab(.guide))
        #expect(await next?.tab == .guide)
        // 古い state を渡せば、待たずにいまの state を返す
        #expect(await fixture.bridge.nextAppState(route: nil, after: before)?.tab == .guide)
    }

    /// 画面ごとの操作は、その型を Action にしている ViewModel に届く
    @Test func screenActionsReachTheirViewModel() async throws {
        let fixture = try make()
        fixture.bridge.perform(AppAction.selectTab(.channels))
        #expect(!fixture.app.channelList.isBusy)
        fixture.bridge.perform(ChannelListAction.reload)
        #expect(fixture.app.channelList.isBusy)
    }

    /// 窓口のつなぎ (Generated/ScreenActions.swift と swift-java の設定) が、State/ と Action/ の型から作り直したものと同じ
    @Test func screenGlueIsUpToDate() throws {
        let script = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../scripts/generate-screen-glue.sh").standardized
        let process = Process()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [script.path(percentEncoded: false), "--check"]
        let error = Pipe()
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let message = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(process.terminationStatus == 0, "\(message)")
    }

    /// 戻る道の画面の操作は、いまのタブで開いている画面の ViewModel に届く
    @Test func screenActionsReachOpenedScreens() async throws {
        let fixture = try make()
        let code = Self.channelCodes[0]
        fixture.bridge.perform(AppAction.selectTab(.channels))
        fixture.bridge.perform(AppAction.push(.channelPrograms(channelCode: code)))
        let route = AppRoute.channelPrograms(channelCode: code)
        #expect(await fixture.bridge.programListState(route: route)?.days == nil)

        fixture.bridge.perform(ProgramListAction.appear)
        try await waitUntil { await fixture.bridge.programListState(route: route)?.days != nil }
        #expect(await fixture.bridge.programListState(route: route) == fixture.app.programList(channelCode: code)?.state)
    }

    /// 番組表の操作 (GuideGridAction) で日付を選ぶと、番組表の state がそのまま届く
    @Test func selectsDayWithGuideAction() async throws {
        let fixture = try make()
        fixture.bridge.perform(AppAction.selectTab(.guide))
        fixture.bridge.perform(GuideGridAction.load)
        try await waitUntil { (await fixture.bridge.guideGridState(route: nil)?.days.count ?? 0) > 1 }

        let day = try #require(await fixture.bridge.guideGridState(route: nil)?.days[1])
        fixture.bridge.perform(GuideGridAction.selectDay(day.date))
        let guide = try #require(await fixture.bridge.guideGridState(route: nil))
        #expect(guide == fixture.app.guideGrid.state)
        #expect(guide.selectedDayIndex == 1)
        #expect(!guide.isToday)
    }

    /// 検索の操作 (GuideSearchAction) で読み取った条件を外すと、検索の state がそのまま届く
    @Test func removesSearchConditionWithSearchAction() async throws {
        let fixture = try make()
        fixture.bridge.perform(AppAction.selectTab(.guide))
        fixture.bridge.perform(AppAction.push(.search))
        fixture.bridge.perform(GuideSearchAction.setText("明日の夜"))
        let before = try #require(await fixture.bridge.guideSearchState(route: .search))
        #expect(before.conditions.count == 2)

        fixture.bridge.perform(GuideSearchAction.removeCondition(before.conditions[0].condition))
        let after = try #require(await fixture.bridge.guideSearchState(route: .search))
        #expect(after.conditions == Array(before.conditions.dropFirst()))
        #expect(after == fixture.app.guideGrid.search.state)
    }

    // MARK: - 設定

    /// 設定の操作 (SettingsAction) を送ると、設定の state がそのまま届く
    @Test func settingsActionsReachSettings() async throws {
        let fixture = try make()
        fixture.bridge.perform(AppAction.showSettings)
        #expect(await fixture.bridge.settingsState(route: nil)?.path == [])

        fixture.bridge.perform(SettingsAction.openPage(.stream))
        fixture.bridge.perform(SettingsAction.server(.setHost(.stream, "192.0.2.30")))
        let setup = try #require(await fixture.bridge.settingsState(route: nil))
        #expect(setup.path == [.stream])
        #expect(setup.servers.stream.host == "192.0.2.30")
        #expect(setup == fixture.app.settings?.state)

        fixture.bridge.perform(SettingsAction.setPath([]))
        #expect(await fixture.bridge.settingsState(route: nil)?.path == [])

        fixture.bridge.perform(SettingsAction.close)
        #expect(await fixture.bridge.settingsState(route: nil) == nil)
    }

    // MARK: - ライブ視聴

    @Test func playerOpensOnlyWhenStreamIsConfigured() async throws {
        let code = Self.channelCodes[0]
        // 見本の配信はいつも配信できないので、それで組み立てたものは開かない
        let unconfigured = try make()
        unconfigured.bridge.perform(AppAction.play(channelCode: code))
        #expect(await unconfigured.bridge.livePlayerState(route: nil) == nil)

        let fixture = try await makeWithStream()
        fixture.bridge.perform(AppAction.play(channelCode: code))
        let player = try #require(await fixture.bridge.livePlayerState(route: nil))
        #expect(player.channelCode == code)
        #expect(player.channelName == "テスト局1")
        #expect(player.phase == .preparing)

        fixture.bridge.perform(AppAction.closePlayer)
        #expect(await fixture.bridge.livePlayerState(route: nil) == nil)
    }

    /// 条件が満たされるまで待つ (見本の ViewModel も、読み込みは Task で進むため)
    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("待っている状態になりませんでした")
    }
}

/// テレビのチャンネル一覧だけに答える偽の通信 (ほかは空の成功を返す)
struct ChannelListTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let body: String
        if request.url.path == "/v2/remote/settings/channel_list" {
            let channels = RegzaAndroidAppTests.channelCodes.enumerated().map { index, code in
                #"{"channel":"\#(code)","channel_number":\#(11 + index * 10),"rcu_channel_number":\#(index + 1),"name":"テスト局\#(index + 1)","ex_channel_number":"DUV_\#(11 + index * 10)","show_setting":"SHOW_REPRESENT"}"#
            }
            body = #"{"status":0,"channel_list":[\#(channels.joined(separator: ","))]}"#
        } else {
            body = #"{"status":0}"#
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }
}

/// メモリに置くだけの保存先 (Kotlin の保存先の代わり)
final class MemoryStorage: RegzaAndroidStorage {
    var values: [String: String]

    init(_ values: [String: String]) {
        self.values = values
    }

    func value(forKey key: String) -> String? { values[key] }
    func setValue(_ value: String, forKey key: String) { values[key] = value }
}
