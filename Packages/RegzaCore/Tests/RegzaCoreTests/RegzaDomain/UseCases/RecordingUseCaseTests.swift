import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaSample

/// RecordingUseCase (録画予約) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct RecordingUseCaseTests {
    @Test func reservationItemsDescribeScheduleAndChannel() async throws {
        let recording = SampleRecordingRepository(reservations: [
            try UseCaseFixtures.reservation(id: "1", channelCode: "JP-G00000001", start: UseCaseFixtures.date(hour: 12, minute: 45)),
            try UseCaseFixtures.reservation(id: "2", channelCode: "JP-G00000009", start: UseCaseFixtures.date(day: 1, hour: 21), series: true),
        ])
        let useCase = RecordingUseCase(recording: recording)
        let items = useCase.items(channels: try UseCaseFixtures.channels(), now: UseCaseFixtures.now)

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
        #expect(useCase.reservations.map(\.id) == ["2"])
    }
}
