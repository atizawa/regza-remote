import Foundation

/// 番組表 (Mirakurun) を探す条件。
/// 打った言葉をそのまま使うときは言葉ごとのグループ (すべて含む)、AI が言葉を広げたときは
/// 関係する言葉を 1 つのグループ (どれかを含む) にし、ジャンル・日付・時間帯も入る
public struct ProgramSearchQuery: Equatable, Sendable {
    /// グループごとに、どれかの言葉を含む番組を探す。すべてのグループを満たすものだけ残す
    /// (番組名・説明・番組内容・出演者から探す)
    public var keywordGroups: [[String]]
    /// ARIB の大分類 (0: ニュース 〜 11: 福祉)。空ならジャンルを問わない
    public var genres: [Int]
    /// 今日を 0 とした日。nil なら日を問わない (番組表の 1 日は朝 4 時から)
    public var dayOffset: Int?
    /// この時刻から始まる番組 (4〜27 時。深夜は前の日の続きとして 24 時以降で書く)。nil なら問わない
    public var startHour: Int?
    /// この時刻より前に始まる番組
    public var endHour: Int?

    public init(
        keywordGroups: [[String]] = [], genres: [Int] = [], dayOffset: Int? = nil,
        startHour: Int? = nil, endHour: Int? = nil
    ) {
        self.keywordGroups = keywordGroups
        self.genres = genres
        self.dayOffset = dayOffset
        self.startHour = startHour
        self.endHour = endHour
    }

    /// 打った言葉を空白で区切り、すべて含む番組を探す条件
    public init(text: String) {
        self.init(keywordGroups: text.split(whereSeparator: \.isWhitespace).map { [String($0)] })
    }

    public var isEmpty: Bool {
        keywordGroups.allSatisfy(\.isEmpty) && genres.isEmpty && dayOffset == nil && startHour == nil && endHour == nil
    }
}
