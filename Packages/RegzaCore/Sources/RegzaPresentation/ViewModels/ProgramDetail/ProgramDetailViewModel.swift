public import Foundation
public import Observation
package import RegzaDomain

/// 番組の詳細の画面の ViewModel。切り替え・録画予約・最初から見る
@MainActor
@Observable
public final class ProgramDetailViewModel {
    public let remoteViewModel: RemoteViewModel
    package let guideUseCase: any GuideUseCaseProtocol
    package let recordingUseCase: any RecordingUseCaseProtocol
    package let streamUseCase: any StreamUseCaseProtocol
    package let program: ProgramItem
    package let channel: ChannelItem

    package init(
        remoteViewModel: RemoteViewModel, guideUseCase: any GuideUseCaseProtocol, recordingUseCase: any RecordingUseCaseProtocol,
        streamUseCase: any StreamUseCaseProtocol,
        program: ProgramItem, channel: ChannelItem
    ) {
        self.remoteViewModel = remoteViewModel
        self.guideUseCase = guideUseCase
        self.recordingUseCase = recordingUseCase
        self.streamUseCase = streamUseCase
        self.program = program
        self.channel = channel
    }

    /// 予約・取り消しの途中のもの
    /// 予約・取り消しの途中のもの
    public typealias Reserving = ProgramDetailReserving

    /// 画面に出すもの
    public typealias State = ProgramDetailState

    /// 画面からの操作
    public typealias Action = ProgramDetailAction

    private var isTuning = false
    private var tuneMessage: String?
    private var reserving: Reserving?
    private var reserveMessage: String?
    private var reserveCount = 0
    @ObservationIgnored private let work = Work()

    public var state: State {
        let reservation = recordingUseCase.reservation(for: program)
        return State(
            program: guideUseCase.item(program),
            texts: guideUseCase.texts(of: program),
            channelCode: channel.code,
            channelName: channel.name,
            isTuning: isTuning,
            reserving: reserving,
            reserveCount: reserveCount,
            message: reserveMessage ?? tuneMessage,
            reservedText: reservation.map(Self.reservedText),
            reservationIsSeries: reservation?.isSeries,
            canTune: program.isOnAir(at: Date()),
            canReserve: program.end > Date(),
            canStream: program.isOnAir(at: Date()) && streamUseCase.canStream,
            canStartOver: program.isOnAir(at: Date())
                && remoteViewModel.tvUseCase.canStartOver(channelCode: program.channelCode, programStart: program.start)
        )
    }

    private static func reservedText(_ reservation: ReservationItem) -> String {
        guard reservation.isSeries else { return "録画予約済み" }
        return reservation.repeatLabel.map { "連ドラ予約済み（\($0)）" } ?? "連ドラ予約済み"
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                if self.recordingUseCase.reservations.isEmpty { try? await self.recordingUseCase.loadReservations() }
                await self.remoteViewModel.tvUseCase.loadTimeshiftSettings()
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
            try await recordingUseCase.reserve(program, series: series)
            reserveCount += 1
            if !recordingUseCase.isReserved(program) {
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
        guard let reservation = recordingUseCase.reservation(for: program) else { return }
        reserving = .cancel
        defer { reserving = nil }
        reserveMessage = nil
        do {
            try await recordingUseCase.cancel(reservation)
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
                try await remoteViewModel.tuneAndStartOver(channel)
                tuneMessage = "テレビを\(channel.name)に切り替えて、最初から再生しました。"
            } else {
                try await remoteViewModel.tune(to: channel)
                tuneMessage = "テレビを\(channel.name)に切り替えました。"
            }
        } catch {
            tuneMessage = error.localizedDescription
        }
    }
}

extension ProgramDetailViewModel: IntrospectableActions {
    public var introspectionName: String { "programDetail" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "画面を開いたときと同じく読み込む"),
            ActionDescription("reserve", "録画予約する", parameters: ["series": "true なら連ドラ予約"]),
            ActionDescription("cancelReservation", "予約を取り消す"),
            ActionDescription("tune", "この局に切り替える", parameters: ["startOver": "true なら番組を最初から再生する"]),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        let state = state
        switch name {
        case "appear": return .appear
        case "reserve":
            guard state.canReserve else { throw IntrospectionError.unavailable("終わった番組は予約できません") }
            return .reserve(series: try arguments.bool("series"))
        case "cancelReservation":
            guard state.isReserved else { throw IntrospectionError.unavailable("この番組は予約していません") }
            return .cancelReservation
        case "tune":
            let startOver = try arguments.bool("startOver")
            guard startOver ? state.canStartOver : state.canTune else {
                throw IntrospectionError.unavailable(startOver ? "この番組は最初から見られません" : "放送中の番組ではありません")
            }
            return .tune(startOver: startOver)
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
