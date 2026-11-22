import Foundation
import Observation
import RegzaDomain

/// テレビの録画予約。同じテレビを使う Repository と APIClient・接続状態を共有する。
@MainActor
@Observable
public final class RegzaRecordingRepository: RecordingRepositoryProtocol {
    @ObservationIgnored private let regzaAPIClient: RegzaAPIClient
    @ObservationIgnored private let connectionState: RegzaConnectionState
    /// 読み込んだ予約と、そのときの接続。接続が変わったら使わない
    private var loaded: (reservations: [ReservationData], revision: Int)?

    /// 今の時刻 (予定の予約を先に並べるのに使う)
    @ObservationIgnored private let clock: AppClock

    public init(regzaAPIClient: RegzaAPIClient, connectionState: RegzaConnectionState, clock: AppClock) {
        self.clock = clock
        self.regzaAPIClient = regzaAPIClient
        self.connectionState = connectionState
    }

    public var reservations: [ReservationData] {
        loaded.flatMap { $0.revision == connectionState.revision ? $0.reservations : nil } ?? []
    }

    public func loadReservations() async throws(RegzaError) {
        let revision = connectionState.revision
        let list: [ReservationData]
        do {
            list = try await regzaAPIClient.request(RegzaReservationsRequest())
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        let now = clock.now
        loaded = (
            list.sorted { lhs, rhs in
                let left = lhs.isScheduled(now: now)
                let right = rhs.isScheduled(now: now)
                // 予定のあるものは近い順、次の回が未定のものは最後に録画した回が新しい順
                return left != right ? left : (left ? lhs.start < rhs.start : lhs.start > rhs.start)
            }, revision
        )
    }

    public func reserve(_ program: ProgramData, series: Bool) async throws(RegzaError) {
        let revision = connectionState.revision
        do {
            try await regzaAPIClient.request(
                RegzaReserveRequest(
                    channel: program.channelCode,
                    epgContentID: program.epgContentID,
                    start: program.start,
                    duration: Int(program.end.timeIntervalSince(program.start)),
                    series: series
                ))
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        // 予約はできたので、一覧を読み直せなくても予約の失敗として伝えない (一覧は次に開いたときに読み直す)
        try? await loadReservations()
    }

    public func cancel(_ reservation: ReservationData) async throws(RegzaError) {
        let revision = connectionState.revision
        do {
            try await regzaAPIClient.request(RegzaCancelReservationRequest(id: reservation.id))
        } catch {
            throw RegzaError(error)
        }
        guard revision == connectionState.revision else { return }
        if let current = loaded, current.revision == revision {
            loaded = (current.reservations.filter { $0.id != reservation.id }, current.revision)
        }
        // 取り消しはできて一覧からも除いたので、読み直せなくても取り消しの失敗として伝えない
        try? await loadReservations()
    }
}
