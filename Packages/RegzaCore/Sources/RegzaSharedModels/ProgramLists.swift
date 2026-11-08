import Foundation

/// 番組の詳細の見出しつきの説明 (「番組内容」「出演者」など)
public struct ProgramTextItem: Equatable, Sendable, Identifiable {
    public var title: String
    public var text: String
    public var id: String { title }

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

/// 1 チャンネルの番組表の 1 日分
public struct ProgramDay: Equatable, Sendable, Identifiable {
    /// その日の始まり
    public var date: Date
    /// 「11月7日(土)」
    public var label: String
    public var programs: [ProgramItem]
    public var id: Date { date }

    public init(date: Date, label: String, programs: [ProgramItem]) {
        self.date = date
        self.label = label
        self.programs = programs
    }
}

/// 新聞のテレビ欄のような番組表の 1 局分
public struct GuideColumn: Equatable, Sendable, Identifiable {
    public var channelCode: String
    public var channelName: String
    public var programs: [ProgramItem]
    public var id: String { channelCode }

    public init(channelCode: String, channelName: String, programs: [ProgramItem]) {
        self.channelCode = channelCode
        self.channelName = channelName
        self.programs = programs
    }
}

/// 番組表の日付の選択肢
public struct GuideDay: Equatable, Sendable, Identifiable {
    /// その日の朝 4 時。今日 (今の時刻から 24 時間) なら nil
    public var date: Date?
    /// 「今日」「明日」「9(月)」
    public var label: String
    /// 土曜は青、日曜は赤で出す (テレビ欄と同じ)
    public var kind: GuideDayKind
    public var id: Date { date ?? .distantPast }

    public init(date: Date?, label: String, kind: GuideDayKind) {
        self.date = date
        self.label = label
        self.kind = kind
    }
}

public enum GuideDayKind: String, Sendable {
    case weekday, saturday, sunday
}

/// 番組表の検索で見つかった番組
public struct SearchResultItem: Equatable, Sendable, Identifiable {
    public var program: ProgramItem
    public var channelCode: String
    public var channelName: String
    /// 「11/5(木) 21:00〜」。放送中は「放送中 〜21:54」
    public var timeText: String
    /// なぜ見つかったか (「〇〇 が出演」など)。番組名に入っていたときは nil
    public var reason: String?
    public var id: Int { program.id }

    public init(program: ProgramItem, channelCode: String, channelName: String, timeText: String, reason: String?) {
        self.program = program
        self.channelCode = channelCode
        self.channelName = channelName
        self.timeText = timeText
        self.reason = reason
    }
}
