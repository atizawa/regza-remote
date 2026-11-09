public import Foundation

/// 1 チャンネルの番組表の画面からの操作 (ProgramListViewModel.Action)
public enum ProgramListAction: Sendable {
    /// 画面を開いた。予約した番組に印を付けるため、予約も読む
    case appear
    case reload
}
