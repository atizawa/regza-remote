import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaSample

/// TVUseCase (テレビ) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct TVUseCaseTests {
    @Test func nowPlayingItemUsesDomainTexts() {
        let tv = TVUseCase(tv: SampleTVRepository(connection: RegzaConnection(host: "192.0.2.1"), channels: [], nowPlaying: nil))
        let recorded = tv.item(
            RegzaNowPlaying(
                kind: .recorded, channelName: "テスト局１", title: "見本の録画", position: 60, duration: 120, isAdvancing: true
            ))
        #expect(recorded.kind == .recorded)
        #expect(recorded.captionText == "録画 · テスト局１")
        #expect(recorded.headlineText == "見本の録画")
        #expect(recorded.progress == 0.5)
        #expect(recorded.hasTimeline)

        let standby = tv.item(RegzaNowPlaying(kind: .standby))
        #expect(standby.kind == .standby)
        #expect(standby.statusText == "待機中")
        #expect(standby.headlineText == "待機中")
        #expect(standby.captionText == nil)
    }

    @Test func startOverJumpsAfterTuning() async throws {
        let repository = RecordingTVRepository()
        let tv = TVUseCase(tv: repository)
        let channel = try #require(UseCaseFixtures.channels().first)

        try await tv.startOver()
        #expect(repository.events == ["key jumpToStart"])

        // 切り替えた直後は「始めにジャンプ」が効かないので、選局のあとに送る
        _ = try await tv.tuneAndStartOver(channel)
        #expect(repository.events == ["key jumpToStart", "tune JP-G00000001", "key jumpToStart"])
    }
}
