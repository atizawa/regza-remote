import Foundation
import Observation

/// 1 チャンネルの番組表の画面の ViewModel (iOS と Android で共有)。放送中の番組から日ごとに並べる
@MainActor
@Observable
public final class ProgramListViewModel {
    public let guide: GuideUseCase
    public let recording: RecordingUseCase
    public let channel: RegzaChannel

    public init(guide: GuideUseCase, recording: RecordingUseCase, channel: RegzaChannel) {
        self.guide = guide
        self.recording = recording
        self.channel = channel
    }

    public struct State: Equatable, Sendable {
        public var channel: RegzaChannel
        /// 日ごとの番組。読み込む前は nil
        public var days: [ProgramDay]?
        /// 取得できなかった説明
        public var loadErrorMessage: String?
    }

    public enum Action: Sendable {
        /// 画面を開いた。予約した番組に印を付けるため、予約も読む
        case appear
        case reload
    }

    private var programs: [MirakurunProgram]?
    private var loadError: RegzaError?
    @ObservationIgnored private let work = Work()

    public var state: State {
        State(
            channel: channel,
            days: programs.map { guide.days($0) },
            loadErrorMessage: programs == nil ? loadError?.localizedDescription : nil
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                if self.programs == nil { await self.load() }
                if self.recording.reservations.isEmpty { try? await self.recording.loadReservations() }
            }
        case .reload: work.run { await self.load() }
        }
    }

    private func load() async {
        do {
            programs = try await guide.programs(for: channel)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

extension ProgramListViewModel: Introspectable {
    public var introspectionName: String { "programList" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [ActionDescription("appear", "画面を開いたときと同じく読み込む"), ActionDescription("reload", "番組を読み直す")]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "appear": send(.appear)
        case "reload": send(.reload)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}

/// 番組の詳細の画面の ViewModel (iOS と Android で共有)。切り替え・録画予約・最初から見る
@MainActor
@Observable
public final class ProgramDetailViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideUseCase
    public let recording: RecordingUseCase
    public let stream: StreamUseCase
    public let program: MirakurunProgram
    public let channel: RegzaChannel

    public init(
        remote: RemoteViewModel, guide: GuideUseCase, recording: RecordingUseCase, stream: StreamUseCase,
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

    public struct State: Equatable, Sendable {
        public var program: ProgramItem
        /// 番組内容・出演者など
        public var texts: [ProgramTextItem]
        public var channel: RegzaChannel
        public var isTuning: Bool
        public var reserving: Reserving?
        /// 予約・取り消しが終わった回数 (触覚フィードバックの合図)
        public var reserveCount: Int
        /// 画面に出す説明。予約の説明を優先する
        public var message: String?
        /// 予約済みの説明 (「連ドラ予約済み（毎週）」など)。予約していなければ nil
        public var reservedText: String?
        /// 予約が連ドラ予約か。予約していなければ nil
        public var reservationIsSeries: Bool?
        /// 放送中なら切り替えられる
        public var canTune: Bool
        /// 終わっていなければ予約できる
        public var canReserve: Bool
        /// アプリで見られる
        public var canStream: Bool
        public var canStartOver: Bool

        public var isReserved: Bool { reservationIsSeries != nil }
    }

    public enum Action: Sendable {
        /// 画面を開いた。予約済みか、最初から見られるかを出すため
        case appear
        /// 録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
        case reserve(series: Bool)
        case cancelReservation
        /// 切り替える。`startOver` なら、切り替えてから番組を最初から再生する
        case tune(startOver: Bool)
    }

    private var isTuning = false
    private var tuneMessage: String?
    private var reserving: Reserving?
    private var reserveMessage: String?
    private var reserveCount = 0
    @ObservationIgnored private let work = Work()

    public var state: State {
        let reservation = recording.reservation(for: program)
        return State(
            program: guide.item(program),
            texts: guide.texts(of: program),
            channel: channel,
            isTuning: isTuning,
            reserving: reserving,
            reserveCount: reserveCount,
            message: reserveMessage ?? tuneMessage,
            reservedText: reservation.map(Self.reservedText),
            reservationIsSeries: reservation?.isSeries,
            canTune: program.isOnAir(),
            canReserve: program.end > Date(),
            canStream: program.isOnAir() && stream.canStream,
            canStartOver: program.isOnAir() && remote.tv.canStartOver(channelCode: program.channelCode, programStart: program.start)
        )
    }

    private static func reservedText(_ reservation: RegzaReservation) -> String {
        guard reservation.isSeries else { return "録画予約済み" }
        return reservation.repeatLabel.map { "連ドラ予約済み（\($0)）" } ?? "連ドラ予約済み"
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                if self.recording.reservations.isEmpty { try? await self.recording.loadReservations() }
                await self.remote.tv.loadTimeshiftSettings()
            }
        case .reserve(let series): work.run { await self.reserve(series: series) }
        case .cancelReservation: work.run { await self.cancelReservation() }
        case .tune(let startOver): work.run { await self.tune(startOver: startOver) }
        }
    }

    private func reserve(series: Bool) async {
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

    private func cancelReservation() async {
        guard let reservation = recording.reservation(for: program) else { return }
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

    private func tune(startOver: Bool) async {
        isTuning = true
        defer { isTuning = false }
        do {
            if startOver {
                try await remote.tuneAndStartOver(channel)
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

extension ProgramDetailViewModel: Introspectable {
    public var introspectionName: String { "programDetail" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "画面を開いたときと同じく読み込む"),
            ActionDescription("reserve", "録画予約する", parameters: ["series": "true なら連ドラ予約"]),
            ActionDescription("cancelReservation", "予約を取り消す"),
            ActionDescription("tune", "この局に切り替える", parameters: ["startOver": "true なら番組を最初から再生する"]),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        let state = state
        switch action {
        case "appear": send(.appear)
        case "reserve":
            guard state.canReserve else { throw IntrospectionError.unavailable("終わった番組は予約できません") }
            send(.reserve(series: try arguments.bool("series")))
        case "cancelReservation":
            guard state.isReserved else { throw IntrospectionError.unavailable("この番組は予約していません") }
            send(.cancelReservation)
        case "tune":
            let startOver = try arguments.bool("startOver")
            guard startOver ? state.canStartOver : state.canTune else {
                throw IntrospectionError.unavailable(startOver ? "この番組は最初から見られません" : "放送中の番組ではありません")
            }
            send(.tune(startOver: startOver))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
