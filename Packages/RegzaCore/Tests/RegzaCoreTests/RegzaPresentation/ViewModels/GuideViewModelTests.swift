import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
@testable import RegzaSample

/// 番組表と検索の ViewModel
@MainActor
@Suite struct GuideViewModelTests {
    let fixtures = ViewModelFixtures()

    /// テスト局１ (JP-G00000001) の番組。start は今からの秒数
    func program(id: Int, startingIn offset: TimeInterval, name: String = "テスト番組") throws -> ProgramData {
        let start = Int((Date().timeIntervalSince1970 + offset) * 1000)
        let json = #"{"id":\#(id),"eventId":\#(id),"networkId":0,"serviceId":1,"startAt":\#(start),"duration":1800000,"name":"\#(name)"}"#
        return try JSONDecoder().decode(ProgramData.self, from: Data(json.utf8))
    }

    func channels() throws -> [ChannelData] {
        try #require(try JSONDecoder().decode(RegzaChannelList.self, from: Data(ViewModelFixtures.channelList.utf8)).channels)
    }

    @Test func gridShowsChannelsThatHavePrograms() async throws {
        let app = fixtures.sampleApp(
            channels: try channels(),
            programs: [
                try program(id: 1, startingIn: 0),
                try program(id: 2, startingIn: 3 * 86_400),
            ])
        let (remote, guide, recording) = (app.remote, app.guide, app.recording)
        let viewModel = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        let state = viewModel.state

        // 番組表があるのは地デジのテスト局１だけ。BS の局は番組表がないので出さない
        #expect(state.bands == [.terrestrial])
        #expect(state.columns.map(\.channelName) == ["テスト局１"])
        // 表に出す時間 (今日は今の時刻の正時から 24 時間) にかかる番組だけを持つ
        #expect(state.columns.first?.programs.map(\.id) == [1])
        #expect(state.band == .terrestrial)
        #expect(state.isToday)
        #expect(state.selectedDayIndex == 0)
        #expect(state.windowEnd.timeIntervalSince(state.windowStart) == 24 * 3600)
        #expect(state.hourLabels.count == 24)
        // 今日のあと、明日から番組表がある最後の日まで
        let today = BroadcastDay.start(of: Date())
        #expect(state.days.first?.date == nil)
        #expect(state.days.dropFirst().first?.date == Calendar.current.date(byAdding: .day, value: 1, to: today))
        let lastDay = BroadcastDay.start(of: Date().addingTimeInterval(3 * 86_400))
        #expect(state.days.last?.date == lastDay)
        // 読み込むまでは検索を出さない
        #expect(!state.canSearch)

        let day = try #require(state.days.last?.date)
        viewModel.send(.selectDay(day))
        #expect(viewModel.state.selectedDay == day)
    }

    @Test func gridDescribesDays() throws {
        let today = BroadcastDay.start(of: Date())
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: today))
        #expect(GuideUseCase.label(of: nil) == "今日")
        #expect(GuideUseCase.label(of: tomorrow) == "明日")
        // 2026-11-07 は土曜、11-08 は日曜
        let saturday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 4)))
        #expect(GuideUseCase.kind(of: saturday) == .saturday)
        #expect(GuideUseCase.kind(of: saturday.addingTimeInterval(86_400)) == .sunday)
        #expect(GuideUseCase.label(of: saturday.addingTimeInterval(7 * 86_400)).hasSuffix("(土)"))
        // 今日は今の時刻の正時から 24 時間、ほかの日はその日の朝 4 時から
        let now = Date()
        let window = GuideGridViewModel.window(now: now)
        #expect(window.lowerBound <= now && now < window.lowerBound.addingTimeInterval(3600))
        #expect(window.upperBound.timeIntervalSince(window.lowerBound) == 24 * 3600)
        #expect(GuideGridViewModel.window(now: now, day: tomorrow).lowerBound == tomorrow)
    }

    @Test func searchFindsProgramsAndReadsConditions() async throws {
        let app = fixtures.sampleApp(
            channels: try channels(),
            programs: [
                try program(id: 1, startingIn: -60, name: "あおぞら散歩"),
                try program(id: 2, startingIn: 86_400, name: "みどり劇場"),
            ])
        let (remote, guide, recording) = (app.remote, app.guide, app.recording)
        let grid = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        let search = grid.search
        // 番組表を読むと索引を作る (読めなくても、見本の番組表はそのまま使う)
        await fixtures.send(grid) { $0.send(.load) }
        #expect(!search.state.isIndexing)

        search.send(.setText("あおぞら"))
        var state = search.state
        #expect(state.results.map(\.program.id) == [1])
        #expect(state.results.first?.channelName == "テスト局１")
        #expect(state.results.first?.timeText.hasPrefix("放送中 〜") == true)
        #expect(state.results.first?.reason == nil)

        // 「明日」は条件として読み取り、外すこともできる
        search.send(.setText("明日のみどり"))
        #expect(search.state.conditions.map(\.label).contains("明日"))
        #expect(search.state.results.map(\.program.id) == [2])
        search.send(.removeCondition(.day))
        state = search.state
        #expect(!state.conditions.contains { $0.condition == .day })
        #expect(state.results.map(\.program.id) == [2])
    }

    @Test func searchExplainsWhyItFoundPrograms() throws {
        let onAir = try program(id: 1, startingIn: -60)
        let byCast = ProgramSearchResult(program: onAir, matches: [.init(term: "見本太郎", field: .cast)])
        let byTitle = ProgramSearchResult(program: onAir, matches: [.init(term: "テスト", field: .title)])
        #expect(GuideUseCase.reason(for: byCast) == "見本太郎 が出演")
        #expect(GuideUseCase.reason(for: byTitle) == nil)
    }
}
