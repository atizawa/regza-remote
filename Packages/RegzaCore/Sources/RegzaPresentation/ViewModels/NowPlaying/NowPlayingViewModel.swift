public import Foundation
public import Observation
package import RegzaDomain

/// いま映っているものの詳細のシートの ViewModel。
/// 待機中なら電源を入れる、放送ならアプリで見る・最初から見る、を出す
@MainActor
@Observable
public final class NowPlayingViewModel {
    public let remoteViewModel: RemoteViewModel
    package let guideUseCase: any GuideUseCaseProtocol
    package let streamUseCase: any StreamUseCaseProtocol

    package init(remoteViewModel: RemoteViewModel, guideUseCase: any GuideUseCaseProtocol, streamUseCase: any StreamUseCaseProtocol) {
        self.remoteViewModel = remoteViewModel
        self.guideUseCase = guideUseCase
        self.streamUseCase = streamUseCase
    }

    /// 画面に出すもの
    public typealias State = NowPlayingState

    /// 画面からの操作
    public typealias Action = NowPlayingAction

    @ObservationIgnored private let work = Work()

    public var state: State {
        let remoteState = remoteViewModel.state
        let nowPlaying = remoteState.nowPlaying
        let isConnected = !remoteState.isSearchingTV && remoteState.errorMessage == nil
        let isWatching = nowPlaying?.kind == .broadcast || nowPlaying?.kind == .recorded
        let description = nowPlaying?.description ?? ""
        return State(
            title: isConnected && isWatching ? "視聴中" : "テレビ",
            description: description.isEmpty ? nil : description,
            canPowerOn: nowPlaying?.kind == .standby && remoteState.errorMessage == nil,
            playableChannelCode: streamUseCase.canStream && nowPlaying?.kind == .broadcast ? remoteViewModel.nowPlayingChannel?.code : nil,
            canStartOver: canStartOver(nowPlaying)
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                await self.remoteViewModel.tvUseCase.loadTimeshiftSettings()
                try? await self.remoteViewModel.loadChannels()
            }
        case .powerOn: remoteViewModel.send(.press(.power))
        case .startOver: work.run { try? await self.remoteViewModel.startOver() }
        }
    }

    private func canStartOver(_ nowPlaying: NowPlayingItem?) -> Bool {
        guard let nowPlaying, nowPlaying.kind == .broadcast, nowPlaying.hasTimeline else { return false }
        let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
        return remoteViewModel.tvUseCase.canStartOver(channelCode: nowPlaying.channelCode, programStart: start)
    }
}

extension NowPlayingViewModel: IntrospectableActions {
    public var introspectionName: String { "nowPlaying" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "最初から見られるかと、いま映っている局を読む"),
            ActionDescription("powerOn", "テレビの電源を入れる"),
            ActionDescription("startOver", "いま映っている番組を最初から見る"),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "appear": return .appear
        case "powerOn": return .powerOn
        case "startOver": return .startOver
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
