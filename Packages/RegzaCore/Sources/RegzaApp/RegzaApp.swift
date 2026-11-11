// 組み立てる場所 (Composition Root)。どの Repository の実装を使うかを決め、アプリ全体の ViewModel を作る。
// iOS・Android・CLI は、ここから作った AppViewModel を使う (画面の ViewModel は UseCase しか知らない)
// 組み立てには Domain の型 (保存先・Repository) が要るので、Domain も見せる (画面は RegzaPresentation だけを使う)
@_exported import RegzaDomain
@_exported import RegzaInfrastructure
@_exported import RegzaPresentation

extension AppViewModel {
    /// 本物のテレビと録画サーバーにつなぐ、アプリ全体の ViewModel を作る
    /// - Parameters:
    ///   - regzaRemote: テレビのリモコン。番組表を補う Mirakurun を短い待ち時間で渡すときなどに使う。渡さなければ作る
    ///   - transport: 録画サーバーとの通信 (テストや見本の返事に差し替える)
    public convenience init(
        secureStorageManager: SecureStorageManager,
        preferencesManager: PreferencesManager,
        regzaRemote: RegzaRemote? = nil,
        transport: any HTTPTransport = RegzaHTTP.transport
    ) {
        let connectionState = RegzaConnectionState(
            connection: RegzaTVRepository.loadConnection(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
        )
        let regzaAPIClient = regzaRemote?.regzaAPIClient ?? RegzaAPIClient(connection: connectionState.connection, transport: transport)
        let guideAPIClient = MirakurunAPIClient(host: (preferencesManager.value(forKey: .guideHost) ?? ""), transport: transport)
        // 状態の定期確認を待たせないよう、番組名を補う通信だけ待ち時間を短くする。
        let remoteGuideAPIClient = MirakurunAPIClient(
            host: (preferencesManager.value(forKey: .guideHost) ?? ""), timeout: 3, transport: transport)
        let regzaRemote =
            regzaRemote
            ?? RegzaRemote(
                regzaAPIClient: regzaAPIClient,
                mirakurunAPIClient: (preferencesManager.value(forKey: .guideHost) ?? "").isEmpty ? nil : remoteGuideAPIClient)
        let tvRepository = RegzaTVRepository(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, regzaAPIClient: regzaAPIClient,
            connectionState: connectionState, regzaRemote: regzaRemote)
        let remoteViewModel = RemoteViewModel(tvUseCase: TVUseCase(tvRepository: tvRepository))
        let guideRepository = MirakurunGuideRepository(preferencesManager: preferencesManager, mirakurunAPIClient: guideAPIClient)
        let streamRepository = EPGStationStreamRepository(
            preferencesManager: preferencesManager,
            epgStationAPIClient: EPGStationAPIClient(host: (preferencesManager.value(forKey: .streamHost) ?? ""), transport: transport))
        let recordingRepository = RegzaRecordingRepository(regzaAPIClient: regzaAPIClient, connectionState: connectionState)
        self.init(
            remoteViewModel: remoteViewModel,
            channelUseCase: ChannelUseCase(tvRepository: tvRepository, guideRepository: guideRepository),
            guideUseCase: GuideUseCase(guideRepository: guideRepository, recordingRepository: recordingRepository),
            recordingUseCase: RecordingUseCase(recordingRepository: recordingRepository, guideRepository: guideRepository),
            streamUseCase: StreamUseCase(streamRepository: streamRepository, guideRepository: guideRepository),
            setupUseCase: SetupUseCase(
                deviceRepository: NetworkDeviceRepository(transport: transport), guideRepository: guideRepository,
                streamRepository: streamRepository
            ) {
                [weak tvRepository, weak remoteViewModel] host in
                // Repository の変更後の連携は UseCase を起点に行う。
                await tvRepository?.updateGuide(mirakurunAPIClient: host.isEmpty ? nil : remoteGuideAPIClient.replacingHost(host))
                remoteViewModel?.send(.refresh)
            }
        )
    }
}

extension RemoteViewModel {
    /// テレビに登録されているチャンネル (SharedModel)。画面のない入口 (iOS の Siri) が、チャンネルの名前から選ぶのに使う。
    /// 取得前は空なので、先に loadChannels を送って待つ
    public var registeredChannels: [ChannelItem] { channels }
}
