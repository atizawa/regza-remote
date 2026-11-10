import Foundation

/// 画面や Live Activity に出すための視聴状況。
public struct RegzaNowPlaying: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// 地デジ・BS・CS の放送
        case broadcast
        /// 録画番組の再生
        case recorded
        /// HDMI などの外部入力
        case external
        /// 待機中など
        case standby
        /// 旧 API で録画再生中でないとき (放送か外部入力かは分からない)
        case unknown
    }

    public var kind: Kind
    public var channelName: String
    /// 放送中のチャンネルの ID。チャンネル一覧の `RegzaChannel.code` と同じ
    public var channelCode: String
    public var title: String
    public var description: String
    public var chapterName: String
    /// 再生位置・放送開始からの経過 (秒)
    public var position: Int
    /// 番組の長さ (秒)
    public var duration: Int
    /// 再生位置が進んでいるか
    public var isAdvancing: Bool
    /// 放送中の次の番組の開始時刻
    public var nextProgramStart: Date?
    /// 次の番組の長さ (秒)
    public var nextProgramDuration: Int
    /// 次の番組名 (番組表から補えたときだけ)
    public var nextTitle: String
    /// 放送中の番組のジャンル (「ニュース」など)。番組名が返らない機種でも、何の番組かの手がかりになる
    public var genre: String
    /// 狭い場所向けのチャンネルの表記。短くした局名 (`NHK総合` `BSフジ`)、収まらなければ番号 (`4ch` `BS181`)
    public var shortChannel: String
    public var updatedAt: Date

    public init(
        kind: Kind = .unknown, channelName: String = "", channelCode: String = "", title: String = "", description: String = "",
        chapterName: String = "", position: Int = 0, duration: Int = 0, isAdvancing: Bool = false,
        nextProgramStart: Date? = nil, nextProgramDuration: Int = 0, nextTitle: String = "", genre: String = "",
        shortChannel: String = "", updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.channelName = channelName
        self.channelCode = channelCode
        self.title = title
        self.description = description
        self.chapterName = chapterName
        self.position = position
        self.duration = duration
        self.isAdvancing = isAdvancing
        self.nextProgramStart = nextProgramStart
        self.nextProgramDuration = nextProgramDuration
        self.nextTitle = nextTitle
        self.genre = genre
        self.shortChannel = shortChannel
        self.updatedAt = updatedAt
    }

    public var isRecordingPlayback: Bool { kind == .recorded }

    /// 経過時間と進捗バーを出せるか
    public var hasTimeline: Bool { duration > 0 }

    /// 放送中の番組の終了時刻
    public var programEnd: Date? {
        guard kind == .broadcast, duration > 0 else { return nil }
        return updatedAt.addingTimeInterval(TimeInterval(duration - position))
    }

    public var progress: Double {
        duration > 0 ? min(1, Double(position) / Double(duration)) : 0
    }

    // MARK: - 画面に出す文言

    /// 2 行で出すときの上の小さな行。局名や「録画」。なければ nil
    public var captionText: String? {
        switch kind {
        case .broadcast:
            // 番組名が取れないときは局名を大きく出すので、同じ局名は重ねず、ジャンルを添える
            if title.isEmpty { return genre.isEmpty ? nil : genre }
            return channelName.isEmpty ? nil : channelName
        case .recorded:
            return channelName.isEmpty ? "録画" : "録画 · \(channelName)"
        default:
            return nil
        }
    }

    /// 2 行で出すときの下の大きな行。番組名や状態
    public var headlineText: String {
        switch kind {
        case .broadcast:
            if !title.isEmpty { return title }
            return channelName.isEmpty ? "放送" : channelName
        case .recorded: return title
        default: return statusText ?? ""
        }
    }

    /// 番組を映していないときの状態。放送と録画の再生のときは nil
    public var statusText: String? {
        switch kind {
        case .broadcast, .recorded: nil
        case .external: "外部入力"
        case .standby: "待機中"
        case .unknown: "接続済み"
        }
    }

    /// 局名を狭い場所 (Dynamic Island の小さい表示) 向けに短くする。収まりそうになければ nil。
    /// `ＮＨＫ総合１・東京` → `NHK総合`、`ＢＳフジ・１８１` → `BSフジ`、`ＮＨＫＥテレ１東京` → `NHKEテレ`
    public static func shortChannelName(_ name: String) -> String? {
        // 全角の英数字と空白を半角にする (カタカナはそのまま)
        var text = String(
            String.UnicodeScalarView(
                name.unicodeScalars.map { scalar in
                    switch scalar.value {
                    case 0xFF01...0xFF5E: Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
                    case 0x3000: " "
                    default: scalar
                    }
                }))
        let regions = ["東京", "大阪", "名古屋", "札幌", "仙台", "広島", "福岡"]
        // 「・東京」「・181」のように、中黒の後ろが地域名か番号のときだけ取り除く (「ザ・シネマ」は残す)
        if let dot = text.firstIndex(where: { $0 == "・" || $0 == "･" }) {
            let rest = text[text.index(after: dot)...].trimmingCharacters(in: .whitespaces)
            if regions.contains(rest) || (!rest.isEmpty && rest.allSatisfy(\.isNumber)) { text = String(text[..<dot]) }
        }
        text = text.trimmingCharacters(in: .whitespaces)
        // 末尾の地域名 (「Eテレ1東京」の「東京」) を取り除く
        for region in regions where text.hasSuffix(region) {
            text = String(text.dropLast(region.count))
        }
        // 末尾の 1 桁の番号 (「日テレ1」の「1」) を取り除く。「NEWS24」のような 2 桁は名前の一部なので残す
        let chars = Array(text)
        if chars.count >= 2, chars[chars.count - 1].isNumber, !chars[chars.count - 2].isNumber {
            text.removeLast()
        }
        text = text.trimmingCharacters(in: .whitespaces)
        // 幅の目安: 漢字・かなは 2、英数字は 1 として 10 まで
        let width = text.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
        return text.count < 2 || width > 10 ? nil : text
    }

    public static func genreName(code: String) -> String? {
        let digits = Array(code)
        guard digits.count == 4, let level1 = Int(String(digits[2]), radix: 16) else { return nil }
        return ProgramGenre.name(level1)
    }

    /// `[字]` `[新]` などの番組記号を取り除く
    public static func cleanTitle(_ title: String) -> String {
        var result = title
        while let open = result.firstIndex(where: { $0 == "[" || $0 == "［" }),
            let close = result[open...].firstIndex(where: { $0 == "]" || $0 == "］" }),
            result.distance(from: open, to: close) <= 3
        {
            result.removeSubrange(open...close)
        }
        // Mirakurun は番組記号を 🈑 🈖 などの囲み文字にして返す
        result.unicodeScalars.removeAll { (0x1F100...0x1F2FF).contains($0.value) }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
