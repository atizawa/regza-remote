// 組み立てる場所 (Composition Root)。どの Repository の実装を使うかを決め、アプリ全体の ViewModel を作る。
// iOS・Android・CLI は、ここから作った AppViewModel を使う (画面の ViewModel は UseCase しか知らない)
@_exported import RegzaPresentation
@_exported import RegzaInfrastructure

extension AppViewModel {
    /// 本物のテレビと録画サーバーにつなぐ、アプリ全体の ViewModel を作る
    /// - Parameters:
    ///   - remote: テレビのリモコン。iOS は Live Activity のボタン (App Intents) と同じものを渡す。渡さなければ作る
    ///   - transport: 録画サーバーとの通信 (テストや見本の返事に差し替える)
    public convenience init(
        store: any RegzaConnectionStore,
        remote: RegzaRemote? = nil,
        transport: any HTTPTransport = RegzaHTTP.transport
    ) {
        let tv = RegzaTVRepository(store: store, remote: remote)
        let model = RemoteViewModel(tv: TVUseCase(tv: tv))
        // 番組表のアドレスが変わったら、番組名を補う番組表も差し替えて、いま映っているものを取り直す
        let guide = MirakurunGuideRepository(store: store, transport: transport) { [weak tv, weak model] host in
            await tv?.updateGuide(host: host)
            model?.send(.refresh)
        }
        let stream = EPGStationStreamRepository(store: store, guide: guide, transport: transport)
        let recording = RegzaRecordingRepository(tv: tv)
        self.init(
            remote: model,
            channels: ChannelUseCase(tv: tv, guide: guide),
            guide: GuideUseCase(guide: guide, recording: recording),
            recording: RecordingUseCase(recording: recording),
            stream: StreamUseCase(stream: stream),
            setup: SetupUseCase(devices: NetworkDeviceRepository(transport: transport), guide: guide, stream: stream)
        )
    }
}
