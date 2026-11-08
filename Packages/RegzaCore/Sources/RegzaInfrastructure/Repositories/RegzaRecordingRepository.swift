import Foundation
import Observation
import RegzaDomain

/// テレビの録画予約 (RecordingRepositoryProtocol の実装)。テレビの Repository と同じリモコンで送る
@MainActor
@Observable
public final class RegzaRecordingRepository: RecordingRepositoryProtocol {
    @ObservationIgnored private let tv: RegzaTVRepository
    /// 読み込んだ予約と、そのときの接続。接続が変わったら使わない
    private var loaded: (reservations: [RegzaReservation], connection: RegzaConnection)?

    public init(tv: RegzaTVRepository) {
        self.tv = tv
    }

    public var reservations: [RegzaReservation] {
        loaded.flatMap { $0.connection == tv.connection ? $0.reservations : nil } ?? []
    }

    public func loadReservations() async throws(RegzaError) {
        let connection = tv.connection
        let list: [RegzaReservation]
        do {
            list = try await tv.remote.client.reservations()
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

    public func reserve(_ program: MirakurunProgram, series: Bool) async throws(RegzaError) {
        do {
            try await tv.remote.client.reserve(
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
            try await tv.remote.client.cancelReservation(id: reservation.id)
        } catch {
            throw RegzaError(error)
        }
        if let current = loaded {
            loaded = (current.reservations.filter { $0.id != reservation.id }, current.connection)
        }
        try? await loadReservations()
    }
}
