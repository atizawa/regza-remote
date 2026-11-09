public import Foundation

/// 録画予約の一覧の画面の状態 (ReservationListViewModel.State)
public struct ReservationListState: Equatable, Sendable {
    public var hasLoaded: Bool
    /// 読み込み中 (引っ張って読み直したときの印を、終わったら消す)
    public var isLoading: Bool
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
