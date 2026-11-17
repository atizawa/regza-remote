import Foundation
public import PresentationCore

/// 1 チャンネルの番組表の画面の状態 (ProgramListViewModel.State)
public struct ProgramListState: Equatable, Sendable {
    public var channelCode: String
    public var channelName: String
    /// 日ごとの番組。読み込む前は nil
    public var days: [ProgramDay]?
    /// 読み込み中 (引っ張って読み直したときの印を、終わったら消す)
    public var isLoading: Bool
    /// 取得できなかった説明
    public var loadErrorMessage: String?
}
