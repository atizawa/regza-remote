// 組み立てる場所 (Composition Root)。どの Repository の実装を使うかを決め、アプリ全体の ViewModel を作る。
// iOS・Android・CLI は、ここから作った AppViewModel を使う (画面の ViewModel は UseCase しか知らない)
// 組み立てには Domain の型 (保存先・Repository) が要るので、Domain も見せる (画面は RegzaPresentation だけを使う)
@_exported import RegzaDomain
@_exported import RegzaInfrastructure
@_exported import RegzaPresentation

extension RemoteViewModel {
    /// テレビに登録されているチャンネル (SharedModel)。画面のない入口 (iOS の Siri) が、チャンネルの名前から選ぶのに使う。
    /// 取得前は空なので、先に loadChannels を送って待つ
    public var registeredChannels: [ChannelItem] { channels }
}
