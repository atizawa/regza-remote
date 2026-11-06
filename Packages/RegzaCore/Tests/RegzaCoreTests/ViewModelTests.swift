import Foundation
import Testing
@testable import RegzaCore

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
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10", user: "user", password: "password"))
        let model = RemoteViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport))
        return (model, transport, store)
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
        #expect(model.nowPlaying?.channelCode == channel.code)
        #expect(model.nowPlayingChannel == channel)
        #expect(model.lastError == nil)
        #expect(model.tapCount == 1)
        #expect(transport.paths.last == "/v2/remote/status/channel")
        #expect(observer.events == ["update \(channel.code) connected", "tune"])
    }

    @Test func refreshFailureKeepsError() async {
        let (model, _, _) = makeModel { _ in HTTPResponse(statusCode: 500, headers: [:], body: Data()) }
        let observer = RecordingObserver()
        model.observer = observer

        await model.refresh()

        #expect(model.lastError == .httpStatus(500))
        #expect(model.nowPlaying == nil)
        #expect(observer.events == ["update - disconnected"])
    }

    @Test func savingAnotherTVForgetsWhatWasLoaded() async throws {
        let (model, _, store) = makeModel { request in
            switch request.url.path {
            case "/v2/remote/settings/channel_list": Self.ok(Self.channelList)
            case "/v2/remote/pvr/reserves/list": Self.ok(Self.reservationList)
            default: HTTPResponse(statusCode: 500, headers: [:], body: Data())
            }
        }
        let recording = ReservationsViewModel(remote: model)
        try await model.loadChannels()
        try await recording.loadReservations()
        #expect(model.channels.count == 2)
        #expect(recording.reservations.map(\.id) == ["1"])

        let other = RegzaConnection(host: "192.0.2.20", user: "user", password: "password")
        await model.save(other)
        model.stopPolling()

        #expect(store.load() == other)
        #expect(model.connection == other)
        #expect(model.channels.isEmpty)
        // 予約は前のテレビのものなので出さない
        #expect(recording.reservations.isEmpty)
    }

    @Test func streamNeedsGuideAndRemembersOwnStreams() {
        let (model, _, store) = makeModel { _ in Self.ok("") }
        let guide = GuideViewModel(remote: model)
        let stream = StreamViewModel(remote: model, guide: guide)
        stream.saveStreamHost(" 192.0.2.30 ")
        #expect(store.streamHost == "192.0.2.30")
        // EPGStation は Mirakurun から放送を受け取るので、番組表がないと使わない
        #expect(!stream.canStream)

        stream.started(5)
        stream.started(5)
        stream.started(7)
        stream.stopped(5)
        #expect(store.ownStreamIDs == [7])
    }

    @Test func sampleModeDoesNotTalkToTV() async {
        let (model, transport, _) = makeModel { _ in Self.ok("") }
        model.showSample(connection: RegzaConnection(host: "192.0.2.1"), nowPlaying: nil, channels: [])
        model.send(.power)
        try? await model.loadChannels(force: true)
        #expect(model.tapCount == 1)
        #expect(transport.paths.isEmpty)
    }
}

/// 画面ごとの ViewModel
@MainActor
@Suite struct ScreenViewModelTests {
    func makeModels(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        -> (RemoteViewModel, GuideViewModel, ReservationsViewModel, StreamViewModel) {
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10", user: "user", password: "password"))
        let remote = RemoteViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: FakeTransport(respond)))
        let guide = GuideViewModel(remote: remote)
        return (remote, guide, ReservationsViewModel(remote: remote), StreamViewModel(remote: remote, guide: guide))
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

    @Test func channelListExplainsUnsupportedModel() async {
        let (remote, guide, _, stream) = makeModels { _ in Self.status(404) }
        let viewModel = ChannelListViewModel(remote: remote, guide: guide, stream: stream)
        await viewModel.load(force: false)
        #expect(viewModel.loadErrorMessage == "この機種はチャンネル一覧の取得に対応していません。")
        #expect(!viewModel.isLoading)
    }

    @Test func channelListExplainsRejectedTune() async throws {
        let (remote, guide, _, stream) = makeModels { request in
            request.url.path.hasSuffix("channel_list") ? Self.status(200, ViewModelTests.channelList) : Self.status(200, #"{"status":1}"#)
        }
        let viewModel = ChannelListViewModel(remote: remote, guide: guide, stream: stream)
        await viewModel.load(force: false)
        #expect(viewModel.bands == [.terrestrial, .bs])
        let channel = try #require(viewModel.channels.first)

        await viewModel.tune(to: channel)

        #expect(viewModel.tuneError == "テスト局１ に切り替えられませんでした。テレビの電源が入っているか確認してください。")
        #expect(viewModel.tuning == nil)
        #expect(!viewModel.isNowPlaying(channel))
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
        #expect(viewModel.canReserve)
        #expect(!viewModel.canTune)

        await viewModel.reserve(series: false)

        #expect(viewModel.message == "テレビが予約を受け付けませんでした (2)。テレビの予約一覧や録画機器を確認してください。")
        #expect(viewModel.reserving == nil)
        #expect(viewModel.reserveCount == 0)
    }

    @Test func programDetailDescribesSeriesReservation() async throws {
        let list = #"{"status":0,"rsv_list":[{"rsv_id":"1","title":"テスト番組","channel":"JP-G00010001","epg_content_id":"JP-0000000100010002","start_time":4000000000,"duration":1800,"repeat":"weekly","series_rec":"true"}]}"#
        let (remote, guide, recording, stream) = makeModels { _ in Self.status(200, list) }
        let program = try program(startingIn: 3600)
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: program, channel: try channel(code: program.channelCode)
        )
        await viewModel.appear()
        #expect(viewModel.isReserved)
        #expect(viewModel.reservedText == "連ドラ予約済み（毎週）")
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
        await viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.scheduled().map(\.id) == ["1"])
        #expect(viewModel.waiting().map(\.id) == ["2"])
        #expect(viewModel.channelName(of: viewModel.scheduled()[0]) == "テスト局１")
        // チャンネル一覧にない局は名前を出さない
        #expect(viewModel.channelName(of: viewModel.waiting()[0]) == nil)
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
