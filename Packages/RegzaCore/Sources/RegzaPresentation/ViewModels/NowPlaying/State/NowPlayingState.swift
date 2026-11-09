public import Foundation

/// いま映っているものの詳細のシートの状態 (NowPlayingViewModel.State)
public struct NowPlayingState: Equatable, Sendable {
    /// 番組を映しているときだけ「視聴中」にする。待機中などはカードに状態が出るので、見出しはテレビとだけ書く
    public var title: String
    /// 番組の説明 (なければ nil)
    public var description: String?
    /// 待機中なので電源を入れられる (開いている間はミニプレーヤーの電源ボタンが隠れるので、ここでも出す)
    public var canPowerOn: Bool
    /// アプリで見られる、いま映っている局
    public var playableChannelCode: String?
    /// いま映っている放送を最初から見られるか
    public var canStartOver: Bool
}
