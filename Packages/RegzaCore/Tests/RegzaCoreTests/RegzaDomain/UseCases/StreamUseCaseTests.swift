import Foundation
import Testing

@testable import RegzaDomain

/// StreamUseCase (ライブ視聴) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct StreamUseCaseTests {
    @Test func streamCleansUpBeforeStarting() async throws {
        let repository = StreamRepositoryProtocolMock(streamHost: "192.0.2.30")
        var events: [String] = []
        repository.cleanUpHandler = { events.append("cleanUp") }
        repository.startLiveStreamHandler = {
            events.append("start \($0)")
            return 5
        }
        let streamUseCase = StreamUseCase(
            streamRepository: repository, guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.20", programs: []))
        let id = try await streamUseCase.startLiveStream(channelCode: "JP-G00000001")
        #expect(id == 5)
        // 前に止められずに残った、このアプリの配信を先に止めてから頼む
        #expect(events == ["cleanUp", "start JP-G00000001"])
    }
}
