import Foundation
import Observation

/// 録画予約の ViewModel。アプリ全体で 1 つ (iOS と Android で共有)
@MainActor
@Observable
public final class ReservationsViewModel {
    public let remote: RemoteViewModel

    public init(remote: RemoteViewModel) {
        self.remote = remote
    }

    /// 開発用の見本データを出す
    public func showSample(_ reservations: [RegzaReservation]) {
        loaded = (reservations, remote.connection)
    }

    /// 読み込んだ予約と、そのときの接続。接続が変わったら使わない
    private var loaded: (reservations: [RegzaReservation], connection: RegzaConnection)?

    /// 録画予約。予定のあるものを先に、時刻順に並べる
    public var reservations: [RegzaReservation] {
        loaded.flatMap { $0.connection == remote.connection ? $0.reservations : nil } ?? []
    }

    public func loadReservations() async throws(RegzaError) {
        guard !remote.isSampleMode else { return }
        let connection = remote.connection
        let list: [RegzaReservation]
        do {
            list = try await remote.remote.client.reservations()
        } catch {
            throw RegzaError(error)
        }
        let now = Date()
        loaded = (list.sorted { lhs, rhs in
            let left = lhs.isScheduled(now: now), right = rhs.isScheduled(now: now)
            // 予定のあるものは近い順、次の回が未定のものは最後に録画した回が新しい順
            return left != right ? left : (left ? lhs.start < rhs.start : lhs.start > rhs.start)
        }, connection)
    }

    /// その番組の予約。なければ nil
    public func reservation(for program: MirakurunProgram) -> RegzaReservation? {
        reservations.first { $0.isReservation(of: program.epgContentID) }
    }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        reservation(for: program) != nil
    }

    /// 番組表の番組を録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    public func reserve(_ program: MirakurunProgram, series: Bool = false) async throws(RegzaError) {
        do {
            try await remote.remote.client.reserve(
                channel: program.channelCode,
                epgContentID: program.epgContentID,
                start: program.start,
                duration: Int(program.end.timeIntervalSince(program.start)),
                series: series
            )
        } catch {
            throw RegzaError(error)
        }
        try? await loadReservations()
    }

    public func cancel(_ reservation: RegzaReservation) async throws(RegzaError) {
        do {
            try await remote.remote.client.cancelReservation(id: reservation.id)
        } catch {
            throw RegzaError(error)
        }
        if let current = loaded {
            loaded = (current.reservations.filter { $0.id != reservation.id }, current.connection)
        }
        try? await loadReservations()
    }
}
