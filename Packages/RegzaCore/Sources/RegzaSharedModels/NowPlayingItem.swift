import Foundation

/// テレビにいま映っているもの (UI で使う形)。TVUseCase が Domain の RegzaNowPlaying から作る
public struct NowPlayingItem: Equatable, Sendable {
    public var kind: NowPlayingKind
    public var channelName: String
    /// 放送のチャンネルの ID (`JP-G…`)。放送でなければ空
    public var channelCode: String
    public var title: String
    public var description: String
    /// 録画の再生中のチャプター名
    public var chapterName: String
    /// ジャンルの名前
    public var genre: String
    /// 再生位置と長さ (秒)
    public var position: Int
    public var duration: Int
    /// 再生が進んでいる (一時停止していない)
    public var isAdvancing: Bool
    /// テレビから取った時刻 (ここから再生位置を進めて出す)
    public var updatedAt: Date
    /// 放送中の次の番組の開始時刻・長さ (秒)・番組名。番組表から補えたときだけ (ロック画面などで、番組が終わったら次の番組に切り替えて出す)
    public var nextProgramStart: Date?
    public var nextProgramDuration: Int
    public var nextTitle: String
    /// 狭い場所向けのチャンネルの表記。短くした局名 (`NHK総合`)、収まらなければ番号 (`4ch` `BS181`)
    public var shortChannel: String
    /// 2 行で出すときの上の小さな行 (局名や「録画」)。なければ nil
    public var captionText: String?
    /// 2 行で出すときの下の大きな行 (番組名や状態)
    public var headlineText: String
    /// 番組を映していないときの状態 (「待機中」など)。放送と録画の再生のときは nil
    public var statusText: String?

    public init(
        kind: NowPlayingKind, channelName: String, channelCode: String, title: String, description: String,
        chapterName: String, genre: String, position: Int, duration: Int, isAdvancing: Bool, updatedAt: Date,
        nextProgramStart: Date?, nextProgramDuration: Int, nextTitle: String, shortChannel: String,
        captionText: String?, headlineText: String, statusText: String?
    ) {
        self.kind = kind
        self.channelName = channelName
        self.channelCode = channelCode
        self.title = title
        self.description = description
        self.chapterName = chapterName
        self.genre = genre
        self.position = position
        self.duration = duration
        self.isAdvancing = isAdvancing
        self.updatedAt = updatedAt
        self.nextProgramStart = nextProgramStart
        self.nextProgramDuration = nextProgramDuration
        self.nextTitle = nextTitle
        self.shortChannel = shortChannel
        self.captionText = captionText
        self.headlineText = headlineText
        self.statusText = statusText
    }

    /// 経過時間と進捗バーを出せるか
    public var hasTimeline: Bool { duration > 0 }

    public var progress: Double {
        duration > 0 ? min(1, Double(position) / Double(duration)) : 0
    }

    /// 再生位置や長さ (秒) の表記。1 時間を超えれば「1:02:03」、超えなければ「12:34」
    public static func durationText(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = seconds % 3600 / 60, rest = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}

/// いま映っているものの種類
public enum NowPlayingKind: String, Sendable {
    /// 地デジ・BS・CS の放送
    case broadcast
    /// 録画番組の再生
    case recorded
    /// HDMI などの外部入力
    case external
    /// 待機中など
    case standby
    /// 放送か外部入力かは分からない
    case unknown
}
