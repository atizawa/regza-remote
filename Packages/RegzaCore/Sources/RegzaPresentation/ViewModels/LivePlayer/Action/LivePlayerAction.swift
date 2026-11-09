public import Foundation

/// ライブ視聴の画面からの操作 (LivePlayerViewModel.Action)
public enum LivePlayerAction: Sendable {
    /// 画面を開いた。局名と番組名を出すため、チャンネルと番組表を読む
    case appear
    /// 配信を頼む
    case start
    /// 前の配信を止めて、選んだ局の配信を頼み直す
    case switchChannel(String)
    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止めてから、もう一度頼む
    case retryAfterStoppingStalled
    /// 見終わった。配信を止めてチューナーを空ける
    case end
}
