import Foundation

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// 本物の Repository を、偽の通信と保存先でつないだもの (RegzaApp の組み立てと同じつなぎ方)
@MainActor
struct LiveModels {
    let store: MemoryStore
    let tvRepository: RegzaTVRepository
    let remoteViewModel: RemoteViewModel
    let channelUseCase: ChannelUseCase
    let guideUseCase: GuideUseCase
    let recordingUseCase: RecordingUseCase
    let streamUseCase: StreamUseCase
    let setupUseCase: SetupUseCase

    init(
        store: MemoryStore = MemoryStore(connection: ConnectionData(host: "192.0.2.10", user: "user", password: "password")),
        transport: FakeTransport
    ) {
        self.store = store
        let regzaAPIClient = RegzaAPIClient(connection: store.load(), transport: transport)
        let connectionState = RegzaConnectionState(connection: store.load())
        tvRepository = RegzaTVRepository(
            secureStorageManager: store.secureStorageManager, preferencesManager: store.preferencesManager, regzaAPIClient: regzaAPIClient,
            connectionState: connectionState)
        remoteViewModel = RemoteViewModel(tvUseCase: TVUseCase(tvRepository: tvRepository))
        let guideRepository = MirakurunGuideRepository(
            preferencesManager: store.preferencesManager,
            mirakurunAPIClient: MirakurunAPIClient(host: store.guideHost, transport: transport))
        let streamRepository = EPGStationStreamRepository(
            preferencesManager: store.preferencesManager,
            epgStationAPIClient: EPGStationAPIClient(host: store.streamHost, transport: transport))
        let recordingRepository = RegzaRecordingRepository(regzaAPIClient: regzaAPIClient, connectionState: connectionState)
        channelUseCase = ChannelUseCase(tvRepository: tvRepository, guideRepository: guideRepository)
        self.guideUseCase = GuideUseCase(guideRepository: guideRepository, recordingRepository: recordingRepository)
        self.recordingUseCase = RecordingUseCase(recordingRepository: recordingRepository, guideRepository: guideRepository)
        self.streamUseCase = StreamUseCase(streamRepository: streamRepository, guideRepository: guideRepository)
        setupUseCase = SetupUseCase(
            deviceRepository: NetworkDeviceRepository(transport: transport), guideRepository: guideRepository,
            streamRepository: streamRepository)
    }

    var appViewModel: AppViewModel {
        AppViewModel(
            remoteViewModel: remoteViewModel, channelUseCase: channelUseCase, guideUseCase: guideUseCase,
            recordingUseCase: recordingUseCase, streamUseCase: streamUseCase, setupUseCase: setupUseCase)
    }
}
