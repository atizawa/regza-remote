import Foundation

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// ViewModel のテストで使う、テレビの応答の見本と、画面の ViewModel の組み立て
@MainActor
struct ViewModelFixtures {
    func makeHTTPModels(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        -> (RemoteViewModel, any GuideUseCaseProtocol, any RecordingUseCaseProtocol, any StreamUseCaseProtocol)
    {
        let live = HTTPTestEnvironment(transport: FakeHTTPTransport(respond))
        return (
            live.appViewModel.remoteViewModel, live.appViewModel.guideUseCase, live.appViewModel.recordingUseCase,
            live.appViewModel.streamUseCase
        )
    }

    /// テストで必要な入力を明示して、Repository の偽物を直接注入する。
    func makeApp(
        connection: ConnectionData = .init(host: "192.0.2.1"),
        nowPlaying: NowPlayingData? = nil, channels: [ChannelData],
        guideHost: String? = nil, programs: [ProgramData] = [], reservations: [ReservationData] = [],
        isSample: Bool = false
    ) -> AppViewModel {
        let tvRepository = TVRepositoryProtocolMock(connection: connection, channels: channels, nowPlaying: nowPlaying)
        tvRepository.isSample = isSample
        return AppFactory.makeAppViewModel(
            tvRepository: tvRepository,
            guideRepository: GuideRepositoryProtocolMock(guideHost: guideHost ?? (programs.isEmpty ? "" : "192.0.2.2"), programs: programs),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: reservations),
            streamRepository: StreamRepositoryProtocolMock(streamHost: ""), deviceRepository: DeviceRepositoryProtocolMock(),
            appPreferencesRepository: AppPreferencesRepositoryProtocolMock(preferences: .init()),
            initialNowPlaying: nowPlaying.map(UseCaseModelMapper.nowPlaying))
    }

    /// 操作を送り、処理が終わるまで待つ
    func send<Model: Introspectable>(_ viewModel: Model, _ send: (Model) -> Void) async {
        send(viewModel)
        _ = await Introspector(root: viewModel).waitUntilIdle()
    }
}
