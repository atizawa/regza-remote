public import Foundation
public import Observation
package import RegzaDomain

/// 新聞のテレビ欄のような番組表の画面の ViewModel。横に局、縦に時刻を並べる
@MainActor
@Observable
public final class GuideGridViewModel {
    public let remote: RemoteViewModel
    package let guide: any GuideUseCaseProtocol
    package let recording: any RecordingUseCaseProtocol
    /// 番組表から開く検索。開き直しても前に探した言葉を残すので、番組表と一緒に持つ
    public let search: GuideSearchViewModel

    package init(remote: RemoteViewModel, guide: any GuideUseCaseProtocol, recording: any RecordingUseCaseProtocol) {
        self.remote = remote
        self.guide = guide
        self.recording = recording
        search = GuideSearchViewModel(remote: remote, guide: guide)
    }

    /// 1 画面に出す時間 (今の時刻の正時から 24 時間)
    public static let hours = 24

    /// 画面に出すもの
    public typealias State = GuideGridState

    /// 画面からの操作
    public typealias Action = GuideGridAction

    private var hasLoaded = false
    private var selectedDay: Date?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let bands = Self.bands(remote.channels, guide.guidePrograms)
        let band = remote.band(among: bands)
        let now = Date()
        let window = Self.window(now: now, day: selectedDay)
        let columns = remote.channels
            .filter { $0.band == band && guide.guidePrograms[$0.code] != nil }
            .groupingSubchannels()
            .map { guide.column($0, now: now) }
            .map { column in
                var column = column
                column.programs = column.programs.filter { $0.end > window.lowerBound && $0.start < window.upperBound }
                return column
            }
        let days = guide.guideDays(now: now)
        return State(
            hasGuide: guide.hasGuide,
            hasLoaded: hasLoaded,
            canSearch: guide.hasGuide && hasLoaded && !columns.isEmpty,
            bands: bands,
            band: band,
            columns: columns,
            days: days,
            selectedDay: selectedDay,
            selectedDayIndex: days.firstIndex { $0.date == selectedDay } ?? 0,
            isToday: selectedDay == nil,
            windowStart: window.lowerBound,
            windowEnd: window.upperBound,
            hourLabels: (0..<Self.hours).map {
                "\(BroadcastDay.hour(of: window.lowerBound.addingTimeInterval(TimeInterval($0 * 3600))))"
            }
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
    package static func window(now: Date, day: Date? = nil) -> ClosedRange<Date> {
        let start = day ?? Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        return start...start.addingTimeInterval(TimeInterval(hours * 3600))
    }

    private static func bands(_ channels: [RegzaChannel], _ programs: [String: [MirakurunProgram]]) -> [BroadcastBand] {
        BroadcastBand.allCases.filter { band in
            channels.contains { $0.band == band && programs[$0.code] != nil }
        }
    }
}

extension GuideGridViewModel: IntrospectableActions {
    public var introspectionName: String { "guideGrid" }
    public var isBusy: Bool { work.isBusy }
    public var introspectionChildren: [any Introspectable] { [search] }

    /// 番組表は 1 週間分あると大きいので、局ごとに番組の数と放送中の番組名だけを見せる
    nonisolated public static func introspectionJSON(of state: State) -> JSONValue {
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

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "load": return .load
        case "selectDay":
            guard arguments["day"] != nil else { return .selectDay(nil) }
            let text = try arguments.string("day")
            guard let day = state.days.compactMap(\.date).first(where: { $0.formatted(.iso8601) == text }) else {
                throw IntrospectionError.invalidArgument("day")
            }
            return .selectDay(day)
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
