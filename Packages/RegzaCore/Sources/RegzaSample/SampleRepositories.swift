import Foundation
import Observation
import RegzaPresentation

// テレビにも録画サーバーにもつながない、見本の Repository。
// 開発用の見本の画面 (iOS の起動引数 -SampleData)、テスト、プレビューで使う

extension AppViewModel {
    /// 見本のデータで、アプリ全体の ViewModel を作る (テレビにはつながない)
    public static func sample(
        connection: RegzaConnection,
        nowPlaying: RegzaNowPlaying?,
        channels: [RegzaChannel],
        guideHost: String = "",
        programs: [MirakurunProgram] = [],
        reservations: [RegzaReservation] = []
    ) -> AppViewModel {
        let tv = SampleTVRepository(connection: connection, channels: channels, nowPlaying: nowPlaying)
        let guide = SampleGuideRepository(guideHost: guideHost, programs: programs)
        let stream = SampleStreamRepository()
        let recording = SampleRecordingRepository(reservations: reservations)
        return AppViewModel(
            remote: RemoteViewModel(tv: TVUseCase(tv: tv), nowPlaying: nowPlaying),
            channels: ChannelUseCase(tv: tv, guide: guide),
            guide: GuideUseCase(guide: guide, recording: recording),
            recording: RecordingUseCase(recording: recording),
            stream: StreamUseCase(stream: stream),
            setup: SetupUseCase(devices: SampleDeviceRepository(), guide: guide, stream: stream)
        )
    }
}

/// 見本のテレビ。キーを送っても何もせず、選局すると、その局に切り替わったものとして出す
@MainActor
@Observable
public final class SampleTVRepository: TVRepositoryProtocol {
    public private(set) var connection: RegzaConnection
    public private(set) var channels: [RegzaChannel]
    public var timeshiftSettings: RegzaTimeshiftSettings? { nil }
    public var isSample: Bool { true }
    private var nowPlaying: RegzaNowPlaying?

    public init(connection: RegzaConnection, channels: [RegzaChannel], nowPlaying: RegzaNowPlaying?) {
        self.connection = connection
        self.channels = channels
        self.nowPlaying = nowPlaying
    }

    public func loadChannels(force: Bool) async throws(RegzaError) {}
    public func loadTimeshiftSettings() async {}
    public func send(_ key: RegzaKey) async throws(RegzaError) {}

    public func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        nowPlaying = RegzaNowPlaying(kind: .broadcast, channelName: channel.name, channelCode: channel.code)
        return nowPlaying
    }

    public func seek(to seconds: Int) async throws(RegzaError) {}

    public func refresh() async throws(RegzaError) -> RegzaNowPlaying {
        guard let nowPlaying else { throw .notConfigured }
        return nowPlaying
    }

    public func lastNowPlaying() async -> RegzaNowPlaying? { nowPlaying }
    public func locateMovedTV() async -> RegzaConnection? { nil }

    public func save(_ connection: RegzaConnection) async {
        self.connection = connection
    }

    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        nowPlaying.map { .success($0) } ?? .failure(.notConfigured)
    }

    public func pairingUserID() -> String { "00:00:5e:00:53:01" }
}

/// 見本の番組表。渡した番組を読み込み済みのものとして持つ
@MainActor
@Observable
public final class SampleGuideRepository: GuideRepositoryProtocol {
    public private(set) var guideHost: String
    public private(set) var guidePrograms: [String: [MirakurunProgram]]
    public private(set) var guideProgramsLoadedAt: Date?

    public init(guideHost: String, programs: [MirakurunProgram]) {
        self.guideHost = guideHost
        guidePrograms = Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
        guideProgramsLoadedAt = programs.isEmpty ? nil : .distantFuture
    }

    public func loadGuidePrograms() async {}

    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        (guidePrograms[channel.code] ?? []).filter { $0.end > Date() }
    }

    public func program(id: Int, channelCode: String) -> MirakurunProgram? {
        guidePrograms[channelCode]?.first { $0.id == id }
    }

    public func saveGuideHost(_ host: String) async {
        guideHost = host
    }
}

/// 見本の録画予約。予約・取り消しは、持っている一覧だけを変える
@MainActor
@Observable
public final class SampleRecordingRepository: RecordingRepositoryProtocol {
    public private(set) var reservations: [RegzaReservation]

    public init(reservations: [RegzaReservation]) {
        self.reservations = reservations
    }

    public func loadReservations() async throws(RegzaError) {}

    public func reserve(_ program: MirakurunProgram, series: Bool) async throws(RegzaError) {
        throw .unsupported
    }

    public func cancel(_ reservation: RegzaReservation) async throws(RegzaError) {
        reservations.removeAll { $0.id == reservation.id }
    }
}

/// 見本のライブ配信。配信はできない
@MainActor
@Observable
public final class SampleStreamRepository: StreamRepositoryProtocol {
    public private(set) var streamHost = ""
    public var canStream: Bool { false }

    public init() {}

    public func saveStreamHost(_ host: String) { streamHost = host }
    public func isPlayable(channelCode: String) -> Bool { false }
    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int { throw .notConfigured }
    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL { throw .notConfigured }
    public func keep(streamID: Int) async {}
    public func stop(streamID: Int) async {}
    public func cleanUp() async {}
    public func stopStalled() async {}
}

/// 見本の機器探し。何も見つからず、PIN 登録もできない
public struct SampleDeviceRepository: DeviceRepositoryProtocol {
    public init() {}

    public func devices() -> AsyncStream<RegzaDevice> { AsyncStream { $0.finish() } }
    public func pairing(host: String, user: String) -> any PairingSession { SamplePairing() }
    public func findGuideServers() async -> [String] { [] }
    public func findStreamServers() async -> [String] { [] }
    public func isStreamServer(host: String) async -> Bool { false }
}

struct SamplePairing: PairingSession {
    func start() async throws { throw RegzaError.unsupported }
    func confirm(pin: String) async throws -> RegzaConnection { throw RegzaError.unsupported }
    func cancel() async {}
}
