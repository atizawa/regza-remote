/// ロック画面や通知の見出しに出すもの (LiveStatus.headline)。文言は OS ごとの画面が決める
public enum LiveHeadline: String, Sendable {
    /// 番組名
    case program
    /// 番組名が取れない放送の、チャンネル名
    case channel
    /// 外部入力
    case external
    /// 待機中
    case standby
    /// テレビに接続できない
    case disconnected
    /// 直前に送ったボタン
    case sentCommand
    /// どれでもないとき (リモコン)
    case remote
}
