import Foundation
import Observation

/// 録画予約の一覧の画面の ViewModel (iOS と Android で共有)
@MainActor
@Observable
public final class ReservationListViewModel {
    public let remote: RemoteViewModel
    public let recording: RecordingUseCase

    public init(remote: RemoteViewModel, recording: RecordingUseCase) {
        self.remote = remote
        self.recording = recording
    }

    public struct State: Equatable, Sendable {
        public var hasLoaded: Bool
        /// 一覧の代わりに出す、取得できなかった説明。一覧があれば nil
        public var loadErrorMessage: String?
        /// 取り消せなかったときの説明
        public var cancelError: String?
        /// 録画の予定があるもの (時刻順)
        public var scheduled: [Row]
        /// 次の回を待っている連ドラ予約
        public var waiting: [Row]

        public var isEmpty: Bool { scheduled.isEmpty && waiting.isEmpty }
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public var reservation: RegzaReservation
        /// 予約したチャンネルの名前。チャンネル一覧を取れなければ nil
        public var channelName: String?
        /// 録画している最中
        public var isRecording: Bool
        public var id: String { reservation.id }
    }

    public enum Action: Sendable {
        case load
        case cancel(RegzaReservation)
    }

    private var loadError: RegzaError?
    private var hasLoaded = false
    private var cancelError: String?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let now = Date()
        let channels = remote.state.channels
        let rows = recording.reservations.map { reservation in
            Row(
                reservation: reservation,
                channelName: channels.first { $0.code == reservation.channelCode }?.name,
                isRecording: reservation.isScheduled(now: now) && reservation.start <= now
            )
        }
        return State(
            hasLoaded: hasLoaded,
            loadErrorMessage: recording.reservations.isEmpty ? loadError?.recordingMessage : nil,
            cancelError: cancelError,
            scheduled: rows.filter { $0.reservation.isScheduled(now: now) },
            waiting: rows.filter { !$0.reservation.isScheduled(now: now) }
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .load: work.run { await self.load() }
        case .cancel(let reservation): work.run { await self.cancel(reservation) }
        }
    }

    private func load() async {
        defer { hasLoaded = true }
        // 局名を出すためにチャンネル一覧も読む (取れなくても予約は出す)
        try? await remote.loadChannels()
        do {
            try await recording.loadReservations()
            loadError = nil
        } catch {
            loadError = error
        }
    }

    private func cancel(_ reservation: RegzaReservation) async {
        cancelError = nil
        do {
            try await recording.cancel(reservation)
        } catch {
            cancelError = "「\(reservation.title)」の予約を取り消せませんでした: \(error.localizedDescription)"
        }
    }
}

extension ReservationListViewModel: Introspectable {
    public var introspectionName: String { "reservationList" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("load", "録画予約を読み直す"),
            ActionDescription("cancel", "予約を取り消す", parameters: ["reservation": "予約の id"]),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "load": send(.load)
        case "cancel":
            let id = try arguments.string("reservation")
            guard let reservation = recording.reservations.first(where: { $0.id == id }) else {
                throw IntrospectionError.unavailable("予約 \(id) はありません")
            }
            send(.cancel(reservation))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}

extension RegzaError {
    /// 録画まわりの画面に出すメッセージ
    public var recordingMessage: String {
        switch self {
        case .httpStatus(404), .unsupported: "この機種は対応していません。"
        default: localizedDescription
        }
    }
}
