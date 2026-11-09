public import Foundation

/// 番組の詳細の画面からの操作 (ProgramDetailViewModel.Action)
public enum ProgramDetailAction: Sendable {
    /// 画面を開いた。予約済みか、最初から見られるかを出すため
    case appear
    /// 録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    case reserve(series: Bool)
    case cancelReservation
    /// 切り替える。`startOver` なら、切り替えてから番組を最初から再生する
    case tune(startOver: Bool)
}
