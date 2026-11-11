import Foundation

/// 番組 (UI で使う形)。GuideUseCase が Domain の ProgramData から作る
public struct ProgramItem: Equatable, Sendable, Identifiable {
    public var id: Int
    /// 放送しているチャンネルの ID (`JP-G…`)
    public var channelCode: String
    public var name: String
    public var description: String
    public var start: Date
    public var end: Date
    /// 「13:00」
    public var startText: String
    /// 「11月7日(土) 13:00 〜 13:45 · 45分」
    public var timeText: String
    /// ジャンルの名前 (「ドラマ」など)
    public var genreName: String?
    /// ARIB のジャンルの大分類 (0〜15)。番組表で色を分ける。なければ -1
    public var genre: Int
    /// 作ったときに放送中だった
    public var isOnAir: Bool
    /// 録画予約している
    public var isReserved: Bool

    public func isOnAir(at date: Date) -> Bool { start <= date && date < end }

    public init(
        id: Int, channelCode: String, name: String, description: String, start: Date, end: Date,
        startText: String, timeText: String, genreName: String?, genre: Int, isOnAir: Bool, isReserved: Bool
    ) {
        self.id = id
        self.channelCode = channelCode
        self.name = name
        self.description = description
        self.start = start
        self.end = end
        self.startText = startText
        self.timeText = timeText
        self.genreName = genreName
        self.genre = genre
        self.isOnAir = isOnAir
        self.isReserved = isReserved
    }
}
