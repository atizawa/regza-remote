public import Foundation

/// 番組表の画面からの操作 (GuideGridViewModel.Action)
public enum GuideGridAction: Sendable {
    /// 画面を開いた。予約した番組に印を付けるため、予約も読む
    case load
    case selectDay(Date?)
}
