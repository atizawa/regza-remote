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
        appPreferencesUseCase: any AppPreferencesUseCaseProtocol,
        initialNowPlaying: NowPlayingItem? = nil
    ) -> AppViewModel {
        makeAppViewModel(
            remoteViewModel: makeRemoteViewModel(tvUseCase: tvUseCase, nowPlaying: initialNowPlaying),
            channelUseCase: channelUseCase, guideUseCase: guideUseCase,
            recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            setupUseCase: setupUseCase, appPreferencesUseCase: appPreferencesUseCase)
    }

    public static func makeAppViewModel(
        remoteViewModel: RemoteViewModel,
        channelUseCase: any ChannelUseCaseProtocol,
        guideUseCase: any GuideUseCaseProtocol,
        recordingUseCase: any RecordingUseCaseProtocol,
        streamUseCase: any StreamUseCaseProtocol,
        setupUseCase: any SetupUseCaseProtocol,
        appPreferencesUseCase: any AppPreferencesUseCaseProtocol
    ) -> AppViewModel {
        AppViewModel(
            remoteViewModel: remoteViewModel,
            channelUseCase: channelUseCase, guideUseCase: guideUseCase,
            recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            setupUseCase: setupUseCase, appPreferencesUseCase: appPreferencesUseCase)
    }
}
