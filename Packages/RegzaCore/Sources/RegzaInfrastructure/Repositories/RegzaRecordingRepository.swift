import Foundation
import Observation
import RegzaDomain

/// テレビの録画予約。同じテレビを使う Repository と APIClient・接続状態を共有する。
@MainActor
@Observable
public final class RegzaRecordingRepository: RecordingRepositoryProtocol {
    @ObservationIgnored private let client: RegzaAPIClient
    @ObservationIgnored private let connectionState: RegzaConnectionState
    /// 読み込んだ予約と、そのときの接続。接続が変わったら使わない
    private var loaded: (reservations: [RegzaReservation], revision: Int)?

    public init(client: RegzaAPIClient, connectionState: RegzaConnectionState) {
        self.client = client
        self.connectionState = connectionState
    }

    public var reservations: [RegzaReservation] {
        loaded.flatMap { $0.revision == connectionState.revision ? $0.reservations : nil } ?? []
    }

    public func loadReservations() async throws(RegzaError) {
        let revision = connectionState.revision
        let list: [RegzaReservation]
        do {
            list = try await client.reservations()
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        let now = Date()
        loaded = (
            list.sorted { lhs, rhs in
                let left = lhs.isScheduled(now: now)
                let right = rhs.isScheduled(now: now)
                // 予定のあるものは近い順、次の回が未定のものは最後に録画した回が新しい順
                return left != right ? left : (left ? lhs.start < rhs.start : lhs.start > rhs.start)
            }, revision
        )
    }

    public func reserve(_ program: MirakurunProgram, series: Bool) async throws(RegzaError) {
        let revision = connectionState.revision
        do {
            try await client.reserve(
                channel: program.channelCode,
                epgContentID: program.epgContentID,
                start: program.start,
                duration: Int(program.end.timeIntervalSince(program.start)),
                series: series
            )
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        try? await loadReservations()
    }

    public func cancel(_ reservation: RegzaReservation) async throws(RegzaError) {
        let revision = connectionState.revision
        do {
            try await client.cancelReservation(id: reservation.id)
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        if let current = loaded, current.revision == revision {
            loaded = (current.reservations.filter { $0.id != reservation.id }, current.revision)
        }
        try? await loadReservations()
    }
}
