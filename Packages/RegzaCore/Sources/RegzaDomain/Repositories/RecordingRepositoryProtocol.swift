import Foundation

/// テレビの録画予約。予約の一覧は、読み込んだものを持っておく (接続が変わったら使わない)
/// @mockable
@MainActor
public protocol RecordingRepositoryProtocol: AnyObject {
    /// 録画予約。予定のあるものを先に、時刻順に並べる
    var reservations: [ReservationData] { get }

    func loadReservations() async throws(RegzaError)
    /// 番組表の番組を録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    func reserve(_ program: ProgramData, series: Bool) async throws(RegzaError)
    func cancel(_ reservation: ReservationData) async throws(RegzaError)
}

extension RecordingRepositoryProtocol {
    /// その番組の予約。なければ nil
    public func reservation(for program: ProgramData) -> ReservationData? {
        reservations.first { $0.isReservation(of: program.epgContentID) }
    }

    public func isReserved(_ program: ProgramData) -> Bool {
        reservation(for: program) != nil
    }
}
