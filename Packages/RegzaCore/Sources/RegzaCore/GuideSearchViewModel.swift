import Foundation
import Observation

/// 番組表の検索の画面の ViewModel (iOS と Android で共有)。
/// 打った言葉から日付・時間帯・ジャンルを読み取り (「明日の夜のサッカー」→ 明日・18 時から・サッカー)、
/// 残りの言葉で全部の番組から探す
@MainActor
@Observable
public final class GuideSearchViewModel {
    public let remote: RemoteViewModel
    public let recording: ReservationsViewModel

    public init(remote: RemoteViewModel, recording: ReservationsViewModel) {
        self.remote = remote
        self.recording = recording
    }

    public var text = "" {
        didSet {
            guard text != oldValue else { return }
            // 打ち直したら、外した条件も戻して読み直す
            removed = []
            isLiteral = false
            refresh()
        }
    }
    /// 読み取った条件 (外したものを除く)
    public private(set) var query = ProgramSearchQuery()
    public private(set) var results: [ProgramSearchResult] = []
    /// 条件を読み取らず、打った言葉そのままで探すか (「夜のニュース」という番組名を探すときなど)
    public private(set) var isLiteral = false
    /// 索引を作っている途中か (その間は結果が空でも「見つかりません」と出さない)
    public private(set) var isIndexing = false
    private var removed: Set<Condition> = []

    @ObservationIgnored private var index = ProgramSearchIndex([])
    @ObservationIgnored private var indexedAt: Date?

    /// 何も打っていない
    public var isBlank: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 番組表を読み込み直したときに、探すための索引を作り直す。
    /// 1 週間分で 1 秒ほどかかるので、番組表の表示を待たせないよう裏で作る
    public func updateIndex(_ programs: [String: [MirakurunProgram]], loadedAt: Date?) {
        guard loadedAt != indexedAt || index.isEmpty else { return }
        indexedAt = loadedAt
        let all = programs.values.flatMap { $0 }
        isIndexing = true
        Task {
            let index = await Task.detached { ProgramSearchIndex(all) }.value
            // 作っている間に番組表を読み込み直していたら、古い索引は使わない
            guard loadedAt == indexedAt else { return }
            self.index = index
            isIndexing = false
            refresh()
        }
    }

    /// 読み取った条件から 1 つ外す
    public func remove(_ condition: Condition) {
        removed.insert(condition)
        refresh()
    }

    /// 条件を読み取らず、打った言葉そのままで探す
    public func searchLiterally() {
        isLiteral = true
        refresh()
    }

    private func refresh() {
        var query = isLiteral ? ProgramSearchQuery(text: text) : ProgramSearchQuery(parsing: text)
        if removed.contains(.day) { query.dayOffset = nil }
        if removed.contains(.hours) { query.startHour = nil; query.endHour = nil }
        query.genres.removeAll { removed.contains(.genre($0)) }
        self.query = query
        results = query.isEmpty ? [] : index.search(query)
    }

    /// 画面に出す、読み取った条件
    public enum Condition: Hashable, Sendable {
        case day, hours, genre(Int)
    }

    public var conditions: [Condition] {
        var conditions: [Condition] = []
        if query.dayOffset != nil { conditions.append(.day) }
        if query.startHour != nil || query.endHour != nil { conditions.append(.hours) }
        return conditions + query.genres.map(Condition.genre)
    }

    public func label(_ condition: Condition) -> String {
        switch condition {
        case .day:
            switch query.dayOffset ?? 0 {
            case 0: return "今日"
            case 1: return "明日"
            case 2: return "あさって"
            case let offset:
                let today = BroadcastDay.start(of: Date())
                let day = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
                return day.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().weekday())
            }
        case .hours:
            let start = query.startHour.map { "\($0)時" } ?? ""
            let end = query.endHour.map { "\($0)時" } ?? ""
            return "\(start)〜\(end)"
        case .genre(let genre):
            return ProgramSearch.genreNames.indices.contains(genre) ? ProgramSearch.genreNames[genre] : ""
        }
    }

    // MARK: - 結果の行

    /// 番組の局。テレビに登録されていない局の番組は出さない
    public func channel(for program: MirakurunProgram) -> RegzaChannel? {
        remote.channels.first { $0.code.caseInsensitiveCompare(program.channelCode) == .orderedSame }
    }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        recording.isReserved(program)
    }

    /// 「11/5(木) 21:00〜」。放送中は「放送中 〜21:54」
    public func timeText(of program: MirakurunProgram, now: Date = Date()) -> String {
        if program.isOnAir(at: now) { return "放送中 〜\(program.end.formatted(.dateTime.hour().minute()))" }
        let day = program.start.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.defaultDigits).day().weekday())
        return "\(day) \(program.start.formatted(.dateTime.hour().minute()))〜"
    }

    /// なぜ見つかったか。番組名に入っていれば言うまでもないので、出演者と説明のときだけ添える
    public func reason(for result: ProgramSearchResult) -> String? {
        let reasons = result.matches.compactMap { match -> String? in
            switch match.field {
            case .title: nil
            case .cast: "\(match.term) が出演"
            case .description: "説明に「\(match.term)」"
            }
        }
        return reasons.isEmpty ? nil : reasons.joined(separator: "・")
    }
}
