import Foundation
import Observation

/// 新聞のテレビ欄のような番組表の画面の ViewModel (iOS と Android で共有)。横に局、縦に時刻を並べる
@MainActor
@Observable
public final class GuideGridViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel
    public let recording: ReservationsViewModel
    /// 番組表から開く検索。開き直しても前に探した言葉を残すので、番組表と一緒に持つ
    public let search: GuideSearchViewModel

    public init(remote: RemoteViewModel, guide: GuideViewModel, recording: ReservationsViewModel) {
        self.remote = remote
        self.guide = guide
        self.recording = recording
        search = GuideSearchViewModel(remote: remote, recording: recording)
    }

    /// 1 画面に出す時間 (今の時刻の正時から 24 時間)
    public static let hours = 24

    public struct State: Equatable, Sendable {
        /// 番組表 (Mirakurun) が設定されている
        public var hasGuide: Bool
        public var hasLoaded: Bool
        /// 検索を出せる (番組表を読み込めたときだけ)
        public var canSearch: Bool
        /// 番組表がある放送の種類
        public var bands: [RegzaChannel.Band]
        /// 選んだ放送の局。サブチャンネル (同じリモコン番号の局) は代表のものだけにする
        public var columns: [Column]
        /// 日付の選択肢。最初は今日 (day が nil)、そのあと明日から番組表がある最後の日まで
        public var days: [Day]
        /// 選んでいる日 (その日の朝 4 時)。nil なら今日 (今の時刻から 24 時間)
        public var selectedDay: Date?
    }

    /// 1 局分の番組
    public struct Column: Equatable, Sendable, Identifiable {
        public var channel: RegzaChannel
        public var cells: [Cell]
        public var id: String { channel.code }
    }

    public struct Cell: Equatable, Sendable, Identifiable {
        public var program: MirakurunProgram
        public var isReserved: Bool
        public var id: Int { program.id }
    }

    public struct Day: Equatable, Sendable, Identifiable {
        public var day: Date?
        /// 「今日」「明日」「6(金)」
        public var label: String
        public var kind: DayKind
        public var id: Date { day ?? .distantPast }
    }

    /// 土曜は青、日曜は赤で出す (テレビ欄と同じ)
    public enum DayKind: Sendable {
        case weekday, saturday, sunday
    }

    public enum Action: Sendable {
        /// 画面を開いた。予約した番組に印を付けるため、予約も読む
        case load
        case selectDay(Date?)
    }

    private var hasLoaded = false
    private var selectedDay: Date?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let bands = Self.bands(remote.state.channels, guide.guidePrograms)
        let band = remote.state.band(among: bands)
        let columns = remote.state.channels
            .filter { $0.band == band && guide.guidePrograms[$0.code] != nil }
            .groupingSubchannels()
            .map { channel in
                Column(channel: channel, cells: (guide.guidePrograms[channel.code] ?? []).map {
                    Cell(program: $0, isReserved: recording.isReserved($0))
                })
            }
        return State(
            hasGuide: guide.hasGuide,
            hasLoaded: hasLoaded,
            canSearch: guide.hasGuide && hasLoaded && !columns.isEmpty,
            bands: bands,
            columns: columns,
            days: ([nil] + Self.days(guide.guidePrograms)).map { Day(day: $0, label: Self.label(of: $0), kind: Self.kind(of: $0)) },
            selectedDay: selectedDay
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .load: work.run { await self.load() }
        case .selectDay(let day): if selectedDay != day { selectedDay = day }
        }
    }

    private func load() async {
        defer { hasLoaded = true }
        try? await remote.loadChannels()
        await guide.loadGuidePrograms()
        search.updateIndex(guide.guidePrograms, loadedAt: guide.guideProgramsLoadedAt)
        try? await recording.loadReservations()
    }

    // MARK: - 表に出す時間・日付

    /// 表に出す時間。今日は今の時刻の正時から 24 時間、ほかの日はその日の朝 4 時から次の日の朝 4 時まで
    public static func window(now: Date, day: Date? = nil) -> ClosedRange<Date> {
        let start = day ?? Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        return start...start.addingTimeInterval(TimeInterval(hours * 3600))
    }

    private static func bands(_ channels: [RegzaChannel], _ programs: [String: [MirakurunProgram]]) -> [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in
            channels.contains { $0.band == band && programs[$0.code] != nil }
        }
    }

    /// 明日から、Mirakurun が番組表を持っている最後の日まで
    private static func days(_ programs: [String: [MirakurunProgram]]) -> [Date] {
        let today = BroadcastDay.start(of: Date())
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

    static func label(of day: Date?) -> String {
        guard let day else { return "今日" }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: BroadcastDay.start(of: Date()))
        if day == tomorrow { return "明日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d(E)"
        return formatter.string(from: day)
    }

    static func kind(of day: Date?) -> DayKind {
        guard let day else { return .weekday }
        switch Calendar.current.component(.weekday, from: day) {
        case 7: return .saturday
        case 1: return .sunday
        default: return .weekday
        }
    }
}

extension GuideGridViewModel: Introspectable {
    public var introspectionName: String { "guideGrid" }
    public var isBusy: Bool { work.isBusy }
    public var introspectionChildren: [any Introspectable] { [search] }

    /// 番組表は 1 週間分あると大きいので、局ごとに番組の数と放送中の番組名だけを見せる
    public var introspectionValue: Any {
        let state = state
        let now = Date()
        return JSONValue.object([
            "hasGuide": .bool(state.hasGuide),
            "hasLoaded": .bool(state.hasLoaded),
            "canSearch": .bool(state.canSearch),
            "bands": JSONValue(reflecting: state.bands),
            "selectedDay": JSONValue(reflecting: state.selectedDay as Any),
            "days": .array(state.days.map { .object(["day": JSONValue(reflecting: $0.day as Any), "label": .string($0.label)]) }),
            "columns": .array(state.columns.map { column in
                .object([
                    "channel": .string(column.channel.code),
                    "name": .string(column.channel.name),
                    "programCount": .number(Double(column.cells.count)),
                    "onAir": column.cells.first { $0.program.isOnAir(at: now) }.map { .object([
                        "id": .number(Double($0.program.id)), "name": .string($0.program.name),
                    ]) } ?? .null,
                ])
            }),
        ])
    }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("load", "番組表を読む"),
            ActionDescription("selectDay", "日付を選ぶ (省くと今日)", parameters: ["day": "days の day (ISO 8601)"]),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "load": send(.load)
        case "selectDay":
            guard arguments["day"] != nil else { return send(.selectDay(nil)) }
            let text = try arguments.string("day")
            guard let day = state.days.compactMap(\.day).first(where: { $0.formatted(.iso8601) == text }) else {
                throw IntrospectionError.invalidArgument("day")
            }
            send(.selectDay(day))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
