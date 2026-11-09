public import Foundation

/// いま映っているものの詳細のシートからの操作 (NowPlayingViewModel.Action)
public enum NowPlayingAction: Sendable {
    /// シートを開いた。最初から見られるかを知るためタイムシフトの設定を、いま映っている局を知るためチャンネルを読む
    case appear
    case powerOn
    /// いま映っている番組を最初から再生する
    case startOver
}
