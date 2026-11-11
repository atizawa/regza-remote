import Foundation

@MainActor
public protocol GuideUseCaseProtocol: AnyObject {
    var guideHost: String { get }
    var hasGuide: Bool { get }
    var guideChannelCodes: Set<String> { get }
    var guideProgramsLoadedAt: Date? { get }
    func loadGuidePrograms() async
    func programs(for channel: ChannelItem) async throws(RegzaError) -> [ProgramItem]
    func program(id: Int, channelCode: String) -> ProgramItem?
    func currentProgram(for channel: ChannelItem, at date: Date) -> ProgramItem?
    func saveGuideHost(_ host: String) async
    func item(_ program: ProgramItem, now: Date) -> ProgramItem
    func texts(of program: ProgramItem) -> [ProgramTextItem]
    func days(_ programs: [ProgramItem], now: Date) -> [ProgramDay]
    func column(_ channel: ChannelItem, now: Date) -> GuideColumn
    func guideDays(now: Date) -> [GuideDay]
    func searchResult(_ result: SearchResultItem, now: Date) -> SearchResultItem?
    func updateSearchIndex() async
    func search(_ query: ProgramSearchQuery, channels: [ChannelItem], now: Date) -> [SearchResultItem]
}

extension GuideUseCaseProtocol {
    public func currentProgram(for channel: ChannelItem) -> ProgramItem? {
        currentProgram(for: channel, at: Date())
    }
    public func item(_ program: ProgramItem) -> ProgramItem { item(program, now: Date()) }
    public func days(_ programs: [ProgramItem]) -> [ProgramDay] { days(programs, now: Date()) }
    public func column(_ channel: ChannelItem) -> GuideColumn { column(channel, now: Date()) }
    public func guideDays() -> [GuideDay] { guideDays(now: Date()) }
    public func search(_ query: ProgramSearchQuery, channels: [ChannelItem]) -> [SearchResultItem] {
        search(query, channels: channels, now: Date())
    }
}

/// Repository の Data と検索索引を内部に保ち、SharedModel だけを返す。
@MainActor
public final class GuideUseCase: GuideUseCaseProtocol {
    private let guide: any GuideRepositoryProtocol
    private let recording: any RecordingRepositoryProtocol
    private var searchIndex = ProgramSearchIndex([])
    private var indexedAt: Date?
    private var indexedHost: String?

    public init(guide: any GuideRepositoryProtocol, recording: any RecordingRepositoryProtocol) {
        self.guide = guide
        self.recording = recording
    }

    public var guideHost: String { guide.guideHost }
    public var hasGuide: Bool { guide.hasGuide }
    public var guideChannelCodes: Set<String> { Set(guide.guidePrograms.keys) }
    public var guideProgramsLoadedAt: Date? { guide.guideProgramsLoadedAt }

    public func loadGuidePrograms() async { await guide.loadGuidePrograms() }

    public func programs(for channel: ChannelItem) async throws(RegzaError) -> [ProgramItem] {
        let programs = try await guide.programs(channelCode: channel.code)
        return programs.map { item($0, now: Date()) }
    }

    public func program(id: Int, channelCode: String) -> ProgramItem? {
        guide.program(id: id, channelCode: channelCode).map { item($0, now: Date()) }
    }

    public func currentProgram(for channel: ChannelItem, at date: Date = Date()) -> ProgramItem? {
        guide.guidePrograms[channel.code]?.first { $0.isOnAir(at: date) }.map { item($0, now: date) }
    }

    public func saveGuideHost(_ host: String) async {
        await guide.saveGuideHost(host)
        searchIndex = ProgramSearchIndex([])
        indexedAt = nil
        indexedHost = nil
    }

    public func item(_ program: ProgramItem, now: Date = Date()) -> ProgramItem {
        guard let data = guide.program(id: program.id, channelCode: program.channelCode) else { return program }
        return item(data, now: now)
    }

    func item(_ data: ProgramData, now: Date = Date()) -> ProgramItem {
        UseCaseModelMapper.program(data, isReserved: recording.isReserved(data), now: now)
    }

    public func texts(of program: ProgramItem) -> [ProgramTextItem] {
        guard let data = guide.program(id: program.id, channelCode: program.channelCode) else { return [] }
        return UseCaseModelMapper.programTexts(data)
    }

    public func days(_ programs: [ProgramItem], now: Date = Date()) -> [ProgramDay] {
        Dictionary(grouping: programs) { Calendar.current.startOfDay(for: $0.start) }
            .map { date, programs in
                ProgramDay(date: date, label: DisplayText.day(date), programs: programs.map { item($0, now: now) })
            }.sorted { $0.date < $1.date }
    }

    func days(_ programs: [ProgramData], now: Date = Date()) -> [ProgramDay] {
        days(programs.map { item($0, now: now) }, now: now)
    }

    public func column(_ channel: ChannelItem, now: Date = Date()) -> GuideColumn {
        GuideColumn(
            channelCode: channel.code, channelName: channel.name,
            programs: (guide.guidePrograms[channel.code] ?? []).map { item($0, now: now) })
    }

    public func guideDays(now: Date = Date()) -> [GuideDay] {
        ([nil] + Self.days(guide.guidePrograms, now: now)).map {
            GuideDay(date: $0, label: Self.label(of: $0, now: now), kind: Self.kind(of: $0))
        }
    }

    public func updateSearchIndex() async {
        let loadedAt = guide.guideProgramsLoadedAt
        let host = guide.guideHost
        guard loadedAt != indexedAt || host != indexedHost || searchIndex.isEmpty else { return }
        let programs = guide.guidePrograms.values.flatMap { $0 }
        let index = await Task.detached { ProgramSearchIndex(programs) }.value
        guard loadedAt == guide.guideProgramsLoadedAt, host == guide.guideHost else { return }
        searchIndex = index
        indexedAt = loadedAt
        indexedHost = host
    }

    public func search(_ query: ProgramSearchQuery, channels: [ChannelItem], now: Date = Date()) -> [SearchResultItem] {
        guard !query.isEmpty, indexedHost == guide.guideHost, indexedAt == guide.guideProgramsLoadedAt else { return [] }
        return searchIndex.search(query, now: now).compactMap { result in
            guard let channel = channels.first(where: { $0.code.caseInsensitiveCompare(result.program.channelCode) == .orderedSame }) else {
                return nil
            }
            return searchResult(result, channel: channel, now: now)
        }
    }

    public func searchResult(_ result: SearchResultItem, now: Date) -> SearchResultItem? {
        guard let data = guide.program(id: result.program.id, channelCode: result.program.channelCode) else { return nil }
        var result = result
        result.program = item(data, now: now)
        result.timeText = Self.searchTimeText(of: data, now: now)
        return result
    }

    func searchResult(_ result: ProgramSearchResult, channel: ChannelItem, now: Date = Date()) -> SearchResultItem {
        SearchResultItem(
            program: item(result.program, now: now), channelCode: channel.code, channelName: channel.name,
            timeText: Self.searchTimeText(of: result.program, now: now), reason: Self.reason(for: result))
    }

    // MARK: - 表記

    /// 明日から、Mirakurun が番組表を持っている最後の日まで
    static func days(_ programs: [String: [ProgramData]], now: Date) -> [Date] {
        let today = BroadcastDay.start(of: now)
        guard let last = programs.values.compactMap({ $0.last?.start }).max() else { return [] }
        let lastDay = BroadcastDay.start(of: last)
        var result: [Date] = []
        var day = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        while day <= lastDay {
            result.append(day)
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? lastDay.addingTimeInterval(1)
        }
        return result
    }

    /// 「今日」「明日」「9(月)」
    static func label(of day: Date?, now: Date = Date()) -> String {
        guard let day else { return "今日" }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: BroadcastDay.start(of: now))
        if day == tomorrow { return "明日" }
        let formatter = DateFormatter()
        formatter.locale = DisplayText.locale
        formatter.dateFormat = "d(E)"
        return formatter.string(from: day)
    }

    static func kind(of day: Date?) -> GuideDayKind {
        guard let day else { return .weekday }
        switch Calendar.current.component(.weekday, from: day) {
        case 7: return .saturday
        case 1: return .sunday
        default: return .weekday
        }
    }

    /// 「11/5(木) 21:00〜」。放送中は「放送中 〜21:54」
    static func searchTimeText(of program: ProgramData, now: Date = Date()) -> String {
        if program.isOnAir(at: now) { return "放送中 〜\(DisplayText.time(program.end))" }
        let day = program.start.formatted(.dateTime.locale(DisplayText.locale).month(.defaultDigits).day().weekday())
        return "\(day) \(DisplayText.time(program.start))〜"
    }

    /// 番組名に入っていれば言うまでもないので、出演者と説明のときだけ添える
    static func reason(for result: ProgramSearchResult) -> String? {
        let reasons = result.matches.compactMap { match -> String? in
            switch match.field {
            case .title: nil
            case .cast: "\(match.term) が出演"
            case .description: "説明に「\(match.term)」"
            }
        }
        return reasons.isEmpty ? nil : reasons.joined(separator: "・")
    }
}
