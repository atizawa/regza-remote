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

    /// 窓口と、その中の ViewModel と保存先
    struct Fixture {
        let bridge: RegzaAndroidApp
        let app: AppViewModel
        let store: AndroidConnectionStore
    }

    func make(host: String = "192.0.2.1", guide: Bool = true, streamHost: String = "", ownStreamIDs: [Int] = []) throws -> Fixture {
        let connection = RegzaConnection(host: host)
        let store = AndroidConnectionStore(
            connection: connection, pairingUserID: "00:00:5e:00:53:00", guideHost: guide ? "192.0.2.2" : "", streamHost: streamHost,
            ownStreamIDs: ownStreamIDs
        )
        let app = AppViewModel.sample(
            connection: connection, nowPlaying: nil, channels: try Self.channels(),
            guideHost: guide ? "192.0.2.2" : "", programs: guide ? try Self.programs() : []
        )
        return Fixture(bridge: RegzaAndroidApp(app: app, store: store), app: app, store: store)
    }

    /// 本物の Repository を偽の通信でつなぎ、ライブ視聴 (EPGStation) も設定してあるものを組み立てる (配信は頼まない)
    func makeWithStream() async throws -> Fixture {
        let store = AndroidConnectionStore(
            connection: RegzaConnection(host: "192.0.2.1"), pairingUserID: "", guideHost: "192.0.2.2", streamHost: "192.0.2.30",
            ownStreamIDs: []
        )
        let transport = ChannelListTransport()
        let app = AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport), transport: transport)
        // 局を引けるよう、チャンネル一覧を読んでおく
        app.remote.send(.loadChannels(force: false))
        _ = await Introspector(root: app).waitUntilIdle()
        return Fixture(bridge: RegzaAndroidApp(app: app, store: store), app: app, store: store)
    }

    // MARK: - アプリ全体の状態

    @Test func startsFromTVSettingsWhenNotConfigured() async throws {
        let fixture = try make(host: "")
        let snapshot = await fixture.bridge.snapshot()
        #expect(snapshot.isShowingSetup)
        #expect(snapshot.setup?.path == [.tv])
    }

    @Test func snapshotCarriesConnectionAndSavedValues() async throws {
        let fixture = try make(streamHost: "192.0.2.30", ownStreamIDs: [1, 2])
        let snapshot = await fixture.bridge.snapshot()
        #expect(!snapshot.isShowingSetup)
        #expect(snapshot.tab == "remote")
        #expect(snapshot.tvHost == "192.0.2.1")
        #expect(snapshot.guideHost == "192.0.2.2")
        #expect(snapshot.streamHost == "192.0.2.30")
        #expect(snapshot.ownStreamIDs == "1,2")
    }

    /// 配信を止めて ID を消したときのように、画面の状態は変わらず保存先だけが変わっても、Kotlin に渡し直す
    @Test func savedValueChangeWakesSnapshot() async throws {
        let fixture = try make(ownStreamIDs: [3])
        _ = await fixture.bridge.snapshot()
        fixture.store.ownStreamIDs = []
        let next = await fixture.bridge.nextSnapshot()
        #expect(next.ownStreamIDs == "")
    }

    @Test func keysAreSentToTheRemote() async throws {
        let fixture = try make()
        fixture.bridge.perform(RemoteAction.press(.power))
        #expect(fixture.app.remote.state.tapCount == 1)
        #expect(await fixture.bridge.snapshot().remote == fixture.app.remote.state)
    }

    /// いま映っているものの詳細は、開いている間だけ state をそのまま渡す
    @Test func nowPlayingDetailIsPassedWhileShowing() async throws {
        let fixture = try make()
        #expect(await fixture.bridge.snapshot().nowPlayingDetail == nil)
        fixture.bridge.perform(.showNowPlaying)
        fixture.bridge.perform(NowPlayingAction.appear)
        #expect(await fixture.bridge.snapshot().nowPlayingDetail == fixture.app.nowPlaying.state)
        fixture.bridge.perform(.closeNowPlaying)
        #expect(await fixture.bridge.snapshot().nowPlayingDetail == nil)
    }

    // MARK: - 見えている画面

    @Test func tabsShowTheirScreens() async throws {
        let fixture = try make()
        #expect(await fixture.bridge.screen().kind == "remote")

        fixture.bridge.perform(.selectTab("channels"))
        #expect(await fixture.bridge.snapshot().tab == "channels")
        #expect(await fixture.bridge.screen().kind == "channels")

        fixture.bridge.perform(.selectTab("reservations"))
        #expect(await fixture.bridge.screen().kind == "reservations")

        fixture.bridge.perform(.selectTab("guide"))
        let guide = try #require(await fixture.bridge.screen().guide)
        #expect(guide.hasGuide)

        // 知らないタブの名前は無視する
        fixture.bridge.perform(.selectTab("nothing"))
        #expect(await fixture.bridge.snapshot().tab == "guide")
    }

    @Test func opensProgramsAndDetailThenGoesBack() async throws {
        let fixture = try make()
        let code = Self.channelCodes[0]
        fixture.bridge.perform(.selectTab("channels"))

        fixture.bridge.perform(.openPrograms(code))
        let programs = try #require(await fixture.bridge.screen().programs)
        #expect(programs.channelName == "テスト局1")
        #expect(await fixture.bridge.snapshot().canGoBack)

        fixture.bridge.perform(.openProgram(code, 1))
        let detail = try #require(await fixture.bridge.screen().detail)
        #expect(detail.program.name == "放送中の番組")
        #expect(detail.channelName == "テスト局1")

        fixture.bridge.perform(RegzaAndroidAction.back)
        #expect(await fixture.bridge.screen().kind == "programs")
        fixture.bridge.perform(RegzaAndroidAction.back)
        #expect(await fixture.bridge.screen().kind == "channels")
        #expect(!(await fixture.bridge.snapshot().canGoBack))
    }

    /// 画面ごとの操作は、その型を Action にしている ViewModel に届く
    @Test func screenActionsReachTheirViewModel() async throws {
        let fixture = try make()
        fixture.bridge.perform(.selectTab("channels"))
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
        fixture.bridge.perform(.selectTab("channels"))
        fixture.bridge.perform(.openPrograms(code))
        #expect(await fixture.bridge.screen().programs?.days == nil)

        fixture.bridge.perform(ProgramListAction.appear)
        try await waitUntil { await fixture.bridge.screen().programs?.days != nil }
        #expect(await fixture.bridge.screen().programs == fixture.app.programList(channelCode: code)?.state)
    }

    /// 見つからない番組を開いても、タブの最初の画面を出す
    @Test func unknownProgramFallsBackToTabScreen() async throws {
        let fixture = try make()
        fixture.bridge.perform(.selectTab("channels"))
        fixture.bridge.perform(.openProgram(Self.channelCodes[0], 999))
        #expect(await fixture.bridge.screen().kind == "channels")
    }

    /// 番組表の操作 (GuideGridAction) で日付を選ぶと、番組表の state がそのまま届く
    @Test func selectsDayWithGuideAction() async throws {
        let fixture = try make()
        fixture.bridge.perform(.selectTab("guide"))
        fixture.bridge.perform(GuideGridAction.load)
        try await waitUntil { (await fixture.bridge.screen().guide?.days.count ?? 0) > 1 }

        let day = try #require(await fixture.bridge.screen().guide?.days[1])
        fixture.bridge.perform(GuideGridAction.selectDay(day.date))
        let guide = try #require(await fixture.bridge.screen().guide)
        #expect(guide == fixture.app.guideGrid.state)
        #expect(guide.selectedDayIndex == 1)
        #expect(!guide.isToday)
    }

    /// 検索の操作 (GuideSearchAction) で読み取った条件を外すと、検索の state がそのまま届く
    @Test func removesSearchConditionWithSearchAction() async throws {
        let fixture = try make()
        fixture.bridge.perform(.selectTab("guide"))
        fixture.bridge.perform(.openSearch)
        fixture.bridge.perform(GuideSearchAction.setText("明日の夜"))
        let before = try #require(await fixture.bridge.screen().search)
        #expect(before.conditions.count == 2)

        fixture.bridge.perform(GuideSearchAction.removeCondition(before.conditions[0].condition))
        let after = try #require(await fixture.bridge.screen().search)
        #expect(after.conditions == Array(before.conditions.dropFirst()))
        #expect(after == fixture.app.guideGrid.search.state)
    }

    // MARK: - 設定

    /// 設定の操作 (SettingsAction) を送ると、設定の state がそのまま届く
    @Test func settingsActionsReachSettings() async throws {
        let fixture = try make()
        fixture.bridge.perform(.showSetup)
        #expect(await fixture.bridge.snapshot().setup?.path == [])

        fixture.bridge.perform(SettingsAction.openPage(.stream))
        fixture.bridge.perform(SettingsAction.server(.setHost(.stream, "192.0.2.30")))
        let setup = try #require(await fixture.bridge.snapshot().setup)
        #expect(setup.path == [.stream])
        #expect(setup.servers.stream.host == "192.0.2.30")
        #expect(setup == fixture.app.settings?.state)

        fixture.bridge.perform(SettingsAction.setPath([]))
        #expect(await fixture.bridge.snapshot().setup?.path == [])

        fixture.bridge.perform(SettingsAction.close)
        #expect(await fixture.bridge.snapshot().setup == nil)
    }

    // MARK: - ライブ視聴

    @Test func playerOpensOnlyWhenStreamIsConfigured() async throws {
        let code = Self.channelCodes[0]
        // 見本の配信はいつも配信できないので、それで組み立てたものは開かない
        let unconfigured = try make()
        unconfigured.bridge.perform(.play(code))
        #expect(await unconfigured.bridge.snapshot().player == nil)

        let fixture = try await makeWithStream()
        fixture.bridge.perform(.play(code))
        let player = try #require(await fixture.bridge.snapshot().player)
        #expect(player.channelCode == code)
        #expect(player.channelName == "テスト局1")
        #expect(player.phase == .preparing)

        fixture.bridge.perform(.closePlayer)
        #expect(await fixture.bridge.snapshot().player == nil)
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
