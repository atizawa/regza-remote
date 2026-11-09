public import Foundation

/// ライブ視聴の画面の状態 (LivePlayerViewModel.State)
public struct LivePlayerState: Equatable, Sendable {
    /// いま見ている局
    /// いま見ている局のコードと名前
    public var channelCode: String
    public var channelName: String
    public var phase: LivePlayerPhase
    /// 見ている局でいま放送中の番組 (番組表から)
    public var program: ProgramItem?
    /// 準備中に出す説明
    public var preparingMessage: String
    /// 見られる局がある放送の種類
    public var bands: [BroadcastBand]
    /// 選んでいる放送の種類
    public var band: BroadcastBand?
    /// 一覧に出す局 (選んでいる放送の種類のもの)
    public var channels: [ChannelItem]
}
