import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
@testable import RegzaSample

/// リモコンの ViewModel を、偽の通信と保存先で確かめる (iOS と Android で同じふるまいになることの確認)
@MainActor
@Suite struct RemoteViewModelTests {
    func makeModel(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) -> (RemoteViewModel, FakeTransport, MemoryStore) {
        let transport = FakeTransport(respond)
        let live = LiveModels(transport: transport)
        return (live.remoteViewModel, transport, live.store)
    }

    @Test func tuneShowsChannelRightAway() async throws {
        let (remoteViewModel, transport, _) = makeModel { request in
            request.url.path.hasSuffix("channel_list")
                ? ViewModelFixtures.ok(ViewModelFixtures.channelList) : ViewModelFixtures.ok(#"{"status":0}"#)
        }
        try await remoteViewModel.loadChannels()
        let channel = try #require(remoteViewModel.channels.last)

        try await remoteViewModel.tune(to: channel)

        // テレビに問い合わせ直さずに、選んだチャンネルに切り替わったものとして出す
        #expect(remoteViewModel.state.nowPlaying?.channelCode == channel.code)
        #expect(remoteViewModel.nowPlayingChannel == channel)
        #expect(remoteViewModel.state.errorMessage == nil)
        #expect(remoteViewModel.lastError == nil)
        #expect(remoteViewModel.state.tapCount == 1)
        #expect(transport.paths.last == "/v2/remote/status/channel")
        #expect(remoteViewModel.state.isConnected)
        #expect(remoteViewModel.state.lastCommandLabel == nil)
    }

    @Test func pressingKeyShowsItUntilTuning() async throws {
        let (remoteViewModel, _, _) = makeModel { request in
            request.url.path.hasSuffix("channel_list")
                ? ViewModelFixtures.ok(ViewModelFixtures.channelList) : ViewModelFixtures.ok(#"{"status":0}"#)
        }
        // 画面のない入口 (Siri など) は、送った操作が終わるまで待てる
        await remoteViewModel.sendAndWait(.press(.volumeUp))
        #expect(!remoteViewModel.isBusy)
        #expect(remoteViewModel.state.lastCommandLabel == RegzaKey.volumeUp.label)

        try await remoteViewModel.loadChannels()
        try await remoteViewModel.tune(to: try #require(remoteViewModel.channels.first))
        #expect(remoteViewModel.state.lastCommandLabel == nil)
    }

    @Test func refreshFailureKeepsError() async {
        let (remoteViewModel, _, _) = makeModel { _ in HTTPResponse(statusCode: 500, headers: [:], body: Data()) }
        await remoteViewModel.refresh()

        #expect(remoteViewModel.lastError == .httpStatus(500))
        #expect(remoteViewModel.state.errorMessage == RegzaError.httpStatus(500).localizedDescription)
        #expect(remoteViewModel.state.nowPlaying == nil)
        #expect(!remoteViewModel.state.isConnected)
    }

    @Test func refreshFailureKeepsWhatWasShowingAsDisconnected() async throws {
        final class Failing: @unchecked Sendable { var value = false }
        let failing = Failing()
        let (remoteViewModel, _, _) = makeModel { request in
            if failing.value { return HTTPResponse(statusCode: 500, headers: [:], body: Data()) }
            return request.url.path.hasSuffix("channel_list")
                ? ViewModelFixtures.ok(ViewModelFixtures.channelList) : ViewModelFixtures.ok(#"{"status":0}"#)
        }
        try await remoteViewModel.loadChannels()
        let channel = try #require(remoteViewModel.channels.first)
        try await remoteViewModel.tune(to: channel)

        failing.value = true
        await remoteViewModel.refresh()

        // 一時的な失敗で番組情報が消えないよう、直前のものを残し、つながっていないことだけを出す (ロック画面も同じ state を読む)
        #expect(remoteViewModel.state.nowPlaying?.channelCode == channel.code)
        #expect(!remoteViewModel.state.isConnected)
    }

    @Test func savingAnotherTVForgetsWhatWasLoaded() async throws {
        let live = LiveModels(
            transport: FakeTransport { request in
                switch request.url.path {
                case "/v2/remote/settings/channel_list": ViewModelFixtures.ok(ViewModelFixtures.channelList)
                case "/v2/remote/pvr/reserves/list": ViewModelFixtures.ok(ViewModelFixtures.reservationList)
                default: HTTPResponse(statusCode: 500, headers: [:], body: Data())
                }
            })
        let (remoteViewModel, store, recordingUseCase) = (live.remoteViewModel, live.store, live.recordingUseCase)
        try await remoteViewModel.loadChannels()
        try await recordingUseCase.loadReservations()
        #expect(remoteViewModel.channels.count == 2)
        #expect(recordingUseCase.reservations.map(\.id) == ["1"])

        let other = ConnectionData(host: "192.0.2.20", user: "user", password: "password")
        await remoteViewModel.save(UseCaseModelMapper.connection(other))
        remoteViewModel.send(.stopPolling)

        #expect(store.load() == other)
        #expect(remoteViewModel.connection == UseCaseModelMapper.connection(other))
        #expect(remoteViewModel.channels.isEmpty)
        // 予約は前のテレビのものなので出さない
        #expect(recordingUseCase.reservations.isEmpty)
    }

    @Test func streamNeedsGuide() {
        let live = LiveModels(transport: FakeTransport { _ in ViewModelFixtures.ok("") })
        live.streamUseCase.saveStreamHost(" 192.0.2.30 ")
        #expect(live.store.streamHost == "192.0.2.30")
        // EPGStation は Mirakurun から放送を受け取るので、番組表がないと使わない
        #expect(!live.streamUseCase.canStream)
    }

    @Test func sampleModeDoesNotTalkToTV() async {
        let remoteViewModel = AppViewModel.sample(connection: ConnectionData(host: "192.0.2.1"), nowPlaying: nil, channels: [])
            .remoteViewModel
        remoteViewModel.send(.press(.power))
        try? await remoteViewModel.loadChannels(force: true)
        #expect(remoteViewModel.state.tapCount == 1)
        #expect(remoteViewModel.state.isSampleMode)
    }

    @Test func introspectionPressesKeys() async throws {
        let (remoteViewModel, transport, _) = makeModel { request in
            request.url.path == "/remote/remote.htm" ? ViewModelFixtures.ok("0") : HTTPResponse(statusCode: 500, headers: [:], body: Data())
        }
        let introspector = Introspector(root: remoteViewModel)
        try introspector.perform("remote", "press", ["key": .string("power")])
        #expect(remoteViewModel.isBusy)
        #expect(await introspector.waitUntilIdle())
        #expect(transport.paths.first == "/remote/remote.htm")
        #expect(remoteViewModel.state.tapCount == 1)
        #expect(throws: IntrospectionError.invalidArgument("key")) {
            try introspector.perform("remote", "press", ["key": .string("nothing")])
        }
    }
}
