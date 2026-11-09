import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaSample

/// StreamUseCase (ライブ視聴) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct StreamUseCaseTests {
    @Test func streamCleansUpBeforeStarting() async throws {
        let repository = RecordingStreamRepository()
        let stream = StreamUseCase(stream: repository)
        let id = try await stream.startLiveStream(channelCode: "JP-G00000001")
        #expect(id == 5)
        // 前に止められずに残った、このアプリの配信を先に止めてから頼む
        #expect(repository.events == ["cleanUp", "start JP-G00000001"])
    }
}
