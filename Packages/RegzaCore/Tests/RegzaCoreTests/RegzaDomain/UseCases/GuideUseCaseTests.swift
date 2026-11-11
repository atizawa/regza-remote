import Foundation
import Testing

@testable import RegzaDomain

/// GuideUseCase (番組) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct GuideUseCaseTests {
    @Test func programItemHasTextsAndReservedMark() throws {
        let onAir = try TestData.program(id: 1, start: TestData.date(hour: 13), genre: 3)
        let later = try TestData.program(id: 2, start: TestData.date(hour: 14))
        let recordingRepository = RecordingRepositoryProtocolMock(reservations: [
            try TestData.reservation(id: "1", channelCode: "JP-G00000001", epgContentID: later.epgContentID, start: later.start)
        ])
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: [onAir, later]),
            recordingRepository: recordingRepository)

        let item = guideUseCase.item(onAir, now: TestData.now)
        #expect(item.startText == "13:00")
        #expect(item.timeText == "11月7日(土) 13:00 〜 13:45 · 45分")
        #expect(item.genre == 3)
        #expect(item.genreName == "ドラマ")
        #expect(item.isOnAir)
        #expect(!item.isReserved)

        let reserved = guideUseCase.item(later, now: TestData.now)
        #expect(!reserved.isOnAir)
        // テレビの予約の番組 ID と、Mirakurun の番組の ID が同じ放送の番組なら予約済み
        #expect(reserved.isReserved)
        #expect(guideUseCase.item(onAir).genre == 3)
        #expect(try guideUseCase.item(TestData.program(id: 3, start: TestData.now)).genre == -1)
    }

    @Test func programsAreGroupedByDay() throws {
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "", programs: []),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: []))
        let days = guideUseCase.days(
            [
                try TestData.program(id: 3, start: TestData.date(day: 8, hour: 9)),
                try TestData.program(id: 1, start: TestData.date(hour: 13)),
                try TestData.program(id: 2, start: TestData.date(hour: 23)),
            ], now: TestData.now)
        #expect(days.map(\.label) == ["11月7日(土)", "11月8日(日)"])
        #expect(days.map { $0.programs.map(\.id) } == [[1, 2], [3]])
    }

    @Test func guideDaysRunUntilLastProgram() throws {
        let programs = [try TestData.program(id: 1, start: TestData.date(day: 9, hour: 10))]
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: programs),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: [])
        )
        let days = guideUseCase.guideDays(now: TestData.now)
        // 今日 (今の時刻から)、明日、そのあとは「9(月)」のように日付で書く。日付は朝 4 時から
        #expect(days.map(\.label) == ["今日", "明日", "9(月)"])
        #expect(days.map(\.kind) == [.weekday, .sunday, .weekday])
        #expect(days.first?.date == nil)
        #expect(days[1].date == TestData.date(day: 8, hour: 4))
    }

    @Test func searchResultExplainsTimeAndReason() throws {
        let onAir = try TestData.program(id: 1, start: TestData.date(hour: 12, minute: 30), minutes: 60)
        let later = try TestData.program(id: 2, start: TestData.date(day: 8, hour: 21))
        let channel = try #require(TestData.channels().first)
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "", programs: []),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: []))

        let byCast = guideUseCase.searchResult(
            ProgramSearchResult(program: onAir, matches: [.init(term: "見本太郎", field: .cast)]), channel: UseCaseModelMapper.channel(channel),
            now: TestData.now)
        #expect(byCast.timeText == "放送中 〜13:30")
        #expect(byCast.reason == "見本太郎 が出演")
        #expect(byCast.channelName == "テスト局１")

        let byTitle = guideUseCase.searchResult(
            ProgramSearchResult(program: later, matches: [.init(term: "見本", field: .title)]), channel: UseCaseModelMapper.channel(channel),
            now: TestData.now)
        #expect(byTitle.timeText == "11/8(日) 21:00〜")
        // 番組名に入っていれば、理由は言わない
        #expect(byTitle.reason == nil)
    }

    @Test func programIsFoundByIDForDetail() throws {
        let program = try TestData.program(id: 7, start: TestData.now)
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: [program]),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: []))
        #expect(guideUseCase.program(id: 7, channelCode: "JP-G00000001")?.id == program.id)
        #expect(guideUseCase.program(id: 7, channelCode: "JP-G00000002") == nil)
    }
}
