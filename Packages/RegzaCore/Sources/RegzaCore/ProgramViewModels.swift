import Foundation
import Observation

/// 1 チャンネルの番組表の画面の ViewModel (iOS と Android で共有)。放送中の番組から日ごとに並べる
@MainActor
@Observable
public final class ProgramListViewModel {
    public let guide: GuideViewModel
    public let recording: ReservationsViewModel
    public let channel: RegzaChannel

    public init(guide: GuideViewModel, recording: ReservationsViewModel, channel: RegzaChannel) {
        self.guide = guide
        self.recording = recording
        self.channel = channel
    }

    /// 番組。読み込む前は nil
    public private(set) var programs: [MirakurunProgram]?
    public private(set) var loadError: RegzaError?

    /// 日ごとの番組
    public var days: [(day: Date, programs: [MirakurunProgram])] {
        let calendar = Calendar.current
        return Dictionary(grouping: programs ?? []) { calendar.startOfDay(for: $0.start) }
            .map { (day: $0.key, programs: $0.value) }
            .sorted { $0.day < $1.day }
    }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        recording.isReserved(program)
    }

    /// 画面を開いたとき。予約した番組に印を付けるため、予約も読む
    public func appear() async {
        if programs == nil { await load() }
        if recording.reservations.isEmpty { try? await recording.loadReservations() }
    }

    public func load() async {
        do {
            programs = try await guide.programs(for: channel)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

/// 番組の詳細の画面の ViewModel (iOS と Android で共有)。切り替え・録画予約・最初から見る
@MainActor
@Observable
public final class ProgramDetailViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel
    public let recording: ReservationsViewModel
    public let stream: StreamViewModel
    public let program: MirakurunProgram
    public let channel: RegzaChannel

    public init(
        remote: RemoteViewModel, guide: GuideViewModel, recording: ReservationsViewModel, stream: StreamViewModel,
        program: MirakurunProgram, channel: RegzaChannel
    ) {
        self.remote = remote
        self.guide = guide
        self.recording = recording
        self.stream = stream
        self.program = program
        self.channel = channel
    }

    /// 予約・取り消しの途中のもの
    public enum Reserving: Sendable {
        case single, series, cancel
    }

    public private(set) var isTuning = false
    /// 切り替えた結果 (切り替えてもタブは移らないので、画面に出す)
    public private(set) var tuneMessage: String?
    public private(set) var reserving: Reserving?
    public private(set) var reserveMessage: String?
    /// 予約・取り消しが終わった回数 (触覚フィードバック用)
    public private(set) var reserveCount = 0

    /// 画面に出す説明。予約の説明を優先する
    public var message: String? { reserveMessage ?? tuneMessage }

    public var reservation: RegzaReservation? { recording.reservation(for: program) }
    public var isReserved: Bool { reservation != nil }

    /// 予約済みの説明 (「連ドラ予約済み（毎週）」など)。予約していなければ nil
    public var reservedText: String? {
        guard let reservation else { return nil }
        guard reservation.isSeries else { return "録画予約済み" }
        return reservation.repeatLabel.map { "連ドラ予約済み（\($0)）" } ?? "連ドラ予約済み"
    }

    /// 放送中なら切り替えられる
    public var canTune: Bool { program.isOnAir() }
    /// 終わっていなければ予約できる
    public var canReserve: Bool { program.end > Date() }
    public var canStream: Bool { program.isOnAir() && stream.canStream }
    public var canStartOver: Bool {
        program.isOnAir() && guide.canStartOver(channelCode: program.channelCode, programStart: program.start)
    }

    /// 画面を開いたとき。予約済みか、最初から見られるかを出すため
    public func appear() async {
        if recording.reservations.isEmpty { try? await recording.loadReservations() }
        await guide.loadTimeshiftSettings()
    }

    /// 録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    public func reserve(series: Bool) async {
        reserving = series ? .series : .single
        defer { reserving = nil }
        reserveMessage = nil
        do {
            try await recording.reserve(program, series: series)
            reserveCount += 1
            if !recording.isReserved(program) {
                // テレビの一覧にまだ反映されていない
                reserveMessage = "予約しました。テレビの予約一覧に反映されるまで少しかかることがあります。"
            }
        } catch .commandRejected(let code) {
            // 重なる予約が多い、ハードディスクがないなど
            reserveMessage = "テレビが予約を受け付けませんでした (\(code))。テレビの予約一覧や録画機器を確認してください。"
        } catch {
            reserveMessage = error.localizedDescription
        }
    }

    public func cancelReservation() async {
        guard let reservation else { return }
        reserving = .cancel
        defer { reserving = nil }
        reserveMessage = nil
        do {
            try await recording.cancel(reservation)
            reserveCount += 1
        } catch {
            reserveMessage = "予約を取り消せませんでした: \(error.localizedDescription)"
        }
    }

    /// 切り替える。`startOver` なら、切り替えてから番組を最初から再生する
    public func tune(startOver: Bool) async {
        isTuning = true
        defer { isTuning = false }
        do {
            if startOver {
                try await guide.tuneAndStartOver(channel)
                tuneMessage = "テレビを\(channel.name)に切り替えて、最初から再生しました。"
            } else {
                try await remote.tune(to: channel)
                tuneMessage = "テレビを\(channel.name)に切り替えました。"
            }
        } catch {
            tuneMessage = error.localizedDescription
        }
    }
}
