import Foundation
public import Observation
public import PresentationCore
package import RegzaDomain
import RegzaStrings

/// いま映っているものの詳細のシートの ViewModel。
/// 待機中なら電源を入れる、放送ならアプリで見る・最初から見る、を出す
@MainActor
@Observable
public final class NowPlayingViewModel {
    public let remoteViewModel: RemoteViewModel
    private let guideUseCase: any GuideUseCaseProtocol
    private let streamUseCase: any StreamUseCaseProtocol

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
            title: isConnected && isWatching ? CoreStrings.nowPlayingTitleWatching : CoreStrings.nowPlayingTitleTv,
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
                await self.remoteViewModel.loadTimeshiftSettings()
                // チャンネル名を出すための下準備。読めなくても、いま映っているものはそのまま出す
                try? await self.remoteViewModel.loadChannels()
            }
        case .powerOn: remoteViewModel.send(.press(.power))
        case .startOver:
            work.run { await self.remoteViewModel.reportingFailure { try await self.remoteViewModel.startOver() } }
        }
    }

    private func canStartOver(_ nowPlaying: NowPlayingItem?) -> Bool {
        guard let nowPlaying, nowPlaying.kind == .broadcast, nowPlaying.hasTimeline else { return false }
        let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
        return remoteViewModel.canStartOver(channelCode: nowPlaying.channelCode, programStart: start)
    }
}

extension NowPlayingViewModel: IntrospectableActions {
    public var introspectionName: String { "nowPlaying" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionTable: [IntrospectionAction<Action>] {
        [
            IntrospectionAction("appear", "最初から見られるかと、いま映っている局を読む", .appear),
            IntrospectionAction("powerOn", "テレビの電源を入れる", .powerOn),
            IntrospectionAction("startOver", "いま映っている番組を最初から見る", .startOver),
        ]
    }
}
