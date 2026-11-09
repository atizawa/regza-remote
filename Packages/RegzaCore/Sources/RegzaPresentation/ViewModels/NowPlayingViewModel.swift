public import Foundation
public import Observation
package import RegzaDomain

/// いま映っているものの詳細のシートの ViewModel。
/// 待機中なら電源を入れる、放送ならアプリで見る・最初から見る、を出す
@MainActor
@Observable
public final class NowPlayingViewModel {
    public let remote: RemoteViewModel
    package let guide: any GuideUseCaseProtocol
    package let stream: any StreamUseCaseProtocol

    package init(remote: RemoteViewModel, guide: any GuideUseCaseProtocol, stream: any StreamUseCaseProtocol) {
        self.remote = remote
        self.guide = guide
        self.stream = stream
    }

    public struct State: Equatable, Sendable {
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

    public enum Action: Sendable {
        /// シートを開いた。最初から見られるかを知るためタイムシフトの設定を、いま映っている局を知るためチャンネルを読む
        case appear
        case powerOn
        /// いま映っている番組を最初から再生する
        case startOver
    }

    @ObservationIgnored private let work = Work()

    public var state: State {
        let remoteState = remote.state
        let nowPlaying = remoteState.nowPlaying
        let isConnected = !remoteState.isSearchingTV && remoteState.errorMessage == nil
        let isWatching = nowPlaying?.kind == .broadcast || nowPlaying?.kind == .recorded
        let description = nowPlaying?.description ?? ""
        return State(
            title: isConnected && isWatching ? "視聴中" : "テレビ",
            description: description.isEmpty ? nil : description,
            canPowerOn: nowPlaying?.kind == .standby && remoteState.errorMessage == nil,
            playableChannelCode: stream.canStream && nowPlaying?.kind == .broadcast ? remote.nowPlayingChannel?.code : nil,
            canStartOver: canStartOver(nowPlaying)
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                await self.remote.tv.loadTimeshiftSettings()
                try? await self.remote.loadChannels()
            }
        case .powerOn: remote.send(.press(.power))
        case .startOver: work.run { try? await self.remote.startOver() }
        }
    }

    private func canStartOver(_ nowPlaying: NowPlayingItem?) -> Bool {
        guard let nowPlaying, nowPlaying.kind == .broadcast, nowPlaying.hasTimeline else { return false }
        let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
        return remote.tv.canStartOver(channelCode: nowPlaying.channelCode, programStart: start)
    }
}

extension NowPlayingViewModel: Introspectable {
    public var introspectionName: String { "nowPlaying" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "最初から見られるかと、いま映っている局を読む"),
            ActionDescription("powerOn", "テレビの電源を入れる"),
            ActionDescription("startOver", "いま映っている番組を最初から見る"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "appear": send(.appear)
        case "powerOn": send(.powerOn)
        case "startOver": send(.startOver)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
