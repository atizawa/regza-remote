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

    public private(set) var hasLoaded = false
    /// 選んでいる日 (その日の朝 4 時)。nil なら今日 (今の時刻から 24 時間)
    public var day: Date?

    /// 1 局分の番組
    public struct Column: Sendable {
        public var channel: RegzaChannel
        public var programs: [MirakurunProgram]
    }

    /// 選んだ放送の局。サブチャンネル (同じリモコン番号の局) は代表のものだけにする
    public var columns: [Column] {
        let band = remote.band(among: bands)
        return remote.channels
            .filter { $0.band == band && guide.guidePrograms[$0.code] != nil }
            .groupingSubchannels()
            .map { Column(channel: $0, programs: guide.guidePrograms[$0.code] ?? []) }
    }

    /// 番組表がある放送の種類
    public var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in
            remote.channels.contains { $0.band == band && guide.guidePrograms[$0.code] != nil }
        }
    }

    /// 検索を出せるか (番組表を読み込めたときだけ)
    public var canSearch: Bool { guide.hasGuide && hasLoaded && !columns.isEmpty }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        recording.isReserved(program)
    }

    /// 表に出す時間。今日は今の時刻の正時から 24 時間、ほかの日はその日の朝 4 時から次の日の朝 4 時まで
    public func window(now: Date) -> ClosedRange<Date> {
        Self.window(now: now, day: day)
    }

    public static func window(now: Date, day: Date? = nil) -> ClosedRange<Date> {
        let start = day ?? Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        return start...start.addingTimeInterval(TimeInterval(hours * 3600))
    }

    /// 明日から、Mirakurun が番組表を持っている最後の日まで (今日は nil で表す)
    public var days: [Date] {
        let today = BroadcastDay.start(of: Date())
        guard let last = guide.guidePrograms.values.compactMap({ $0.last?.start }).max() else { return [] }
        let lastDay = BroadcastDay.start(of: last)
        var result: [Date] = []
        var day = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        while day <= lastDay {
            result.append(day)
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? lastDay.addingTimeInterval(1)
        }
        return result
    }

    /// 日付の選択肢の表記。「今日」「明日」「6(金)」
    public func label(of day: Date?) -> String {
        guard let day else { return "今日" }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: BroadcastDay.start(of: Date()))
        if day == tomorrow { return "明日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d(E)"
        return formatter.string(from: day)
    }

    /// 土曜は青、日曜は赤で出す (テレビ欄と同じ)
    public enum DayKind: Sendable {
        case weekday, saturday, sunday
    }

    public func kind(of day: Date?) -> DayKind {
        guard let day else { return .weekday }
        switch Calendar.current.component(.weekday, from: day) {
        case 7: return .saturday
        case 1: return .sunday
        default: return .weekday
        }
    }

    /// 画面を開いたとき。予約した番組に印を付けるため、予約も読む
    public func load() async {
        defer { hasLoaded = true }
        try? await remote.loadChannels()
        await guide.loadGuidePrograms()
        search.updateIndex(guide.guidePrograms, loadedAt: guide.guideProgramsLoadedAt)
        try? await recording.loadReservations()
    }
}
