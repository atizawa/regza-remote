import Testing

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaApp
@testable import RegzaDomain
@testable import ReservationsPresentation
@testable import SettingsPresentation

@MainActor
@Suite struct AppFactoryTests {
    @Test func injectedUseCaseReceivesCommandsAndReturnsErrors() async {
        let tvUseCase = TVUseCaseProtocolMock(clock: .system, connection: .init(host: "192.0.2.1"))
        tvUseCase.sendHandler = { _ throws(RegzaError) in throw .httpStatus(503) }
        let appViewModel = AppFactory.makeAppViewModel(
            tvUseCase: tvUseCase,
            channelUseCase: ChannelUseCaseProtocolMock(), guideUseCase: GuideUseCaseProtocolMock(),
            recordingUseCase: RecordingUseCaseProtocolMock(), streamUseCase: StreamUseCaseProtocolMock(),
            setupUseCase: SetupUseCaseProtocolMock(), appPreferencesUseCase: AppPreferencesUseCaseProtocolMock(appearance: .system))

        await appViewModel.remoteViewModel.sendAndWait(.press(.volumeUp))

        #expect(tvUseCase.sendArgValues == [.volumeUp])
        #expect(appViewModel.remoteViewModel.lastError == .httpStatus(503))
    }

    @Test func separateAppsKeepTheirOwnTransportAndStorage() async {
        let firstTransport = FakeHTTPTransport { _ in FakeHTTPTransport.response(500) }
        let secondTransport = FakeHTTPTransport { _ in FakeHTTPTransport.response(503) }
        let first = HTTPTestEnvironment(
            store: TestStorage(connection: .init(host: "192.0.2.1")), transport: firstTransport)
        let second = HTTPTestEnvironment(
            store: TestStorage(connection: .init(host: "192.0.2.2")), transport: secondTransport)

        await first.appViewModel.remoteViewModel.sendAndWait(.press(.volumeUp))
        #expect(first.appViewModel.remoteViewModel.lastError == .httpStatus(500))
        #expect(!firstTransport.paths.isEmpty)
        #expect(secondTransport.paths.isEmpty)

        await second.appViewModel.remoteViewModel.sendAndWait(.press(.volumeDown))
        #expect(second.appViewModel.remoteViewModel.lastError == .httpStatus(503))
        #expect(first.appViewModel.remoteViewModel.connection.host == "192.0.2.1")
        #expect(second.appViewModel.remoteViewModel.connection.host == "192.0.2.2")
    }
}
