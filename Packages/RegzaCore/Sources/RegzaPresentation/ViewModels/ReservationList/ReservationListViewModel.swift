public import Foundation
public import Observation
package import RegzaDomain

/// 録画予約の一覧の画面の ViewModel
@MainActor
@Observable
public final class ReservationListViewModel {
    public let remote: RemoteViewModel
    package let recording: any RecordingUseCaseProtocol

    package init(remote: RemoteViewModel, recording: any RecordingUseCaseProtocol) {
        self.remote = remote
        self.recording = recording
    }

    /// 画面に出すもの
    public typealias State = ReservationListState

    /// 画面からの操作
    public typealias Action = ReservationListAction

    private var loadError: RegzaError?
    private var hasLoaded = false
    private var isLoading = false
    private var cancelError: String?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let items = recording.items(channels: remote.channels)
        return State(
            hasLoaded: hasLoaded,
            isLoading: isLoading,
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
        isLoading = true
        defer {
            hasLoaded = true
            isLoading = false
        }
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

extension ReservationListViewModel: IntrospectableActions {
    public var introspectionName: String { "reservationList" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("load", "録画予約を読み直す"),
            ActionDescription("cancel", "予約を取り消す", parameters: ["reservation": "予約の id"]),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "load": return .load
        case "cancel":
            let id = try arguments.string("reservation")
            guard recording.reservations.contains(where: { $0.id == id }) else {
                throw IntrospectionError.unavailable("予約 \(id) はありません")
            }
            return .cancel(id)
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}

extension RegzaError {
    /// 録画まわりの画面に出すメッセージ
    package var recordingMessage: String {
        switch self {
        case .httpStatus(404), .unsupported: "この機種は対応していません。"
        default: localizedDescription
        }
    }
}
