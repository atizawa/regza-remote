public import Foundation

/// リモコンの画面の状態 (RemoteViewModel.State)
public struct RemoteState: Equatable, Sendable {
    /// テレビを登録してある
    public var isConfigured: Bool
    public var nowPlaying: NowPlayingItem?
    /// テレビに接続できないときの説明。つながっていれば nil
    public var errorMessage: String?
    /// 最後にテレビから取り直せた。取り直せなかったときも nowPlaying は直前のものを残すので、これで「接続できません」を添える
    public var isConnected: Bool = false
    /// 直前に送ったリモコンのボタン (「音量+」など)。選局したあとは nil
    public var lastCommandLabel: String?
    /// ボタンを押した回数 (触覚フィードバックの合図)
    public var tapCount: Int = 0
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public var isSearchingTV: Bool = false
    /// 開発用の見本データを表示している (テレビにはつながない)
    public var isSampleMode: Bool = false
    /// 番組表とチャンネル一覧で選んでいる放送の種類 (地デジ・BS・CS)。タブを行き来しても同じものを出す。未選択なら nil
    public var selectedBand: BroadcastBand?
    /// いま見ている放送の種類 (リモコンの地デジ・BS・CS の印)。チャンネル一覧から分かるときだけ
    public var nowPlayingBand: BroadcastBand?
}
