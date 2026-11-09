public import Foundation

/// チャンネル一覧の画面の状態 (ChannelListViewModel.State)
public struct ChannelListState: Equatable, Sendable {
    public var isLoading: Bool
    /// 一覧の代わりに出す、取得できなかった説明。一覧があれば nil
    public var loadErrorMessage: String?
    /// まだ一覧がない (読み込み中か、取得できなかった)
    public var hasNoChannels: Bool
    /// 切り替えられなかったときの説明
    public var tuneError: String?
    /// 切り替え中のチャンネルのコード
    public var tuningCode: String?
    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    public var bands: [BroadcastBand]
    /// 出す放送の種類 (選んでいなければ、いま見ている種類)
    public var band: BroadcastBand?
    public var rows: [ChannelItem]
    /// アプリで見られる (ライブ視聴が設定されている)
    public var canStream: Bool
}
