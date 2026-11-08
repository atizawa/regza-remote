import Foundation
import Testing
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// 本物の Repository を、偽の通信と保存先でつないだもの (RegzaApp の組み立てと同じつなぎ方)
@MainActor
struct LiveModels {
    let store: MemoryStore
    let tv: RegzaTVRepository
    let remote: RemoteViewModel
    let guide: GuideUseCase
    let recording: RecordingUseCase
    let stream: StreamUseCase
    let setup: SetupUseCase

    init(store: MemoryStore = MemoryStore(connection: RegzaConnection(host: "192.0.2.10", user: "user", password: "password")),
         transport: FakeTransport) {
        self.store = store
        tv = RegzaTVRepository(store: store, remote: RegzaRemote(connection: store.load(), transport: transport))
        remote = RemoteViewModel(tv: TVUseCase(tv: tv))
        let guide = MirakurunGuideRepository(store: store, transport: transport)
        let stream = EPGStationStreamRepository(store: store, guide: guide, transport: transport)
        let recording = RegzaRecordingRepository(tv: tv)
        self.guide = GuideUseCase(guide: guide, recording: recording)
        self.recording = RecordingUseCase(recording: recording)
        self.stream = StreamUseCase(stream: stream)
        setup = SetupUseCase(devices: NetworkDeviceRepository(transport: transport), guide: guide, stream: stream)
    }

    var app: AppViewModel {
        AppViewModel(remote: remote, guide: guide, recording: recording, stream: stream, setup: setup)
    }
}

/// 共有の ViewModel を、偽の通信と保存先で確かめる (iOS と Android で同じふるまいになることの確認)
@MainActor
@Suite struct ViewModelTests {
    nonisolated static let channelList = """
        {"status":0,"total":2,"channel_list":[\
        {"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","ex_channel_number":"DUV_011-1","name":"テスト局１","show_setting":"SHOW_REPRESENT"},\
        {"channel_number":183,"rcu_channel_number":8,"channel":"JP-G00000002","ex_channel_number":"DBS_183","name":"テストBS","show_setting":"SHOW"}]}
        """
    nonisolated static let reservationList = """
        {"status":0,"rsv_list":[\
        {"rsv_id":"1","title":"テスト番組","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":4000000000,"duration":1800}]}
        """

    func makeModel(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) -> (RemoteViewModel, FakeTransport, MemoryStore) {
        let transport = FakeTransport(respond)
        let live = LiveModels(transport: transport)
        return (live.remote, transport, live.store)
    }

    nonisolated static func ok(_ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }

    @Test func tuneShowsChannelRightAway() async throws {
        let (model, transport, _) = makeModel { request in
            request.url.path.hasSuffix("channel_list") ? Self.ok(Self.channelList) : Self.ok(#"{"status":0}"#)
        }
        let observer = RecordingObserver()
        model.observer = observer
        try await model.loadChannels()
        let channel = try #require(model.channels.last)

        try await model.tune(to: channel)

        // テレビに問い合わせ直さずに、選んだチャンネルに切り替わったものとして出す
        #expect(model.state.nowPlaying?.channelCode == channel.code)
        #expect(model.nowPlayingChannel == channel)
        #expect(model.state.lastError == nil)
        #expect(model.state.tapCount == 1)
        #expect(transport.paths.last == "/v2/remote/status/channel")
        #expect(observer.events == ["update \(channel.code) connected", "tune"])
    }

    @Test func refreshFailureKeepsError() async {
        let (model, _, _) = makeModel { _ in HTTPResponse(statusCode: 500, headers: [:], body: Data()) }
        let observer = RecordingObserver()
        model.observer = observer

        await model.refresh()

        #expect(model.state.lastError == .httpStatus(500))
        #expect(model.state.nowPlaying == nil)
        #expect(observer.events == ["update - disconnected"])
    }

    @Test func savingAnotherTVForgetsWhatWasLoaded() async throws {
        let live = LiveModels(transport: FakeTransport { request in
            switch request.url.path {
            case "/v2/remote/settings/channel_list": Self.ok(Self.channelList)
            case "/v2/remote/pvr/reserves/list": Self.ok(Self.reservationList)
            default: HTTPResponse(statusCode: 500, headers: [:], body: Data())
            }
        })
        let (model, store, recording) = (live.remote, live.store, live.recording)
        try await model.loadChannels()
        try await recording.loadReservations()
        #expect(model.channels.count == 2)
        #expect(recording.reservations.map(\.id) == ["1"])

        let other = RegzaConnection(host: "192.0.2.20", user: "user", password: "password")
        await model.save(other)
        model.send(.stopPolling)

        #expect(store.load() == other)
        #expect(model.connection == other)
        #expect(model.channels.isEmpty)
        // 予約は前のテレビのものなので出さない
        #expect(recording.reservations.isEmpty)
    }

    @Test func streamNeedsGuide() {
        let live = LiveModels(transport: FakeTransport { _ in Self.ok("") })
        live.stream.saveStreamHost(" 192.0.2.30 ")
        #expect(live.store.streamHost == "192.0.2.30")
        // EPGStation は Mirakurun から放送を受け取るので、番組表がないと使わない
        #expect(!live.stream.canStream)
    }

    @Test func sampleModeDoesNotTalkToTV() async {
        let model = AppViewModel.sample(connection: RegzaConnection(host: "192.0.2.1"), nowPlaying: nil, channels: []).remote
        model.send(.press(.power))
        try? await model.loadChannels(force: true)
        #expect(model.state.tapCount == 1)
        #expect(model.state.isSampleMode)
    }

    @Test func introspectionPressesKeys() async throws {
        let (model, transport, _) = makeModel { request in
            request.url.path == "/remote/remote.htm" ? Self.ok("0") : HTTPResponse(statusCode: 500, headers: [:], body: Data())
        }
        let introspector = Introspector(root: model)
        try introspector.perform("remote", "press", ["key": .string("power")])
        #expect(model.isBusy)
        #expect(await introspector.waitUntilIdle())
        #expect(transport.paths.first == "/remote/remote.htm")
        #expect(model.state.tapCount == 1)
        #expect(throws: IntrospectionError.invalidArgument("key")) {
            try introspector.perform("remote", "press", ["key": .string("nothing")])
        }
    }
}

/// 画面ごとの ViewModel
@MainActor
@Suite struct ScreenViewModelTests {
    func makeModels(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        -> (RemoteViewModel, GuideUseCase, RecordingUseCase, StreamUseCase) {
        let live = LiveModels(transport: FakeTransport(respond))
        return (live.remote, live.guide, live.recording, live.stream)
    }

    /// 見本の Repository でつないだもの (テレビにつながない)
    func sampleApp(channels: [RegzaChannel], nowPlaying: RegzaNowPlaying? = nil, programs: [MirakurunProgram] = []) -> AppViewModel {
        AppViewModel.sample(
            connection: RegzaConnection(host: "192.0.2.1"), nowPlaying: nowPlaying, channels: channels,
            guideHost: programs.isEmpty ? "" : "192.0.2.2", programs: programs
        )
    }

    nonisolated static func status(_ code: Int, _ body: String = "") -> HTTPResponse {
        HTTPResponse(statusCode: code, headers: [:], body: Data(body.utf8))
    }

    /// 番組 (network 1・service 1・event 2)。テレビの番組 ID は JP-0000000100010002
    func program(startingIn offset: TimeInterval) throws -> MirakurunProgram {
        let start = Int((Date().timeIntervalSince1970 + offset) * 1000)
        let json = #"{"id":100010002,"eventId":2,"networkId":1,"serviceId":1,"startAt":\#(start),"duration":1800000,"name":"テスト番組"}"#
        return try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
    }

    func channel(code: String) throws -> RegzaChannel {
        let json = #"{"channel_number":11,"channel":"\#(code)","name":"テスト局"}"#
        return try JSONDecoder().decode(RegzaChannel.self, from: Data(json.utf8))
    }

    /// 操作を送り、処理が終わるまで待つ
    func send<Model: Introspectable>(_ viewModel: Model, _ send: (Model) -> Void) async {
        send(viewModel)
        _ = await Introspector(root: viewModel).waitUntilIdle()
    }

    @Test func channelListExplainsUnsupportedModel() async {
        let (remote, guide, _, stream) = makeModels { _ in Self.status(404) }
        let viewModel = ChannelListViewModel(remote: remote, guide: guide, stream: stream)
        await send(viewModel) { $0.send(.reload) }
        #expect(viewModel.state.loadErrorMessage == "この機種はチャンネル一覧の取得に対応していません。")
        #expect(!viewModel.state.isLoading)
    }

    @Test func channelListExplainsRejectedTune() async throws {
        let (remote, guide, _, stream) = makeModels { request in
            request.url.path.hasSuffix("channel_list") ? Self.status(200, ViewModelTests.channelList) : Self.status(200, #"{"status":1}"#)
        }
        let viewModel = ChannelListViewModel(remote: remote, guide: guide, stream: stream)
        await send(viewModel) { $0.send(.reload) }
        #expect(viewModel.state.bands == [.terrestrial, .bs])
        let row = try #require(viewModel.state.rows.first)
        #expect(!row.isSubchannel)

        await send(viewModel) { $0.send(.tune(row.channel)) }

        #expect(viewModel.state.tuneError == "テスト局１ に切り替えられませんでした。テレビの電源が入っているか確認してください。")
        #expect(viewModel.state.tuning == nil)
        #expect(viewModel.state.rows.first?.isNowPlaying == false)
    }

    @Test func programDetailExplainsRejectedReservation() async throws {
        let (remote, guide, recording, stream) = makeModels { request in
            request.url.path.hasSuffix("reserves/new") ? Self.status(200, #"{"status":2}"#) : Self.status(200, #"{"status":0,"rsv_list":[]}"#)
        }
        let program = try program(startingIn: 3600)
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: program, channel: try channel(code: program.channelCode)
        )
        #expect(viewModel.state.canReserve)
        #expect(!viewModel.state.canTune)

        await send(viewModel) { $0.send(.reserve(series: false)) }

        #expect(viewModel.state.message == "テレビが予約を受け付けませんでした (2)。テレビの予約一覧や録画機器を確認してください。")
        #expect(viewModel.state.reserving == nil)
        #expect(viewModel.state.reserveCount == 0)
    }

    @Test func programDetailDescribesSeriesReservation() async throws {
        let list = #"{"status":0,"rsv_list":[{"rsv_id":"1","title":"テスト番組","channel":"JP-G00010001","epg_content_id":"JP-0000000100010002","start_time":4000000000,"duration":1800,"repeat":"weekly","series_rec":"true"}]}"#
        let (remote, guide, recording, stream) = makeModels { _ in Self.status(200, list) }
        let program = try program(startingIn: 3600)
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: program, channel: try channel(code: program.channelCode)
        )
        await send(viewModel) { $0.send(.appear) }
        #expect(viewModel.state.isReserved)
        #expect(viewModel.state.reservationIsSeries == true)
        #expect(viewModel.state.reservedText == "連ドラ予約済み（毎週）")
    }

    @Test func reservationListSplitsScheduledAndWaiting() async {
        let list = """
            {"status":0,"rsv_list":[\
            {"rsv_id":"1","title":"これからの番組","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":4000000000,"duration":1800},\
            {"rsv_id":"2","title":"次の回待ち","channel":"JP-G00000009","epg_content_id":"JP-0000000000010003","start_time":1000000000,"duration":1800,"repeat":"weekly","series_rec":"true"}]}
            """
        let (remote, _, recording, _) = makeModels { request in
            request.url.path.hasSuffix("channel_list") ? Self.status(200, ViewModelTests.channelList) : Self.status(200, list)
        }
        let viewModel = ReservationListViewModel(remote: remote, recording: recording)
        await send(viewModel) { $0.send(.load) }

        let state = viewModel.state
        #expect(state.hasLoaded)
        #expect(state.scheduled.map(\.id) == ["1"])
        #expect(state.waiting.map(\.id) == ["2"])
        #expect(state.scheduled.first?.channelName == "テスト局１")
        #expect(state.scheduled.first?.isRecording == false)
        // チャンネル一覧にない局は名前を出さない
        #expect(state.waiting.first?.channelName == nil)
    }

    @Test func introspectionReachesScreensOnPath() async throws {
        let app = LiveModels(transport: FakeTransport { request in
            request.url.path.hasSuffix("channel_list") ? Self.status(200, ViewModelTests.channelList) : Self.status(500)
        }).app
        let introspector = Introspector(root: app)
        try introspector.perform("app/channelList", "reload")
        _ = await introspector.waitUntilIdle()
        try introspector.perform("app", "selectTab", ["tab": .string("channels")])
        try introspector.perform("app", "openPrograms", ["channel": .string("JP-G00000002")])
        #expect(introspector.paths().contains("app/channels-0"))
        #expect(try introspector.node("app/channels-0").actions.map(\.name) == ["appear", "reload"])
    }
}

/// 番組表と検索の ViewModel
@MainActor
@Suite struct GuideScreenViewModelTests {
    let screens = ScreenViewModelTests()

    /// テスト局１ (JP-G00000001) の番組。start は今からの秒数
    func program(id: Int, startingIn offset: TimeInterval, name: String = "テスト番組") throws -> MirakurunProgram {
        let start = Int((Date().timeIntervalSince1970 + offset) * 1000)
        let json = #"{"id":\#(id),"eventId":\#(id),"networkId":0,"serviceId":1,"startAt":\#(start),"duration":1800000,"name":"\#(name)"}"#
        return try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
    }

    func channels() throws -> [RegzaChannel] {
        try #require(try JSONDecoder().decode(RegzaChannelList.self, from: Data(ViewModelTests.channelList.utf8)).channels)
    }

    @Test func gridShowsChannelsThatHavePrograms() async throws {
        let app = screens.sampleApp(channels: try channels(), programs: [
            try program(id: 1, startingIn: 0),
            try program(id: 2, startingIn: 3 * 86_400),
        ])
        let (remote, guide, recording) = (app.remote, app.guide, app.recording)
        let viewModel = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        let state = viewModel.state

        // 番組表があるのは地デジのテスト局１だけ。BS の局は番組表がないので出さない
        #expect(state.bands == [.terrestrial])
        #expect(state.columns.map(\.channelName) == ["テスト局１"])
        #expect(state.columns.first?.programs.count == 2)
        // 今日のあと、明日から番組表がある最後の日まで
        let today = BroadcastDay.start(of: Date())
        #expect(state.days.first?.date == nil)
        #expect(state.days.dropFirst().first?.date == Calendar.current.date(byAdding: .day, value: 1, to: today))
        let lastDay = BroadcastDay.start(of: Date().addingTimeInterval(3 * 86_400))
        #expect(state.days.last?.date == lastDay)
        // 読み込むまでは検索を出さない
        #expect(!state.canSearch)

        let day = try #require(state.days.last?.date)
        viewModel.send(.selectDay(day))
        #expect(viewModel.state.selectedDay == day)
    }

    @Test func gridDescribesDays() throws {
        let today = BroadcastDay.start(of: Date())
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: today))
        #expect(GuideUseCase.label(of: nil) == "今日")
        #expect(GuideUseCase.label(of: tomorrow) == "明日")
        // 2026-11-07 は土曜、11-08 は日曜
        let saturday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 4)))
        #expect(GuideUseCase.kind(of: saturday) == .saturday)
        #expect(GuideUseCase.kind(of: saturday.addingTimeInterval(86_400)) == .sunday)
        #expect(GuideUseCase.label(of: saturday.addingTimeInterval(7 * 86_400)).hasSuffix("(土)"))
        // 今日は今の時刻の正時から 24 時間、ほかの日はその日の朝 4 時から
        let now = Date()
        let window = GuideGridViewModel.window(now: now)
        #expect(window.lowerBound <= now && now < window.lowerBound.addingTimeInterval(3600))
        #expect(window.upperBound.timeIntervalSince(window.lowerBound) == 24 * 3600)
        #expect(GuideGridViewModel.window(now: now, day: tomorrow).lowerBound == tomorrow)
    }

    @Test func searchFindsProgramsAndReadsConditions() async throws {
        let app = screens.sampleApp(channels: try channels(), programs: [
            try program(id: 1, startingIn: -60, name: "あおぞら散歩"),
            try program(id: 2, startingIn: 86_400, name: "みどり劇場"),
        ])
        let (remote, guide, recording) = (app.remote, app.guide, app.recording)
        let grid = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        let search = grid.search
        // 番組表を読むと索引を作る (読めなくても、見本の番組表はそのまま使う)
        await screens.send(grid) { $0.send(.load) }
        #expect(!search.state.isIndexing)

        search.send(.setText("あおぞら"))
        var state = search.state
        #expect(state.results.map(\.program.id) == [1])
        #expect(state.results.first?.channelName == "テスト局１")
        #expect(state.results.first?.timeText.hasPrefix("放送中 〜") == true)
        #expect(state.results.first?.reason == nil)

        // 「明日」は条件として読み取り、外すこともできる
        search.send(.setText("明日のみどり"))
        #expect(search.state.conditions.map(\.label).contains("明日"))
        #expect(search.state.results.map(\.program.id) == [2])
        search.send(.removeCondition(.day))
        state = search.state
        #expect(!state.conditions.contains { $0.condition == .day })
        #expect(state.results.map(\.program.id) == [2])
    }

    @Test func searchExplainsWhyItFoundPrograms() throws {
        let onAir = try program(id: 1, startingIn: -60)
        let byCast = ProgramSearchResult(program: onAir, matches: [.init(term: "見本太郎", field: .cast)])
        let byTitle = ProgramSearchResult(program: onAir, matches: [.init(term: "テスト", field: .title)])
        #expect(GuideUseCase.reason(for: byCast) == "見本太郎 が出演")
        #expect(GuideUseCase.reason(for: byTitle) == nil)
    }
}

/// いま映っているものの詳細のシートの ViewModel
@MainActor
@Suite struct NowPlayingViewModelTests {
    let screens = ScreenViewModelTests()

    @Test func offersPowerOnOnlyInStandby() throws {
        let channels = try GuideScreenViewModelTests().channels()

        let standby = screens.sampleApp(channels: channels, nowPlaying: RegzaNowPlaying(kind: .standby)).nowPlaying
        #expect(standby.state.canPowerOn)
        #expect(standby.state.title == "テレビ")

        let broadcast = screens.sampleApp(
            channels: channels,
            nowPlaying: RegzaNowPlaying(kind: .broadcast, channelCode: "JP-G00000001", title: "見本の番組", description: "見本の説明")
        ).nowPlaying
        let state = broadcast.state
        #expect(!state.canPowerOn)
        #expect(state.title == "視聴中")
        #expect(state.description == "見本の説明")
        // 見本のときは配信できないので、アプリで見るは出さない。タイムシフトの設定もないので最初から見るも出さない
        #expect(state.playableChannel == nil)
        #expect(!state.canStartOver)
    }
}

/// ライブ視聴の ViewModel
@MainActor
@Suite struct LivePlayerViewModelTests {
    let screens = ScreenViewModelTests()

    func makePlayer(channelCode: String, _ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        throws -> (LivePlayerViewModel, FakeTransport, MemoryStore) {
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10"))
        // 配信を頼めるのは、番組表と EPGStation の両方を設定しているとき
        store.guideHost = "192.0.2.2"
        store.streamHost = "192.0.2.30"
        let transport = FakeTransport(respond)
        let live = LiveModels(store: store, transport: transport)
        let player = LivePlayerViewModel(
            remote: live.remote, guide: live.guide, stream: live.stream, channel: try screens.channel(code: channelCode)
        )
        return (player, transport, store)
    }

    /// 条件を満たすまで待つ (配信の準備は別の Task で進む)
    func wait(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func playsThenStopsTheStream() async throws {
        let (player, transport, store) = try makePlayer(channelCode: "JP-G00000001") { request in
            switch (request.method, request.url.path) {
            case ("GET", let path) where path.hasPrefix("/api/streams/live/"):
                ScreenViewModelTests.status(200, #"{"streamId":5}"#)
            case ("GET", "/streamfiles/stream5.m3u8"):
                ScreenViewModelTests.status(200, "#EXTM3U\nsegment0.ts\n")
            default:
                ScreenViewModelTests.status(200, "{}")
            }
        }
        player.send(.start)
        await wait { if case .ready = player.state.phase { true } else { false } }

        #expect(player.state.phase == .ready(try #require(URL(string: "http://192.0.2.30:8888/streamfiles/stream5.m3u8"))))
        // 止められずに残ったときに次に開いて止められるよう、頼んだ配信を覚えておく
        #expect(store.ownStreamIDs == [5])

        player.send(.end)
        #expect(player.state.phase == .preparing)
        await wait { store.ownStreamIDs.isEmpty }
        #expect(store.ownStreamIDs.isEmpty)
        #expect(transport.paths.contains("/api/streams/5"))
    }

    @Test func explainsWhenStreamDoesNotStart() async throws {
        let (player, _, store) = try makePlayer(channelCode: "JP-G00000001") { _ in ScreenViewModelTests.status(500) }
        player.send(.start)
        await wait { if case .failed = player.state.phase { true } else { false } }
        guard case .failed(let message, let canRetry) = player.state.phase else {
            Issue.record("失敗にならなかった: \(player.state.phase)")
            return
        }
        #expect(message.hasPrefix("再生できませんでした。"))
        #expect(canRetry)
        #expect(store.ownStreamIDs.isEmpty)
    }

    @Test func refusesChannelThatEPGStationDoesNotKnow() async throws {
        let (player, transport, _) = try makePlayer(channelCode: "unknown") { _ in ScreenViewModelTests.status(200, "{}") }
        player.send(.start)
        await wait { player.state.phase != .preparing }
        #expect(player.state.phase == .failed("このチャンネルは EPGStation で見られません。", canRetry: false))
        #expect(transport.paths.isEmpty)
    }
}

/// 設定の ViewModel
@MainActor
@Suite struct SetupViewModelTests {
    let screens = ScreenViewModelTests()

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
        let live = LiveModels(transport: FakeTransport { _ in ScreenViewModelTests.status(500) })
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
        let live = LiveModels(store: store, transport: FakeTransport { _ in ScreenViewModelTests.status(500) })
        let servers = ServerSetupViewModel(setup: live.setup)
        #expect(servers.state.guide.status == "192.0.2.2")
        #expect(servers.state.stream.isLinked)

        await screens.send(servers) { $0.send(.unlink(.guide)) }

        // EPGStation は Mirakurun から放送を受け取るので、一緒に外す
        #expect(servers.state.guide.status == "未設定")
        #expect(servers.state.stream.status == "未設定")
        #expect(!servers.state.stream.isLinked)
        #expect(store.guideHost == "")
        #expect(store.streamHost == "")
    }

    @Test func suggestsEPGStationOnMirakurunServer() async {
        let live = LiveModels(transport: FakeTransport { request in
            request.url.path == "/api/version" ? ScreenViewModelTests.status(200, #"{"version":"2.0.0"}"#) : ScreenViewModelTests.status(404)
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

/// 画面の移り変わりと Introspection
@MainActor
@Suite struct AppViewModelTests {
    let guideScreens = GuideScreenViewModelTests()

    func makeApp(configured: Bool = true) throws -> AppViewModel {
        AppViewModel.sample(
            connection: RegzaConnection(host: configured ? "192.0.2.10" : ""), nowPlaying: nil, channels: try guideScreens.channels()
        )
    }

    @Test func opensAndClosesScreensPerTab() throws {
        let app = try makeApp()
        let channel = try #require(app.remote.channels.first)
        app.send(.selectTab(.channels))
        app.send(.open(.channelPrograms(channel)))
        let list = app.programList(for: channel)
        // 戻る道にある間は同じ ViewModel を使う
        #expect(app.programList(for: channel) === list)
        #expect(app.state.path(of: .channels) == [.channelPrograms(channel)])
        // ほかのタブの戻る道には入らない
        #expect(app.state.path(of: .guide).isEmpty)

        app.send(.back)
        #expect(app.state.path(of: .channels).isEmpty)
        // 閉じた画面の ViewModel は捨て、開き直すと作り直す
        #expect(app.programList(for: channel) !== list)
    }

    @Test func settingsStartFromTVWhenNotConfigured() throws {
        let app = try makeApp(configured: false)
        app.send(.showSettings)
        #expect(app.state.isShowingSettings)
        #expect(app.state.settingsPath == [.tv])
        #expect(app.settings != nil)
        app.send(.closeSettings)
        #expect(!app.state.isShowingSettings)
        #expect(app.settings == nil)
    }

    @Test func playNeedsStreamServer() throws {
        let app = try makeApp()
        let channel = try #require(app.remote.channels.first)
        // EPGStation が設定されていないので開かない
        app.send(.play(channel))
        #expect(app.state.playingChannel == nil)
        #expect(app.player == nil)
    }

    @Test func introspectionShowsStateAndActions() throws {
        let app = try makeApp()
        let introspector = Introspector(root: app)
        try introspector.perform("app", "selectTab", ["tab": .string("guide")])
        let node = try introspector.node("app")
        #expect(node.path == "app")
        guard case .object(let state) = node.state else {
            Issue.record("状態が JSON のオブジェクトになっていない: \(node.state)")
            return
        }
        #expect(state["tab"] == .string("guide"))
        #expect(state["isShowingSettings"] == .bool(false))
        #expect(node.actions.contains { $0.name == "openPrograms" })

        #expect(throws: IntrospectionError.unknownAction("fly")) { try introspector.perform("app", "fly") }
        #expect(throws: IntrospectionError.unknownPath("app/nothing")) { try introspector.node("app/nothing") }
        #expect(throws: IntrospectionError.unavailable("チャンネル none はテレビに登録されていません")) {
            try introspector.perform("app", "openPrograms", ["channel": .string("none")])
        }
    }

    @Test func reflectsValuesIntoJSON() throws {
        let channel = try #require(try guideScreens.channels().first)
        guard case .object(let object) = JSONValue(reflecting: channel) else {
            Issue.record("チャンネルが JSON のオブジェクトにならない")
            return
        }
        #expect(object["name"] == .string("テスト局１"))
        // 保存しているプロパティだけを出す (band のように計算で出すものは出さない)
        #expect(object["code"] == .string(channel.code))
        #expect(JSONValue(reflecting: AppViewModel.Route.search) == .string("search"))
        #expect(JSONValue(reflecting: Optional<Int>.none) == .null)
        #expect(JSONValue(reflecting: [1, 2]) == .array([.number(1), .number(2)]))
    }
}

/// 決めた返事を返し、届いた問い合わせを覚えておく
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let respond: @Sendable (HTTPRequest) -> HTTPResponse
    private let lock = NSLock()
    private var requests: [HTTPRequest] = []

    init(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.respond = respond
    }

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return requests.map(\.url.path)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { requests.append(request) }
        return respond(request)
    }
}

final class MemoryStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private var values: (guideHost: String, streamHost: String, ownStreamIDs: [Int]) = ("", "", [])

    init(connection: RegzaConnection) {
        self.connection = connection
    }

    func load() -> RegzaConnection {
        lock.lock(); defer { lock.unlock() }
        return connection
    }

    func save(_ connection: RegzaConnection) {
        lock.lock(); self.connection = connection; lock.unlock()
    }

    func pairingUserID() -> String { "00:00:5e:00:53:00" }

    var guideHost: String {
        get { lock.lock(); defer { lock.unlock() }; return values.guideHost }
        set { lock.lock(); values.guideHost = newValue.trimmingCharacters(in: .whitespaces); lock.unlock() }
    }

    var streamHost: String {
        get { lock.lock(); defer { lock.unlock() }; return values.streamHost }
        set { lock.lock(); values.streamHost = newValue; lock.unlock() }
    }

    var ownStreamIDs: [Int] {
        get { lock.lock(); defer { lock.unlock() }; return values.ownStreamIDs }
        set { lock.lock(); values.ownStreamIDs = newValue; lock.unlock() }
    }
}

@MainActor
final class RecordingObserver: RemoteViewModelObserver {
    private(set) var events: [String] = []

    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async {
        events.append("update \(nowPlaying?.channelCode ?? "-") \(isConnected ? "connected" : "disconnected")")
    }

    func remoteViewModelDidTune(_ model: RemoteViewModel) async {
        events.append("tune")
    }
}
