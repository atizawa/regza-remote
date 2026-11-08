import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaSample

/// UseCase がエンティティから UI の型 (SharedModels) を作るところと、UseCase に書いた手順や決まりを、
/// 見本の Repository と、呼ばれたことを記録する偽物の Repository で確かめる (通信はしない)
@MainActor
@Suite struct UseCaseTests {
    /// 2026-11-07 (土) のその時刻 (この端末の時間帯で)
    static func date(day: Int = 7, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// 決まった「今」(11/7 13:00)。表記や放送中かを、いつ走らせても同じにする
    static let now = date(hour: 13)

    /// 地デジの局と、そのサブチャンネル、BS、CS
    static func channels() throws -> [RegzaChannel] {
        let json = """
            [{"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","name":"テスト局１","ex_channel_number":"DUV_011-1","show_setting":"SHOW_REPRESENT"},
             {"channel_number":12,"rcu_channel_number":1,"channel":"JP-G00000011","name":"テスト局１サブ","ex_channel_number":"DUV_012-1","show_setting":"SHOW"},
             {"channel_number":181,"channel":"JP-G00040001","name":"テストBS","ex_channel_number":"DBS_181","show_setting":"SHOW_REPRESENT"},
             {"channel_number":55,"channel":"JP-G00060001","name":"テストCS","ex_channel_number":"DCS_055","show_setting":"SHOW"}]
            """
        return try JSONDecoder().decode([RegzaChannel].self, from: Data(json.utf8))
    }

    static func program(
        id: Int, networkId: Int = 0, serviceId: Int = 1, start: Date, minutes: Int = 45, name: String = "見本の番組", genre: Int? = nil
    ) throws -> MirakurunProgram {
        let genres = genre.map { #","genres":[{"lv1":\#($0)}]"# } ?? ""
        let json = """
            {"id":\(id),"eventId":\(id),"networkId":\(networkId),"serviceId":\(serviceId),\
            "startAt":\(Int(start.timeIntervalSince1970 * 1000)),"duration":\(minutes * 60_000),"name":"\(name)"\(genres)}
            """
        return try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
    }

    static func reservation(id: String, channelCode: String, epgContentID: String = "", start: Date, minutes: Int = 30, series: Bool = false) throws -> RegzaReservation {
        let json = """
            {"rsv_id":"\(id)","title":"予約\(id)","channel":"\(channelCode)","epg_content_id":"\(epgContentID)",\
            "start_time":\(Int(start.timeIntervalSince1970)),"duration":\(minutes * 60)\(series ? #","repeat":"weekly","series_rec":"true""# : "")}
            """
        return try JSONDecoder().decode(RegzaReservation.self, from: Data(json.utf8))
    }

    // MARK: - 番組 (GuideUseCase)

    @Test func programItemHasTextsAndReservedMark() throws {
        let onAir = try Self.program(id: 1, start: Self.date(hour: 13), genre: 3)
        let later = try Self.program(id: 2, start: Self.date(hour: 14))
        let recording = SampleRecordingRepository(reservations: [
            try Self.reservation(id: "1", channelCode: "JP-G00000001", epgContentID: later.epgContentID, start: later.start),
        ])
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: [onAir, later]), recording: recording)

        let item = guide.item(onAir, now: Self.now)
        #expect(item.startText == "13:00")
        #expect(item.timeText == "11月7日(土) 13:00 〜 13:45 · 45分")
        #expect(item.genre == 3)
        #expect(item.genreName == "ドラマ")
        #expect(item.isOnAir)
        #expect(!item.isReserved)

        let reserved = guide.item(later, now: Self.now)
        #expect(!reserved.isOnAir)
        // テレビの予約の番組 ID と、Mirakurun の番組の ID が同じ放送の番組なら予約済み
        #expect(reserved.isReserved)
        #expect(guide.item(onAir).genre == 3)
        #expect(try guide.item(Self.program(id: 3, start: Self.now)).genre == -1)
    }

    @Test func programsAreGroupedByDay() throws {
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "", programs: []), recording: SampleRecordingRepository(reservations: []))
        let days = guide.days([
            try Self.program(id: 3, start: Self.date(day: 8, hour: 9)),
            try Self.program(id: 1, start: Self.date(hour: 13)),
            try Self.program(id: 2, start: Self.date(hour: 23)),
        ], now: Self.now)
        #expect(days.map(\.label) == ["11月7日(土)", "11月8日(日)"])
        #expect(days.map { $0.programs.map(\.id) } == [[1, 2], [3]])
    }

    @Test func guideDaysRunUntilLastProgram() throws {
        let programs = [try Self.program(id: 1, start: Self.date(day: 9, hour: 10))]
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: programs), recording: SampleRecordingRepository(reservations: []))
        let days = guide.guideDays(now: Self.now)
        // 今日 (今の時刻から)、明日、そのあとは「9(月)」のように日付で書く。日付は朝 4 時から
        #expect(days.map(\.label) == ["今日", "明日", "9(月)"])
        #expect(days.map(\.kind) == [.weekday, .sunday, .weekday])
        #expect(days.first?.date == nil)
        #expect(days[1].date == Self.date(day: 8, hour: 4))
    }

    @Test func searchResultExplainsTimeAndReason() throws {
        let onAir = try Self.program(id: 1, start: Self.date(hour: 12, minute: 30), minutes: 60)
        let later = try Self.program(id: 2, start: Self.date(day: 8, hour: 21))
        let channel = try #require(Self.channels().first)
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "", programs: []), recording: SampleRecordingRepository(reservations: []))

        let byCast = guide.searchResult(ProgramSearchResult(program: onAir, matches: [.init(term: "見本太郎", field: .cast)]), channel: channel, now: Self.now)
        #expect(byCast.timeText == "放送中 〜13:30")
        #expect(byCast.reason == "見本太郎 が出演")
        #expect(byCast.channelName == "テスト局１")

        let byTitle = guide.searchResult(ProgramSearchResult(program: later, matches: [.init(term: "見本", field: .title)]), channel: channel, now: Self.now)
        #expect(byTitle.timeText == "11/8(日) 21:00〜")
        // 番組名に入っていれば、理由は言わない
        #expect(byTitle.reason == nil)
    }

    @Test func programIsFoundByIDForDetail() throws {
        let program = try Self.program(id: 7, start: Self.now)
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: [program]), recording: SampleRecordingRepository(reservations: []))
        #expect(guide.program(id: 7, channelCode: "JP-G00000001") == program)
        #expect(guide.program(id: 7, channelCode: "JP-G00000002") == nil)
    }

    // MARK: - 録画予約 (RecordingUseCase)

    @Test func reservationItemsDescribeScheduleAndChannel() async throws {
        let recording = SampleRecordingRepository(reservations: [
            try Self.reservation(id: "1", channelCode: "JP-G00000001", start: Self.date(hour: 12, minute: 45)),
            try Self.reservation(id: "2", channelCode: "JP-G00000009", start: Self.date(day: 1, hour: 21), series: true),
        ])
        let useCase = RecordingUseCase(recording: recording)
        let items = useCase.items(channels: try Self.channels(), now: Self.now)

        let recordingNow = try #require(items.first)
        #expect(recordingNow.timeText == "11月7日(土) 12:45 〜 13:15")
        #expect(recordingNow.channelName == "テスト局１")
        #expect(recordingNow.isRecording)
        #expect(recordingNow.isScheduled)
        #expect(recordingNow.repeatLabel == nil)

        let waiting = items[1]
        // 連ドラ予約で、最後に録画した回が終わっているもの (次の回を待っている)
        #expect(!waiting.isScheduled)
        #expect(waiting.isSeries)
        #expect(waiting.repeatLabel == "毎週")
        // テレビに登録されていない局は、名前を出さない
        #expect(waiting.channelName == nil)

        try await useCase.cancel(id: "1")
        #expect(useCase.reservations.map(\.id) == ["2"])
    }

    // MARK: - チャンネル (ChannelUseCase)

    @Test func channelItemsHideSubchannelsUnlessWatching() throws {
        let channels = try Self.channels()
        let programs = [
            try Self.program(id: 1, serviceId: 1, start: Self.date(hour: 12, minute: 30), minutes: 60, name: "代表の番組"),
            try Self.program(id: 2, serviceId: 0x11, start: Self.date(hour: 12, minute: 30), minutes: 60, name: "代表の番組"),
        ]
        let tv = SampleTVRepository(connection: RegzaConnection(host: "192.0.2.1"), channels: channels, nowPlaying: nil)
        let useCase = ChannelUseCase(tv: tv, guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: programs))

        #expect(useCase.bands == [.terrestrial, .bs, .cs])
        // サブチャンネルは代表と同じ番組なので出さない
        let items = useCase.items(band: .terrestrial, nowPlayingCode: nil, now: Self.now)
        #expect(items.map(\.name) == ["テスト局１"])
        let item = try #require(items.first)
        #expect(item.numberText == "011")
        #expect(item.programName == "代表の番組")
        #expect(item.hasPrograms)
        #expect(!item.isNowPlaying)
        #expect(!item.canStartOver)

        // 見ているときはサブチャンネルも出し、控えめに出す印を付ける
        let watching = useCase.items(band: .terrestrial, nowPlayingCode: "JP-G00000011", now: Self.now)
        #expect(watching.map(\.name) == ["テスト局１", "テスト局１サブ"])
        #expect(watching.last?.isNowPlaying == true)
        #expect(watching.last?.isSubchannel == true)

        #expect(useCase.items(band: .cs, nowPlayingCode: nil, now: Self.now).map(\.name) == ["テストCS"])
        #expect(useCase.channel(code: "JP-G00040001")?.name == "テストBS")
    }

    @Test func liveChannelsAreThoseMirakurunReceives() throws {
        let channels = try Self.channels()
        let tv = SampleTVRepository(connection: RegzaConnection(host: "192.0.2.1"), channels: channels, nowPlaying: nil)
        // 番組表がまだなければ、CS 以外の代表のチャンネル
        let noGuide = ChannelUseCase(tv: tv, guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: []))
        #expect(noGuide.liveBands == [.terrestrial, .bs])
        #expect(noGuide.liveItems(band: .terrestrial, watchingCode: "JP-G00000001", now: Self.now).map(\.name) == ["テスト局１"])

        // 番組表があれば、番組表がある (Mirakurun が受信している) 局だけ
        let withGuide = ChannelUseCase(tv: tv, guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: [
            try Self.program(id: 1, networkId: 4, serviceId: 1, start: Self.now),
        ]))
        #expect(withGuide.liveBands == [.bs])
        let bs = withGuide.liveItems(band: .bs, watchingCode: "JP-G00040001", now: Self.now)
        #expect(bs.map(\.name) == ["テストBS"])
        #expect(bs.first?.isNowPlaying == true)
    }

    // MARK: - テレビ (TVUseCase)

    @Test func nowPlayingItemUsesDomainTexts() {
        let tv = TVUseCase(tv: SampleTVRepository(connection: RegzaConnection(host: "192.0.2.1"), channels: [], nowPlaying: nil))
        let recorded = tv.item(RegzaNowPlaying(
            kind: .recorded, channelName: "テスト局１", title: "見本の録画", position: 60, duration: 120, isAdvancing: true
        ))
        #expect(recorded.kind == .recorded)
        #expect(recorded.captionText == "録画 · テスト局１")
        #expect(recorded.headlineText == "見本の録画")
        #expect(recorded.progress == 0.5)
        #expect(recorded.hasTimeline)

        let standby = tv.item(RegzaNowPlaying(kind: .standby))
        #expect(standby.kind == .standby)
        #expect(standby.statusText == "待機中")
        #expect(standby.headlineText == "待機中")
        #expect(standby.captionText == nil)
    }

    @Test func startOverJumpsAfterTuning() async throws {
        let repository = RecordingTVRepository()
        let tv = TVUseCase(tv: repository)
        let channel = try #require(Self.channels().first)

        try await tv.startOver()
        #expect(repository.events == ["key jumpToStart"])

        // 切り替えた直後は「始めにジャンプ」が効かないので、選局のあとに送る
        _ = try await tv.tuneAndStartOver(channel)
        #expect(repository.events == ["key jumpToStart", "tune JP-G00000001", "key jumpToStart"])
    }

    // MARK: - ライブ視聴 (StreamUseCase)

    @Test func streamCleansUpBeforeStarting() async throws {
        let repository = RecordingStreamRepository()
        let stream = StreamUseCase(stream: repository)
        let id = try await stream.startLiveStream(channelCode: "JP-G00000001")
        #expect(id == 5)
        // 前に止められずに残った、このアプリの配信を先に止めてから頼む
        #expect(repository.events == ["cleanUp", "start JP-G00000001"])
    }

    // MARK: - 設定 (SetupUseCase)

    @Test func unlinkingGuideAlsoUnlinksStream() async {
        let guide = SampleGuideRepository(guideHost: "192.0.2.2", programs: [])
        let stream = SampleStreamRepository()
        stream.saveStreamHost("192.0.2.2:8888")
        let setup = SetupUseCase(devices: RecordingDeviceRepository(), guide: guide, stream: stream)

        setup.unlinkStream()
        #expect(setup.linkedGuideHost == "192.0.2.2")
        #expect(setup.linkedStreamHost == "")

        stream.saveStreamHost("192.0.2.2:8888")
        // EPGStation は Mirakurun から放送を受け取るので、番組表を外したらライブ視聴も外す
        await setup.unlinkGuide()
        #expect(setup.linkedGuideHost == "")
        #expect(setup.linkedStreamHost == "")
    }

    @Test func setupFindsDevicesAndStreamServer() async {
        let setup = SetupUseCase(
            devices: RecordingDeviceRepository(),
            guide: SampleGuideRepository(guideHost: "", programs: []),
            stream: SampleStreamRepository()
        )
        var found: [DeviceItem] = []
        for await device in setup.findTVs() { found.append(device) }
        #expect(found == [DeviceItem(host: "192.0.2.10", name: "REGZA 55Z000", supportsPIN: true)])

        #expect(await setup.streamServer(sameAs: "192.0.2.2") == "192.0.2.2")
        #expect(await setup.streamServer(sameAs: "192.0.2.3") == nil)
        #expect(await setup.streamServer(sameAs: "") == nil)
    }
}

// MARK: - 呼ばれたことを記録する偽物の Repository

/// 送ったキーと選局を記録するテレビ
@MainActor
final class RecordingTVRepository: TVRepository {
    var events: [String] = []
    var connection = RegzaConnection(host: "192.0.2.1")
    var channels: [RegzaChannel] = []
    var timeshiftSettings: RegzaTimeshiftSettings? { nil }
    var isSample: Bool { false }

    func loadChannels(force: Bool) async throws(RegzaError) {}
    func loadTimeshiftSettings() async {}
    func send(_ key: RegzaKey) async throws(RegzaError) { events.append("key \(key)") }

    func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        events.append("tune \(channel.code)")
        return nil
    }

    func seek(to seconds: Int) async throws(RegzaError) {}
    func refresh() async throws(RegzaError) -> RegzaNowPlaying { throw .notConfigured }
    func lastNowPlaying() async -> RegzaNowPlaying? { nil }
    func locateMovedTV() async -> RegzaConnection? { nil }
    func save(_ connection: RegzaConnection) async {}
    func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> { .failure(.notConfigured) }
    func pairingUserID() -> String { "" }
}

/// 頼んだ順番を記録する配信
@MainActor
final class RecordingStreamRepository: StreamRepository {
    var events: [String] = []
    var streamHost = "192.0.2.30"
    var canStream: Bool { true }

    func saveStreamHost(_ host: String) { streamHost = host }
    func isPlayable(channelCode: String) -> Bool { true }

    func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        events.append("start \(channelCode)")
        return 5
    }

    func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL { throw .notConfigured }
    func keep(streamID: Int) async {}
    func stop(streamID: Int) async { events.append("stop \(streamID)") }
    func cleanUp() async { events.append("cleanUp") }
    func stopStalled() async {}
}

/// テレビ 1 台と、192.0.2.2 で動いている EPGStation が見つかる機器探し
struct RecordingDeviceRepository: DeviceRepository {
    func devices() -> AsyncStream<RegzaDevice> {
        AsyncStream { continuation in
            continuation.yield(RegzaDevice(host: "192.0.2.10", model: "Z000", size: "55", supportsPIN: true))
            continuation.finish()
        }
    }

    func pairing(host: String, user: String) -> any PairingSession { SamplePairingSession() }
    func findGuideServers() async -> [String] { [] }
    func findStreamServers() async -> [String] { [] }
    func isStreamServer(host: String) async -> Bool { host == "192.0.2.2" }
}

struct SamplePairingSession: PairingSession {
    func start() async throws {}
    func confirm(pin: String) async throws -> RegzaConnection { RegzaConnection() }
    func cancel() async {}
}
