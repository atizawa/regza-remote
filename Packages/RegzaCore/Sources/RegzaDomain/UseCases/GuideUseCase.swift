import Foundation

/// 番組表 (Mirakurun): 全局の番組表・1 チャンネルの番組表・放送中の番組・番組の録画予約。
/// 番組は、UI の型 (RegzaSharedModels) にして返す。予約済みの印を付けるため、録画予約の Repository も見る
@MainActor
public protocol GuideUseCaseProtocol: AnyObject {
    /// Mirakurun のアドレス。未設定なら空
    var guideHost: String { get }

    var hasGuide: Bool { get }

    /// 全局の番組を、チャンネルの ID ごとに時刻順で持つ
    var guidePrograms: [String: [MirakurunProgram]] { get }

    /// 番組表を読み込んだ時刻 (検索の索引を作り直すかを決めるのに使う)
    var guideProgramsLoadedAt: Date? { get }

    func loadGuidePrograms() async

    /// 1 チャンネルの番組表 (放送中の番組から)
    func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram]

    /// 全局の番組表か、1 チャンネルの番組表で読んだ番組 (番組の詳細を開くとき、番組の id から引く)
    func program(id: Int, channelCode: String) -> MirakurunProgram?

    /// そのチャンネルでいま放送中の番組
    func currentProgram(for channel: RegzaChannel, at date: Date) -> MirakurunProgram?

    func saveGuideHost(_ host: String) async

    /// 番組 (予約済みの印つき)
    func item(_ program: MirakurunProgram, now: Date) -> ProgramItem

    /// 番組内容・出演者など、見出しつきの説明
    func texts(of program: MirakurunProgram) -> [ProgramTextItem]

    /// 1 チャンネルの番組を、日ごとに分ける
    func days(_ programs: [MirakurunProgram], now: Date) -> [ProgramDay]

    /// 番組表の 1 局分 (全局の番組表から)
    func column(_ channel: RegzaChannel, now: Date) -> GuideColumn

    /// 番組表の日付の選択肢。最初は今日、そのあと明日から番組表がある最後の日まで
    func guideDays(now: Date) -> [GuideDay]

    /// 検索で見つかった番組
    func searchResult(_ result: ProgramSearchResult, channel: RegzaChannel, now: Date) -> SearchResultItem
}

extension GuideUseCaseProtocol {
    public func currentProgram(for channel: RegzaChannel) -> MirakurunProgram? {
        currentProgram(for: channel, at: Date())
    }

    public func item(_ program: MirakurunProgram) -> ProgramItem {
        item(program, now: Date())
    }

    public func days(_ programs: [MirakurunProgram]) -> [ProgramDay] {
        days(programs, now: Date())
    }

    public func column(_ channel: RegzaChannel) -> GuideColumn {
        column(channel, now: Date())
    }

    public func guideDays() -> [GuideDay] {
        guideDays(now: Date())
    }

    public func searchResult(_ result: ProgramSearchResult, channel: RegzaChannel) -> SearchResultItem {
        searchResult(result, channel: channel, now: Date())
    }
}

/// 番組表 (Mirakurun): 全局の番組表・1 チャンネルの番組表・放送中の番組・番組の録画予約。
/// 番組は、UI の型 (RegzaSharedModels) にして返す。予約済みの印を付けるため、録画予約の Repository も見る
@MainActor
public final class GuideUseCase: GuideUseCaseProtocol {
    private let guide: any GuideRepositoryProtocol
    private let recording: any RecordingRepositoryProtocol

    public init(guide: any GuideRepositoryProtocol, recording: any RecordingRepositoryProtocol) {
        self.guide = guide
        self.recording = recording
    }

    /// Mirakurun のアドレス。未設定なら空
    public var guideHost: String { guide.guideHost }
    public var hasGuide: Bool { guide.hasGuide }
    /// 全局の番組を、チャンネルの ID ごとに時刻順で持つ
    public var guidePrograms: [String: [MirakurunProgram]] { guide.guidePrograms }
    /// 番組表を読み込んだ時刻 (検索の索引を作り直すかを決めるのに使う)
    public var guideProgramsLoadedAt: Date? { guide.guideProgramsLoadedAt }

    public func loadGuidePrograms() async {
        await guide.loadGuidePrograms()
    }

    /// 1 チャンネルの番組表 (放送中の番組から)
    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        try await guide.programs(for: channel)
    }

    /// 全局の番組表か、1 チャンネルの番組表で読んだ番組 (番組の詳細を開くとき、番組の id から引く)
    public func program(id: Int, channelCode: String) -> MirakurunProgram? {
        guide.program(id: id, channelCode: channelCode)
    }

    /// そのチャンネルでいま放送中の番組
    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guide.currentProgram(for: channel, at: date)
    }

    public func saveGuideHost(_ host: String) async {
        await guide.saveGuideHost(host)
    }

    // MARK: - UI の型

    /// 番組 (予約済みの印つき)
    public func item(_ program: MirakurunProgram, now: Date = Date()) -> ProgramItem {
        let minutes = Int(program.end.timeIntervalSince(program.start) / 60)
        return ProgramItem(
            id: program.id,
            channelCode: program.channelCode,
            name: program.name,
            description: program.description,
            start: program.start,
            end: program.end,
            startText: DisplayText.time(program.start),
            timeText: "\(DisplayText.range(program.start, program.end)) · \(minutes)分",
            genreName: program.genreName,
            genre: program.genres.first ?? -1,
            isOnAir: program.isOnAir(at: now),
            isReserved: recording.isReserved(program)
        )
    }

    /// 番組内容・出演者など、見出しつきの説明
    public func texts(of program: MirakurunProgram) -> [ProgramTextItem] {
        program.extended.map { ProgramTextItem(title: $0.title, text: $0.text) }
    }

    /// 1 チャンネルの番組を、日ごとに分ける
    public func days(_ programs: [MirakurunProgram], now: Date = Date()) -> [ProgramDay] {
        let calendar = Calendar.current
        return Dictionary(grouping: programs) { calendar.startOfDay(for: $0.start) }
            .map { date, programs in
                ProgramDay(date: date, label: DisplayText.day(date), programs: programs.map { item($0, now: now) })
            }
            .sorted { $0.date < $1.date }
    }

    /// 番組表の 1 局分 (全局の番組表から)
    public func column(_ channel: RegzaChannel, now: Date = Date()) -> GuideColumn {
        GuideColumn(
            channelCode: channel.code,
            channelName: channel.name,
            programs: (guidePrograms[channel.code] ?? []).map { item($0, now: now) }
        )
    }

    /// 番組表の日付の選択肢。最初は今日、そのあと明日から番組表がある最後の日まで
    public func guideDays(now: Date = Date()) -> [GuideDay] {
        ([nil] + Self.days(guidePrograms, now: now)).map {
            GuideDay(date: $0, label: Self.label(of: $0, now: now), kind: Self.kind(of: $0))
        }
    }

    /// 検索で見つかった番組
    public func searchResult(_ result: ProgramSearchResult, channel: RegzaChannel, now: Date = Date()) -> SearchResultItem {
        SearchResultItem(
            program: item(result.program, now: now),
            channelCode: channel.code,
            channelName: channel.name,
            timeText: Self.searchTimeText(of: result.program, now: now),
            reason: Self.reason(for: result)
        )
    }

    // MARK: - 表記

    /// 明日から、Mirakurun が番組表を持っている最後の日まで
    static func days(_ programs: [String: [MirakurunProgram]], now: Date) -> [Date] {
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
    static func searchTimeText(of program: MirakurunProgram, now: Date = Date()) -> String {
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
