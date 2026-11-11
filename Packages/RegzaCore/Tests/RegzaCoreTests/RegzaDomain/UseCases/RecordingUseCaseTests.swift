import Foundation
import Testing

@testable import RegzaDomain

/// RecordingUseCase (録画予約) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct RecordingUseCaseTests {
    @Test func reservationItemsDescribeScheduleAndChannel() async throws {
        let recordingRepository = RecordingRepositoryProtocolMock(reservations: [
            try TestData.reservation(id: "1", channelCode: "JP-G00000001", start: TestData.date(hour: 12, minute: 45)),
            try TestData.reservation(
                id: "2", channelCode: "JP-G00000009", start: TestData.date(day: 1, hour: 21), series: true),
        ])
        let useCase = RecordingUseCase(
            recordingRepository: recordingRepository, guideRepository: GuideRepositoryProtocolMock(guideHost: "", programs: []))
        let items = useCase.items(channels: try TestData.channels().map(UseCaseModelMapper.channel), now: TestData.now)

        let recordingNow = try #require(items.first)
        #expect(recordingNow.timeText == "11月7日(土) 12:45 〜 13:15")
        #expect(recordingNow.channelName == "テスト局１")
        #expect(recordingNow.isRecording)
        #expect(recordingNow.isScheduled)
        #expect(recordingNow.repeatLabel == nil)

        let waiting = items[1]
        // 連ドラ予約で、最後に録画した回が終わっているもの (次の回を待っている)
        #expect(!waiting.isScheduled)
        #expect(waiting.isSeries)
        #expect(waiting.repeatLabel == "毎週")
        // テレビに登録されていない局は、名前を出さない
        #expect(waiting.channelName == nil)

        try await useCase.cancel(id: "1")
        #expect(recordingRepository.cancelArgValues.map(\.id) == ["1"])
    }
}
