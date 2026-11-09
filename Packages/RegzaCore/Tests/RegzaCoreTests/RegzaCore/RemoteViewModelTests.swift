import Foundation
import Testing
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// リモコンの ViewModel を、偽の通信と保存先で確かめる (iOS と Android で同じふるまいになることの確認)
@MainActor
@Suite struct RemoteViewModelTests {
    func makeModel(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) -> (RemoteViewModel, FakeTransport, MemoryStore) {
        let transport = FakeTransport(respond)
        let live = LiveModels(transport: transport)
        return (live.remote, transport, live.store)
    }

    @Test func tuneShowsChannelRightAway() async throws {
        let (model, transport, _) = makeModel { request in
            request.url.path.hasSuffix("channel_list") ? ViewModelFixtures.ok(ViewModelFixtures.channelList) : ViewModelFixtures.ok(#"{"status":0}"#)
        }
        let observer = RecordingObserver()
        model.observer = observer
        try await model.loadChannels()
        let channel = try #require(model.channels.last)

        try await model.tune(to: channel)

        // テレビに問い合わせ直さずに、選んだチャンネルに切り替わったものとして出す
        #expect(model.state.nowPlaying?.channelCode == channel.code)
        #expect(model.nowPlayingChannel == channel)
        #expect(model.state.lastError == nil)
        #expect(model.state.tapCount == 1)
        #expect(transport.paths.last == "/v2/remote/status/channel")
        #expect(observer.events == ["update \(channel.code) connected", "tune"])
    }

    @Test func refreshFailureKeepsError() async {
        let (model, _, _) = makeModel { _ in HTTPResponse(statusCode: 500, headers: [:], body: Data()) }
        let observer = RecordingObserver()
        model.observer = observer

        await model.refresh()

        #expect(model.state.lastError == .httpStatus(500))
        #expect(model.state.nowPlaying == nil)
        #expect(observer.events == ["update - disconnected"])
    }

    @Test func savingAnotherTVForgetsWhatWasLoaded() async throws {
        let live = LiveModels(transport: FakeTransport { request in
            switch request.url.path {
            case "/v2/remote/settings/channel_list": ViewModelFixtures.ok(ViewModelFixtures.channelList)
            case "/v2/remote/pvr/reserves/list": ViewModelFixtures.ok(ViewModelFixtures.reservationList)
            default: HTTPResponse(statusCode: 500, headers: [:], body: Data())
            }
        })
        let (model, store, recording) = (live.remote, live.store, live.recording)
        try await model.loadChannels()
        try await recording.loadReservations()
        #expect(model.channels.count == 2)
        #expect(recording.reservations.map(\.id) == ["1"])

        let other = RegzaConnection(host: "192.0.2.20", user: "user", password: "password")
        await model.save(other)
        model.send(.stopPolling)

        #expect(store.load() == other)
        #expect(model.connection == other)
        #expect(model.channels.isEmpty)
        // 予約は前のテレビのものなので出さない
        #expect(recording.reservations.isEmpty)
    }

    @Test func streamNeedsGuide() {
        let live = LiveModels(transport: FakeTransport { _ in ViewModelFixtures.ok("") })
        live.stream.saveStreamHost(" 192.0.2.30 ")
        #expect(live.store.streamHost == "192.0.2.30")
        // EPGStation は Mirakurun から放送を受け取るので、番組表がないと使わない
        #expect(!live.stream.canStream)
    }

    @Test func sampleModeDoesNotTalkToTV() async {
        let model = AppViewModel.sample(connection: RegzaConnection(host: "192.0.2.1"), nowPlaying: nil, channels: []).remote
        model.send(.press(.power))
        try? await model.loadChannels(force: true)
        #expect(model.state.tapCount == 1)
        #expect(model.state.isSampleMode)
    }

    @Test func introspectionPressesKeys() async throws {
        let (model, transport, _) = makeModel { request in
            request.url.path == "/remote/remote.htm" ? ViewModelFixtures.ok("0") : HTTPResponse(statusCode: 500, headers: [:], body: Data())
        }
        let introspector = Introspector(root: model)
        try introspector.perform("remote", "press", ["key": .string("power")])
        #expect(model.isBusy)
        #expect(await introspector.waitUntilIdle())
        #expect(transport.paths.first == "/remote/remote.htm")
        #expect(model.state.tapCount == 1)
        #expect(throws: IntrospectionError.invalidArgument("key")) {
            try introspector.perform("remote", "press", ["key": .string("nothing")])
        }
    }
}
