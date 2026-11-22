import Foundation

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import ReservationsPresentation
@testable import SettingsPresentation

/// ViewModel のテストで使う、テレビの応答の見本と、画面の ViewModel の組み立て
@MainActor
struct ViewModelFixtures {
    func makeHTTPApp(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) -> AppViewModel {
        HTTPTestEnvironment(transport: FakeHTTPTransport(respond)).appViewModel
    }

    /// テストで必要な入力を明示して、Repository の偽物を直接注入する。
    func makeApp(
        connection: ConnectionData = .init(host: "192.0.2.1"),
        nowPlaying: NowPlayingData? = nil, channels: [ChannelData],
        guideHost: String? = nil, programs: [ProgramData] = [], reservations: [ReservationData] = [],
        guideRepository: GuideRepositoryProtocolMock? = nil
    ) -> AppViewModel {
        let tvRepository = TVRepositoryProtocolMock(connection: connection, channels: channels, nowPlaying: nowPlaying)
        return AppFactory.makeAppViewModel(
            tvRepository: tvRepository,
            guideRepository: guideRepository
                ?? GuideRepositoryProtocolMock(guideHost: guideHost ?? (programs.isEmpty ? "" : "192.0.2.2"), programs: programs),
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
