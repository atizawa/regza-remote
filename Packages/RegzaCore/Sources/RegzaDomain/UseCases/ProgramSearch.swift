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

/// 見つかった番組と、見つかったわけ (どの言葉が、どこに入っていたか)
public struct ProgramSearchResult: Sendable, Identifiable {
    public var program: MirakurunProgram
    /// 見つかった言葉 (グループごとに 1 つ)
    public var matches: [Match]

    public var id: Int { program.id }

    public struct Match: Equatable, Sendable {
        public var term: String
        public var field: Field
    }

    /// 言葉が入っていた場所。番組名 → 出演者 → 説明の順に見る
    public enum Field: Sendable {
        case title, cast, description
    }
}

/// 番組を探しやすい形 (正規化した文字の UTF-8) にしたもの。番組表を読み込んだときに 1 度だけ作る。
/// String の contains は 1 万件を超えると打つたびに数百ミリ秒かかるので、バイト列のまま比べる
public struct ProgramSearchIndex: Sendable {
    struct Entry: Sendable {
        var program: MirakurunProgram
        var title: [UInt8]
        var cast: [UInt8]
        var description: [UInt8]
    }

    let entries: [Entry]

    public init(_ programs: [MirakurunProgram]) {
        entries = programs.sorted { $0.start < $1.start }.map { program in
            // 出演者は「出演者」「出演」「声の出演」などの見出しで入っている
            let isCast = { (item: MirakurunProgram.Extended) in item.title.contains("出演") }
            return Entry(
                program: program,
                title: Array(ProgramSearch.normalize(program.name).utf8),
                cast: Array(ProgramSearch.normalize(program.extended.filter(isCast).map(\.text).joined(separator: " ")).utf8),
                description: Array(
                    ProgramSearch.normalize(
                        ([program.description] + program.extended.filter { !isCast($0) }.map(\.text)).joined(separator: " ")
                    ).utf8)
            )
        }
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// 条件に合う、これから放送する番組 (放送中を含む) を時刻順に返す
    public func search(
        _ query: ProgramSearchQuery, now: Date = Date(), calendar: Calendar = .current
    ) -> [ProgramSearchResult] {
        let groups = query.keywordGroups
            .map { group in group.map { ($0, Array(ProgramSearch.normalize($0).utf8)) }.filter { !$0.1.isEmpty } }
            .filter { !$0.isEmpty }
        let today = BroadcastDay.start(of: now, calendar: calendar)
        let day = query.dayOffset.flatMap { calendar.date(byAdding: .day, value: $0, to: today) }
        var results: [ProgramSearchResult] = []
        for entry in entries where entry.program.end > now {
            let program = entry.program
            if !query.genres.isEmpty, !program.genres.contains(where: query.genres.contains) { continue }
            if let day, BroadcastDay.start(of: program.start, calendar: calendar) != day { continue }
            // 時刻の計算は軽くないので、時間帯を聞かれたときだけ行う
            if query.startHour != nil || query.endHour != nil {
                let hour = BroadcastDay.hour(of: program.start, calendar: calendar)
                if let startHour = query.startHour, hour < startHour { continue }
                if let endHour = query.endHour, hour >= endHour { continue }
            }
            var matches: [ProgramSearchResult.Match] = []
            for group in groups {
                guard let match = entry.match(group) else { break }
                matches.append(match)
            }
            guard matches.count == groups.count else { continue }
            results.append(ProgramSearchResult(program: program, matches: matches))
        }
        return results
    }
}

extension ProgramSearchIndex.Entry {
    /// グループの言葉のうち、いちばん目立つ場所 (番組名 → 出演者 → 説明) に入っているもの
    func match(_ group: [(String, [UInt8])]) -> ProgramSearchResult.Match? {
        let fields: [(ProgramSearchResult.Field, [UInt8])] = [(.title, title), (.cast, cast), (.description, description)]
        for (field, text) in fields {
            if let term = group.first(where: { Self.contains(text, $0.1) }) {
                return ProgramSearchResult.Match(term: term.0, field: field)
            }
        }
        return nil
    }

    /// UTF-8 は文字の途中から一致することがないので、バイト列のまま探してよい
    static func contains(_ text: [UInt8], _ word: [UInt8]) -> Bool {
        guard let first = word.first, word.count <= text.count else { return word.isEmpty }
        return text.withUnsafeBufferPointer { text in
            word.withUnsafeBufferPointer { word in
                guard let base = text.baseAddress, let wordBase = word.baseAddress else { return false }
                var offset = 0
                let last = text.count - word.count
                while offset <= last {
                    // 最初のバイトを memchr で探してから、残りを比べる
                    guard let found = memchr(base + offset, Int32(first), last - offset + 1) else { return false }
                    let position = base.distance(to: found.assumingMemoryBound(to: UInt8.self))
                    if memcmp(base + position, wordBase, word.count) == 0 { return true }
                    offset = position + 1
                }
                return false
            }
        }
    }
}

public enum ProgramSearch {
    /// ジャンルの名前 (ARIB の大分類の順)
    public static var genreNames: [String] { ProgramGenre.names }

    /// 全角・半角、ひらがな・カタカナ、大文字・小文字の違いを無視して比べるための形。
    /// NFKC で全角英数を半角に、半角カナを全角にそろえ (ｶﾞ → ガ)、ひらがなはカタカナにする。
    /// applyingTransform (ICU) は 1 万件を超えると数秒かかるので使わない
    static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCompatibilityMapping.lowercased().unicodeScalars {
            if scalar.properties.isWhitespace { continue }
            // ぁ〜ゖ・ゝゞ は、同じ並びのカタカナ (0x60 後ろ) にする
            if (0x3041...0x3096).contains(scalar.value) || (0x309D...0x309E).contains(scalar.value),
                let katakana = Unicode.Scalar(scalar.value + 0x60)
            {
                scalars.append(katakana)
            } else {
                scalars.append(scalar)
            }
        }
        // 半角の濁点は NFKC でも「ス + ゛」と分かれたままなので、最後に NFC で「ズ」にまとめる
        // (バイト列で比べるので、同じ文字は同じバイト列にしておく)
        return String(scalars).precomposedStringWithCanonicalMapping
    }
}

extension ProgramSearchQuery {
    /// 打った言葉から日付・時間帯・ジャンルの言葉を読み取って条件にし、残りを探す言葉にする。
    /// 「明日の夜のサッカー」→ 明日・18〜28 時・「サッカー」。
    /// 言葉の途中は読まない (「朝ドラ」「大河ドラマ」はそのまま探す言葉にする)
    public init(parsing text: String, now: Date = Date(), calendar: Calendar = .current) {
        self.init()
        let today = BroadcastDay.start(of: now, calendar: calendar)
        let digits = String(
            text.map { character -> Character in
                // 全角の数字は半角にする (ほかの文字は打ったままにする)
                guard let value = character.unicodeScalars.first?.value, (0xFF10...0xFF19).contains(value),
                    let scalar = Unicode.Scalar(value - 0xFF10 + 0x30)
                else { return character }
                return Character(scalar)
            })
        for chunk in digits.split(whereSeparator: \.isWhitespace) {
            var rest = Substring(chunk)
            while let (condition, length) = Self.condition(at: rest) {
                let particles = Self.particles(after: rest.dropFirst(length))
                guard particles.isBoundary else { break }
                apply(condition, particle: particles.first, today: today, calendar: calendar)
                rest = rest.dropFirst(length + particles.length)
            }
            if !rest.isEmpty, !Self.ignoredWords.contains(String(rest)) {
                keywordGroups.append([String(rest)])
            }
        }
    }

    enum Condition {
        case day(Int)
        case weekday(Int)
        case date(month: Int, day: Int)
        case hours(Int, Int)
        case hour(Int)
        case genre(Int)
        /// 今夜 (今日の夜)
        case tonight
    }

    /// 条件として読む言葉 (長いものを先に見る)
    static let conditionWords: [(String, Condition)] = {
        var words: [(String, Condition)] = [
            ("今日", .day(0)), ("きょう", .day(0)), ("明日", .day(1)), ("あした", .day(1)), ("あす", .day(1)),
            ("明後日", .day(2)), ("あさって", .day(2)), ("今夜", .tonight), ("今晩", .tonight),
            ("朝", .hours(5, 10)), ("午前", .hours(4, 12)), ("昼", .hours(11, 14)), ("午後", .hours(12, 18)),
            ("夕方", .hours(16, 19)), ("夜", .hours(18, 28)), ("ゴールデンタイム", .hours(19, 22)), ("ゴールデン", .hours(19, 22)),
            ("プライムタイム", .hours(19, 23)), ("プライム", .hours(19, 23)), ("深夜", .hours(23, 28)),
            ("ドキュメント", .genre(8)), ("舞台", .genre(9)), ("演劇", .genre(9)), ("教育", .genre(10)), ("特撮", .genre(7)),
        ]
        for (index, name) in ["日", "月", "火", "水", "木", "金", "土"].enumerated() {
            words += [("\(name)曜日", .weekday(index + 1)), ("\(name)曜", .weekday(index + 1))]
        }
        words += ProgramSearch.genreNames.enumerated().map { ($0.element, .genre($0.offset)) }
        return words.sorted { $0.0.count > $1.0.count }
    }()

    /// 条件の言葉のあとに続く言葉 (「明日の」「21時から」)
    static let particleWords = ["から", "まで", "以降", "以前", "台", "の", "に", "で", "は", "や", "と"]

    /// 条件を読んだあとに残っても、探す言葉にしないもの (「明日の番組」)
    static let ignoredWords: Set<String> = ["番組", "放送", "やつ"]

    static func condition(at text: Substring) -> (Condition, Int)? {
        // 「21時」「11/7」「11月7日」
        if let match = text.prefixMatch(of: /(\d{1,2})時(半)?/), let hour = Int(match.1), hour <= 28 {
            return (.hour(hour < BroadcastDay.startHour ? hour + 24 : hour), match.0.count)
        }
        if let match = text.prefixMatch(of: /(\d{1,2})(?:\/|月)(\d{1,2})日?/), let month = Int(match.1),
            let day = Int(match.2), (1...12).contains(month), (1...31).contains(day)
        {
            return (.date(month: month, day: day), match.0.count)
        }
        return conditionWords.first { text.hasPrefix($0.0) }.map { ($0.1, $0.0.count) }
    }

    /// 続く助詞などを読む。言葉の途中 (「朝ドラ」の「朝」) なら isBoundary が false
    static func particles(after text: Substring) -> (first: String?, length: Int, isBoundary: Bool) {
        var rest = text
        var first: String?
        var length = 0
        while let particle = particleWords.first(where: { rest.hasPrefix($0) }) {
            first = first ?? particle
            length += particle.count
            rest = rest.dropFirst(particle.count)
        }
        let isBoundary = rest.isEmpty || length > 0 || condition(at: rest) != nil
        return (first, length, isBoundary)
    }

    mutating func apply(_ condition: Condition, particle: String?, today: Date, calendar: Calendar) {
        switch condition {
        case .day(let offset):
            dayOffset = offset
        case .tonight:
            dayOffset = 0
            startHour = 18
            endHour = 28
        case .weekday(let weekday):
            dayOffset = (weekday - calendar.component(.weekday, from: today) + 7) % 7
        case .date(let month, let day):
            var components = calendar.dateComponents([.year], from: today)
            components.month = month
            components.day = day
            guard var date = calendar.date(from: components) else { return }
            if date < calendar.startOfDay(for: today) {
                date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
            }
            dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: date).day
        case .hours(let start, let end):
            startHour = start
            endHour = end
        case .hour(let hour):
            switch particle {
            case "から", "以降":
                startHour = hour
                endHour = nil
            case "まで", "以前": endHour = hour
            default:
                startHour = hour
                endHour = hour + 1
            }
        case .genre(let genre):
            if !genres.contains(genre) { genres.append(genre) }
        }
    }
}
