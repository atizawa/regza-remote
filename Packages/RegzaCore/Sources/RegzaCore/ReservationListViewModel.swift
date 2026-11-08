import Foundation
import Observation

/// 録画予約の一覧の画面の ViewModel (iOS と Android で共有)
@MainActor
@Observable
public final class ReservationListViewModel {
    public let remote: RemoteViewModel
    public let recording: any RecordingUseCaseProtocol

    public init(remote: RemoteViewModel, recording: any RecordingUseCaseProtocol) {
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
        public var scheduled: [ReservationItem]
        /// 次の回を待っている連ドラ予約
        public var waiting: [ReservationItem]

        public var isEmpty: Bool { scheduled.isEmpty && waiting.isEmpty }
    }

    public enum Action: Sendable {
        case load
        /// 予約を取り消す (ReservationItem の id)
        case cancel(String)
    }

    private var loadError: RegzaError?
    private var hasLoaded = false
    private var cancelError: String?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let items = recording.items(channels: remote.state.channels)
        return State(
            hasLoaded: hasLoaded,
            loadErrorMessage: items.isEmpty ? loadError?.recordingMessage : nil,
            cancelError: cancelError,
            scheduled: items.filter(\.isScheduled),
            waiting: items.filter { !$0.isScheduled }
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .load: work.run { await self.load() }
        case .cancel(let id): work.run { await self.cancel(id: id) }
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

    private func cancel(id: String) async {
        cancelError = nil
        let title = recording.reservations.first { $0.id == id }?.title ?? ""
        do {
            try await recording.cancel(id: id)
        } catch {
            cancelError = "「\(title)」の予約を取り消せませんでした: \(error.localizedDescription)"
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
            guard recording.reservations.contains(where: { $0.id == id }) else {
                throw IntrospectionError.unavailable("予約 \(id) はありません")
            }
            send(.cancel(id))
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
