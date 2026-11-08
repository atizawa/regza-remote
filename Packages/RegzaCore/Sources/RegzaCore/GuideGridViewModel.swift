import Foundation
import Observation

/// 新聞のテレビ欄のような番組表の画面の ViewModel (iOS と Android で共有)。横に局、縦に時刻を並べる
@MainActor
@Observable
public final class GuideGridViewModel {
    public let remote: RemoteViewModel
    public let guide: any GuideUseCaseProtocol
    public let recording: any RecordingUseCaseProtocol
    /// 番組表から開く検索。開き直しても前に探した言葉を残すので、番組表と一緒に持つ
    public let search: GuideSearchViewModel

    public init(remote: RemoteViewModel, guide: any GuideUseCaseProtocol, recording: any RecordingUseCaseProtocol) {
        self.remote = remote
        self.guide = guide
        self.recording = recording
        search = GuideSearchViewModel(remote: remote, guide: guide)
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
        public var columns: [GuideColumn]
        /// 日付の選択肢。最初は今日 (date が nil)、そのあと明日から番組表がある最後の日まで
        public var days: [GuideDay]
        /// 選んでいる日 (その日の朝 4 時)。nil なら今日 (今の時刻から 24 時間)
        public var selectedDay: Date?
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
        let now = Date()
        let columns = remote.state.channels
            .filter { $0.band == band && guide.guidePrograms[$0.code] != nil }
            .groupingSubchannels()
            .map { guide.column($0, now: now) }
        return State(
            hasGuide: guide.hasGuide,
            hasLoaded: hasLoaded,
            canSearch: guide.hasGuide && hasLoaded && !columns.isEmpty,
            bands: bands,
            columns: columns,
            days: guide.guideDays(now: now),
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
            "days": .array(state.days.map { .object(["day": JSONValue(reflecting: $0.date as Any), "label": .string($0.label)]) }),
            "columns": .array(state.columns.map { column in
                .object([
                    "channel": .string(column.channelCode),
                    "name": .string(column.channelName),
                    "programCount": .number(Double(column.programs.count)),
                    "onAir": column.programs.first { $0.start <= now && now < $0.end }.map { .object([
                        "id": .number(Double($0.id)), "name": .string($0.name),
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
            guard let day = state.days.compactMap(\.date).first(where: { $0.formatted(.iso8601) == text }) else {
                throw IntrospectionError.invalidArgument("day")
            }
            send(.selectDay(day))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
