import RegzaDomain
import RegzaPresentation
import RegzaSharedModels

extension AppFactory {
    /// 注入された Repository を共有して UseCase を組み立てる。
    public static func makeAppViewModel(
        tvRepository: any TVRepositoryProtocol,
        guideRepository: any GuideRepositoryProtocol,
        recordingRepository: any RecordingRepositoryProtocol,
        streamRepository: any StreamRepositoryProtocol,
        deviceRepository: any DeviceRepositoryProtocol,
        appPreferencesRepository: any AppPreferencesRepositoryProtocol,
        initialNowPlaying: NowPlayingItem? = nil,
        onGuideHostChange: @escaping @MainActor (String) async -> Void = { _ in }
    ) -> AppViewModel {
        let remoteViewModel = makeRemoteViewModel(
            tvUseCase: TVUseCase(tvRepository: tvRepository), nowPlaying: initialNowPlaying)
        return makeAppViewModel(
            remoteViewModel: remoteViewModel,
            channelUseCase: ChannelUseCase(tvRepository: tvRepository, guideRepository: guideRepository),
            guideUseCase: GuideUseCase(guideRepository: guideRepository, recordingRepository: recordingRepository),
            recordingUseCase: RecordingUseCase(recordingRepository: recordingRepository, guideRepository: guideRepository),
            streamUseCase: StreamUseCase(streamRepository: streamRepository, guideRepository: guideRepository),
            setupUseCase: SetupUseCase(
                deviceRepository: deviceRepository, guideRepository: guideRepository, streamRepository: streamRepository
            ) { [weak remoteViewModel] host in
                await onGuideHostChange(host)
                remoteViewModel?.send(.refresh)
            },
            appPreferencesUseCase: AppPreferencesUseCase(appPreferencesRepository: appPreferencesRepository)
        )
    }

}
