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

    /// 画面に出すもの
    public typealias State = NowPlayingState

    /// 画面からの操作
    public typealias Action = NowPlayingAction

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
