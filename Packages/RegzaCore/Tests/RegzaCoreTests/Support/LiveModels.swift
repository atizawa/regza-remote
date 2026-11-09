import Foundation
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp

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

    init(store: MemoryStore = MemoryStore(connection: RegzaConnection(host: "192.0.2.10", user: "user", password: "password")),
         transport: FakeTransport) {
        self.store = store
        tv = RegzaTVRepository(store: store, remote: RegzaRemote(connection: store.load(), transport: transport))
        remote = RemoteViewModel(tv: TVUseCase(tv: tv))
        let guide = MirakurunGuideRepository(store: store, transport: transport)
        let stream = EPGStationStreamRepository(store: store, guide: guide, transport: transport)
        let recording = RegzaRecordingRepository(tv: tv)
        channels = ChannelUseCase(tv: tv, guide: guide)
        self.guide = GuideUseCase(guide: guide, recording: recording)
        self.recording = RecordingUseCase(recording: recording)
        self.stream = StreamUseCase(stream: stream)
        setup = SetupUseCase(devices: NetworkDeviceRepository(transport: transport), guide: guide, stream: stream)
    }

    var app: AppViewModel {
        AppViewModel(remote: remote, channels: channels, guide: guide, recording: recording, stream: stream, setup: setup)
    }
}
