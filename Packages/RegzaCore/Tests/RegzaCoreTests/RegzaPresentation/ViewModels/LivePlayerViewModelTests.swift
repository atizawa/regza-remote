import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// ライブ視聴の ViewModel
@MainActor
@Suite struct LivePlayerViewModelTests {
    let fixtures = ViewModelFixtures()

    func makePlayer(channelCode: String, _ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        throws -> (LivePlayerViewModel, FakeHTTPTransport, TestStorage)
    {
        let store = TestStorage(connection: ConnectionData(host: "192.0.2.10"))
        // 配信を頼めるのは、番組表と EPGStation の両方を設定しているとき
        store.guideHost = "192.0.2.2"
        store.streamHost = "192.0.2.30"
        let transport = FakeHTTPTransport(respond)
        let live = HTTPTestEnvironment(store: store, transport: transport)
        let livePlayerViewModel = LivePlayerViewModel(
            remoteViewModel: live.appViewModel.remoteViewModel, channelUseCase: live.appViewModel.channelUseCase,
            guideUseCase: live.appViewModel.guideUseCase,
            streamUseCase: live.appViewModel.streamUseCase,
            channel: TestData.channel(code: channelCode)
        )
        return (livePlayerViewModel, transport, store)
    }

    /// 条件を満たすまで待つ (配信の準備は別の Task で進む)
    func wait(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func playsThenStopsTheStream() async throws {
        let (livePlayerViewModel, transport, store) = try makePlayer(channelCode: "JP-G00000001") { request in
            switch (request.method, request.url.path) {
            case ("GET", let path) where path.hasPrefix("/api/streams/live/"):
                FakeHTTPTransport.response(200, #"{"streamId":5}"#)
            case ("GET", "/streamfiles/stream5.m3u8"):
                FakeHTTPTransport.response(200, "#EXTM3U\nsegment0.ts\n")
            default:
                FakeHTTPTransport.response(200, "{}")
            }
        }
        livePlayerViewModel.send(.start)
        await wait { if case .ready = livePlayerViewModel.state.phase { true } else { false } }

        #expect(
            livePlayerViewModel.state.phase == .ready(url: try #require(URL(string: "http://192.0.2.30:8888/streamfiles/stream5.m3u8"))))
        // 止められずに残ったときに次に開いて止められるよう、頼んだ配信を覚えておく
        #expect(store.ownStreamIDs == [5])

        livePlayerViewModel.send(.end)
        #expect(livePlayerViewModel.state.phase == .preparing)
        await wait { store.ownStreamIDs.isEmpty }
        #expect(store.ownStreamIDs.isEmpty)
        #expect(transport.paths.contains("/api/streams/5"))
    }

    @Test func explainsWhenStreamDoesNotStart() async throws {
        let (livePlayerViewModel, _, store) = try makePlayer(channelCode: "JP-G00000001") { _ in FakeHTTPTransport.response(500) }
        livePlayerViewModel.send(.start)
        await wait { if case .failed = livePlayerViewModel.state.phase { true } else { false } }
        guard case .failed(let message, let canRetry) = livePlayerViewModel.state.phase else {
            Issue.record("失敗にならなかった: \(livePlayerViewModel.state.phase)")
            return
        }
        #expect(message.hasPrefix("再生できませんでした。"))
        #expect(canRetry)
        #expect(store.ownStreamIDs.isEmpty)
    }

    @Test func refusesChannelThatEPGStationDoesNotKnow() async throws {
        let (livePlayerViewModel, transport, _) = try makePlayer(channelCode: "unknown") { _ in FakeHTTPTransport.response(200, "{}") }
        livePlayerViewModel.send(.start)
        await wait { livePlayerViewModel.state.phase != .preparing }
        #expect(livePlayerViewModel.state.phase == .failed(message: "このチャンネルは EPGStation で見られません。", canRetry: false))
        #expect(transport.paths.isEmpty)
    }
}
