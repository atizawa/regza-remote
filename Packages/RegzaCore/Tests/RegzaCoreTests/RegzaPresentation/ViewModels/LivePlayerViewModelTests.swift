import Foundation
import Testing
@testable import RegzaPresentation
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// ライブ視聴の ViewModel
@MainActor
@Suite struct LivePlayerViewModelTests {
    let fixtures = ViewModelFixtures()

    func makePlayer(channelCode: String, _ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        throws -> (LivePlayerViewModel, FakeTransport, MemoryStore) {
        let store = MemoryStore(connection: RegzaConnection(host: "192.0.2.10"))
        // 配信を頼めるのは、番組表と EPGStation の両方を設定しているとき
        store.guideHost = "192.0.2.2"
        store.streamHost = "192.0.2.30"
        let transport = FakeTransport(respond)
        let live = LiveModels(store: store, transport: transport)
        let player = LivePlayerViewModel(
            remote: live.remote, channels: live.channels, guide: live.guide, stream: live.stream,
            channel: try fixtures.channel(code: channelCode)
        )
        return (player, transport, store)
    }

    /// 条件を満たすまで待つ (配信の準備は別の Task で進む)
    func wait(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func playsThenStopsTheStream() async throws {
        let (player, transport, store) = try makePlayer(channelCode: "JP-G00000001") { request in
            switch (request.method, request.url.path) {
            case ("GET", let path) where path.hasPrefix("/api/streams/live/"):
                ViewModelFixtures.status(200, #"{"streamId":5}"#)
            case ("GET", "/streamfiles/stream5.m3u8"):
                ViewModelFixtures.status(200, "#EXTM3U\nsegment0.ts\n")
            default:
                ViewModelFixtures.status(200, "{}")
            }
        }
        player.send(.start)
        await wait { if case .ready = player.state.phase { true } else { false } }

        #expect(player.state.phase == .ready(url: try #require(URL(string: "http://192.0.2.30:8888/streamfiles/stream5.m3u8"))))
        // 止められずに残ったときに次に開いて止められるよう、頼んだ配信を覚えておく
        #expect(store.ownStreamIDs == [5])

        player.send(.end)
        #expect(player.state.phase == .preparing)
        await wait { store.ownStreamIDs.isEmpty }
        #expect(store.ownStreamIDs.isEmpty)
        #expect(transport.paths.contains("/api/streams/5"))
    }

    @Test func explainsWhenStreamDoesNotStart() async throws {
        let (player, _, store) = try makePlayer(channelCode: "JP-G00000001") { _ in ViewModelFixtures.status(500) }
        player.send(.start)
        await wait { if case .failed = player.state.phase { true } else { false } }
        guard case .failed(let message, let canRetry) = player.state.phase else {
            Issue.record("失敗にならなかった: \(player.state.phase)")
            return
        }
        #expect(message.hasPrefix("再生できませんでした。"))
        #expect(canRetry)
        #expect(store.ownStreamIDs.isEmpty)
    }

    @Test func refusesChannelThatEPGStationDoesNotKnow() async throws {
        let (player, transport, _) = try makePlayer(channelCode: "unknown") { _ in ViewModelFixtures.status(200, "{}") }
        player.send(.start)
        await wait { player.state.phase != .preparing }
        #expect(player.state.phase == .failed(message: "このチャンネルは EPGStation で見られません。", canRetry: false))
        #expect(transport.paths.isEmpty)
    }
}
