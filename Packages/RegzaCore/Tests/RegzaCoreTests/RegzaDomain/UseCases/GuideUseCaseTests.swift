import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaSample

/// GuideUseCase (番組) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct GuideUseCaseTests {
    @Test func programItemHasTextsAndReservedMark() throws {
        let onAir = try UseCaseFixtures.program(id: 1, start: UseCaseFixtures.date(hour: 13), genre: 3)
        let later = try UseCaseFixtures.program(id: 2, start: UseCaseFixtures.date(hour: 14))
        let recording = SampleRecordingRepository(reservations: [
            try UseCaseFixtures.reservation(id: "1", channelCode: "JP-G00000001", epgContentID: later.epgContentID, start: later.start)
        ])
        let guide = GuideUseCase(guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: [onAir, later]), recording: recording)

        let item = guide.item(onAir, now: UseCaseFixtures.now)
        #expect(item.startText == "13:00")
        #expect(item.timeText == "11月7日(土) 13:00 〜 13:45 · 45分")
        #expect(item.genre == 3)
        #expect(item.genreName == "ドラマ")
        #expect(item.isOnAir)
        #expect(!item.isReserved)

        let reserved = guide.item(later, now: UseCaseFixtures.now)
        #expect(!reserved.isOnAir)
        // テレビの予約の番組 ID と、Mirakurun の番組の ID が同じ放送の番組なら予約済み
        #expect(reserved.isReserved)
        #expect(guide.item(onAir).genre == 3)
        #expect(try guide.item(UseCaseFixtures.program(id: 3, start: UseCaseFixtures.now)).genre == -1)
    }

    @Test func programsAreGroupedByDay() throws {
        let guide = GuideUseCase(
            guide: SampleGuideRepository(guideHost: "", programs: []), recording: SampleRecordingRepository(reservations: []))
        let days = guide.days(
            [
                try UseCaseFixtures.program(id: 3, start: UseCaseFixtures.date(day: 8, hour: 9)),
                try UseCaseFixtures.program(id: 1, start: UseCaseFixtures.date(hour: 13)),
                try UseCaseFixtures.program(id: 2, start: UseCaseFixtures.date(hour: 23)),
            ], now: UseCaseFixtures.now)
        #expect(days.map(\.label) == ["11月7日(土)", "11月8日(日)"])
        #expect(days.map { $0.programs.map(\.id) } == [[1, 2], [3]])
    }

    @Test func guideDaysRunUntilLastProgram() throws {
        let programs = [try UseCaseFixtures.program(id: 1, start: UseCaseFixtures.date(day: 9, hour: 10))]
        let guide = GuideUseCase(
            guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: programs), recording: SampleRecordingRepository(reservations: [])
        )
        let days = guide.guideDays(now: UseCaseFixtures.now)
        // 今日 (今の時刻から)、明日、そのあとは「9(月)」のように日付で書く。日付は朝 4 時から
        #expect(days.map(\.label) == ["今日", "明日", "9(月)"])
        #expect(days.map(\.kind) == [.weekday, .sunday, .weekday])
        #expect(days.first?.date == nil)
        #expect(days[1].date == UseCaseFixtures.date(day: 8, hour: 4))
    }

    @Test func searchResultExplainsTimeAndReason() throws {
        let onAir = try UseCaseFixtures.program(id: 1, start: UseCaseFixtures.date(hour: 12, minute: 30), minutes: 60)
        let later = try UseCaseFixtures.program(id: 2, start: UseCaseFixtures.date(day: 8, hour: 21))
        let channel = try #require(UseCaseFixtures.channels().first)
        let guide = GuideUseCase(
            guide: SampleGuideRepository(guideHost: "", programs: []), recording: SampleRecordingRepository(reservations: []))

        let byCast = guide.searchResult(
            ProgramSearchResult(program: onAir, matches: [.init(term: "見本太郎", field: .cast)]), channel: UseCaseModelMapper.channel(channel),
            now: UseCaseFixtures.now)
        #expect(byCast.timeText == "放送中 〜13:30")
        #expect(byCast.reason == "見本太郎 が出演")
        #expect(byCast.channelName == "テスト局１")

        let byTitle = guide.searchResult(
            ProgramSearchResult(program: later, matches: [.init(term: "見本", field: .title)]), channel: UseCaseModelMapper.channel(channel),
            now: UseCaseFixtures.now)
        #expect(byTitle.timeText == "11/8(日) 21:00〜")
        // 番組名に入っていれば、理由は言わない
        #expect(byTitle.reason == nil)
    }

    @Test func programIsFoundByIDForDetail() throws {
        let program = try UseCaseFixtures.program(id: 7, start: UseCaseFixtures.now)
        let guide = GuideUseCase(
            guide: SampleGuideRepository(guideHost: "192.0.2.2", programs: [program]),
            recording: SampleRecordingRepository(reservations: []))
        #expect(guide.program(id: 7, channelCode: "JP-G00000001")?.id == program.id)
        #expect(guide.program(id: 7, channelCode: "JP-G00000002") == nil)
    }
}
