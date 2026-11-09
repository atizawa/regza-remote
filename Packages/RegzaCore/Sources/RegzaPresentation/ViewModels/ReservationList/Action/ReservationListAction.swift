public import Foundation

/// 録画予約の一覧の画面からの操作 (ReservationListViewModel.Action)
public enum ReservationListAction: Sendable {
    case load
    /// 予約を取り消す (ReservationItem の id)
    case cancel(String)
}
