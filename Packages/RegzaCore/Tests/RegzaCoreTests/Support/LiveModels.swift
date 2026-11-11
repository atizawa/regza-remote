import Foundation

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// 本物の Repository を、偽の通信と保存先でつないだもの (RegzaApp の組み立てと同じつなぎ方)
@MainActor
struct LiveModels {
    let store: MemoryStore
    let tv: RegzaTVRepository
    let remote: RemoteViewModel
    let channels: ChannelUseCase
    let guide: GuideUseCase
    let recording: RecordingUseCase
    let stream: StreamUseCase
    let setup: SetupUseCase

    init(
        store: MemoryStore = MemoryStore(connection: ConnectionData(host: "192.0.2.10", user: "user", password: "password")),
        transport: FakeTransport
    ) {
        self.store = store
        let client = RegzaAPIClient(connection: store.load(), transport: transport)
        let connectionState = RegzaConnectionState(connection: store.load())
        tv = RegzaTVRepository(store: store, client: client, connectionState: connectionState)
        remote = RemoteViewModel(tv: TVUseCase(tv: tv))
        let guide = MirakurunGuideRepository(store: store, client: MirakurunAPIClient(host: store.guideHost, transport: transport))
        let stream = EPGStationStreamRepository(store: store, client: EPGStationAPIClient(host: store.streamHost, transport: transport))
        let recording = RegzaRecordingRepository(client: client, connectionState: connectionState)
        channels = ChannelUseCase(tv: tv, guide: guide)
        self.guide = GuideUseCase(guide: guide, recording: recording)
        self.recording = RecordingUseCase(recording: recording, guide: guide)
        self.stream = StreamUseCase(stream: stream, guide: guide)
        setup = SetupUseCase(devices: NetworkDeviceRepository(transport: transport), guide: guide, stream: stream)
    }

    var app: AppViewModel {
        AppViewModel(remote: remote, channels: channels, guide: guide, recording: recording, stream: stream, setup: setup)
    }
}
