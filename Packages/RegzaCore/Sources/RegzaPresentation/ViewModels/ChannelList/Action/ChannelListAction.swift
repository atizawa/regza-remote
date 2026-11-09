public import Foundation

/// チャンネル一覧の画面からの操作 (ChannelListViewModel.Action)
public enum ChannelListAction: Sendable {
    /// 画面を開いた。番組名と「最初から見る」を出すため、番組表とタイムシフトの設定も読む
    case appear
    case reload
    /// 選局する (チャンネルのコード)
    case tune(String)
    /// 切り替えてから、放送中の番組を最初から再生する (チャンネルのコード)
    case tuneFromStart(String)
}
