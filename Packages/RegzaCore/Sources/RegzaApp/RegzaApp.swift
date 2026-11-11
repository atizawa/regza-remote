// 組み立てる場所 (Composition Root)。どの Repository の実装を使うかを決め、アプリ全体の ViewModel を作る。
// iOS・Android・CLI は、ここから作った AppViewModel を使う (画面の ViewModel は UseCase しか知らない)
// 組み立てには Domain の型 (保存先・Repository) が要るので、Domain も見せる (画面は RegzaPresentation だけを使う)
@_exported import RegzaDomain
@_exported import RegzaInfrastructure
@_exported import RegzaPresentation

extension AppViewModel {
    /// 本物のテレビと録画サーバーにつなぐ、アプリ全体の ViewModel を作る
    /// - Parameters:
    ///   - remote: テレビのリモコン。番組表を補う Mirakurun を短い待ち時間で渡すときなどに使う。渡さなければ作る
    ///   - transport: 録画サーバーとの通信 (テストや見本の返事に差し替える)
    public convenience init(
        secureStorage: SecureStorageManager,
        preferences: PreferencesManager,
        remote: RegzaRemote? = nil,
        transport: any HTTPTransport = RegzaHTTP.transport
    ) {
        let connectionState = RegzaConnectionState(
            connection: RegzaTVRepository.loadConnection(secureStorage: secureStorage, preferences: preferences))
        let client = remote?.client ?? RegzaAPIClient(connection: connectionState.connection, transport: transport)
        let guideClient = MirakurunAPIClient(host: (preferences.value(forKey: .guideHost) ?? ""), transport: transport)
        // 状態の定期確認を待たせないよう、番組名を補う通信だけ待ち時間を短くする。
        let remoteGuide = MirakurunAPIClient(host: (preferences.value(forKey: .guideHost) ?? ""), timeout: 3, transport: transport)
        let remote = remote ?? RegzaRemote(client: client, guide: (preferences.value(forKey: .guideHost) ?? "").isEmpty ? nil : remoteGuide)
        let tv = RegzaTVRepository(
            secureStorage: secureStorage, preferences: preferences, client: client, connectionState: connectionState, remote: remote)
        let model = RemoteViewModel(tv: TVUseCase(tv: tv))
        let guide = MirakurunGuideRepository(preferences: preferences, client: guideClient)
        let stream = EPGStationStreamRepository(
            preferences: preferences,
            client: EPGStationAPIClient(host: (preferences.value(forKey: .streamHost) ?? ""), transport: transport))
        let recording = RegzaRecordingRepository(client: client, connectionState: connectionState)
        self.init(
            remote: model,
            channels: ChannelUseCase(tv: tv, guide: guide),
            guide: GuideUseCase(guide: guide, recording: recording),
            recording: RecordingUseCase(recording: recording, guide: guide),
            stream: StreamUseCase(stream: stream, guide: guide),
            setup: SetupUseCase(devices: NetworkDeviceRepository(transport: transport), guide: guide, stream: stream) {
                [weak tv, weak model] host in
                // Repository の変更後の連携は UseCase を起点に行う。
                await tv?.updateGuide(client: host.isEmpty ? nil : remoteGuide.replacingHost(host))
                model?.send(.refresh)
            }
        )
    }
}

extension RemoteViewModel {
    /// テレビに登録されているチャンネル (SharedModel)。画面のない入口 (iOS の Siri) が、チャンネルの名前から選ぶのに使う。
    /// 取得前は空なので、先に loadChannels を送って待つ
    public var registeredChannels: [ChannelItem] { channels }
}
