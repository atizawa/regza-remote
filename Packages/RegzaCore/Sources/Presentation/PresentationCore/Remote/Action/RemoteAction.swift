import Foundation

/// リモコンの画面からの操作 (RemoteViewModel.Action)
public enum RemoteAction: Sendable {
    /// リモコンのボタンを押す
    case press(RegzaKey)
    /// 録画の再生位置を移す (秒)
    case seek(Int)
    case selectBand(BroadcastBand?)
    case loadChannels(force: Bool)
    /// 選局する (チャンネルの code)
    case tune(String)
    /// いま映っているものを取り直す
    case refresh
    /// 画面が見えている間、2 秒ごとに取り直す
    case startPolling
    case stopPolling
    /// ロック画面の表示を始められなかったことを出す (テレビとのやり取りの外で起きた失敗)
    case lockScreenStartFailed
}
