import RegzaDomain
import RegzaPresentation
import RegzaSharedModels

extension AppFactory {
    public static func makeRemoteViewModel(
        tvUseCase: any TVUseCaseProtocol,
        nowPlaying: NowPlayingItem? = nil
    ) -> RemoteViewModel {
        RemoteViewModel(tvUseCase: tvUseCase, nowPlaying: nowPlaying)
    }

    /// UseCase を差し替えて、アプリ全体の ViewModel を組み立てる。
    public static func makeAppViewModel(
        tvUseCase: any TVUseCaseProtocol,
        channelUseCase: any ChannelUseCaseProtocol,
        guideUseCase: any GuideUseCaseProtocol,
        recordingUseCase: any RecordingUseCaseProtocol,
        streamUseCase: any StreamUseCaseProtocol,
        setupUseCase: any SetupUseCaseProtocol,
        initialNowPlaying: NowPlayingItem? = nil
    ) -> AppViewModel {
        makeAppViewModel(
            remoteViewModel: makeRemoteViewModel(tvUseCase: tvUseCase, nowPlaying: initialNowPlaying),
            channelUseCase: channelUseCase, guideUseCase: guideUseCase,
            recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            setupUseCase: setupUseCase)
    }

    public static func makeAppViewModel(
        remoteViewModel: RemoteViewModel,
        channelUseCase: any ChannelUseCaseProtocol,
        guideUseCase: any GuideUseCaseProtocol,
        recordingUseCase: any RecordingUseCaseProtocol,
        streamUseCase: any StreamUseCaseProtocol,
        setupUseCase: any SetupUseCaseProtocol
    ) -> AppViewModel {
        AppViewModel(
            remoteViewModel: remoteViewModel,
            channelUseCase: channelUseCase, guideUseCase: guideUseCase,
            recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            setupUseCase: setupUseCase)
    }
}
