import Foundation
import Observation

/// 録画予約の一覧の画面の ViewModel (iOS と Android で共有)
@MainActor
@Observable
public final class ReservationListViewModel {
    public let remote: RemoteViewModel
    public let recording: ReservationsViewModel

    public init(remote: RemoteViewModel, recording: ReservationsViewModel) {
        self.remote = remote
        self.recording = recording
    }

    public private(set) var loadError: RegzaError?
    public private(set) var hasLoaded = false
    /// 取り消せなかったときの説明
    public private(set) var cancelError: String?

    /// 録画の予定があるもの (時刻順)
    public func scheduled(now: Date = Date()) -> [RegzaReservation] {
        recording.reservations.filter { $0.isScheduled(now: now) }
    }

    /// 次の回を待っている連ドラ予約
    public func waiting(now: Date = Date()) -> [RegzaReservation] {
        recording.reservations.filter { !$0.isScheduled(now: now) }
    }

    public var isEmpty: Bool { recording.reservations.isEmpty }

    /// 一覧の代わりに出す、取得できなかった説明。一覧があれば nil
    public var loadErrorMessage: String? {
        guard let loadError, recording.reservations.isEmpty else { return nil }
        return loadError.recordingMessage
    }

    /// 予約したチャンネルの名前。チャンネル一覧を取れなければ nil
    public func channelName(of reservation: RegzaReservation) -> String? {
        remote.channels.first { $0.code == reservation.channelCode }?.name
    }

    public func load() async {
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

    public func cancel(_ reservation: RegzaReservation) async {
        cancelError = nil
        do {
            try await recording.cancel(reservation)
        } catch {
            cancelError = "「\(reservation.title)」の予約を取り消せませんでした: \(error.localizedDescription)"
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
