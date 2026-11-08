import Foundation
import Observation

/// 番組表の検索の画面の ViewModel (iOS と Android で共有)。
/// 打った言葉から日付・時間帯・ジャンルを読み取り (「明日の夜のサッカー」→ 明日・18 時から・サッカー)、
/// 残りの言葉で全部の番組から探す
@MainActor
@Observable
public final class GuideSearchViewModel {
    public let remote: RemoteViewModel
    public let guide: any GuideUseCaseProtocol

    public init(remote: RemoteViewModel, guide: any GuideUseCaseProtocol) {
        self.remote = remote
        self.guide = guide
    }

    /// 画面に出す、読み取った条件
    public enum Condition: Hashable, Sendable {
        case day, hours, genre(Int)
    }

    public struct State: Equatable, Sendable {
        public var text: String
        /// 何も打っていない
        public var isBlank: Bool
        /// 読み取った条件 (外したものを除く)
        public var conditions: [ConditionChip]
        /// 条件を読み取らず、打った言葉そのままで探しているか (「夜のニュース」という番組名を探すときなど)
        public var isLiteral: Bool
        /// 索引を作っている途中か (その間は結果が空でも「見つかりません」と出さない)
        public var isIndexing: Bool
        /// 見つかった番組 (テレビに登録されていない局の番組は出さない)
        public var results: [SearchResultItem]
    }

    public struct ConditionChip: Equatable, Sendable, Identifiable {
        public var condition: Condition
        /// 「明日」「18時〜」「スポーツ」
        public var label: String
        public var id: Condition { condition }
    }

    public enum Action: Sendable {
        case setText(String)
        /// 読み取った条件から 1 つ外す
        case removeCondition(Condition)
        /// 条件を読み取らず、打った言葉そのままで探す
        case searchLiterally
    }

    private var text = ""
    private var query = ProgramSearchQuery()
    private var results: [ProgramSearchResult] = []
    private var isLiteral = false
    private var isIndexing = false
    @ObservationIgnored private var removed: Set<Condition> = []
    @ObservationIgnored private var index = ProgramSearchIndex([])
    @ObservationIgnored private var indexedAt: Date?

    public var state: State {
        let now = Date()
        let channels = remote.state.channels
        return State(
            text: text,
            isBlank: text.trimmingCharacters(in: .whitespaces).isEmpty,
            conditions: conditions.map { ConditionChip(condition: $0, label: label($0)) },
            isLiteral: isLiteral,
            isIndexing: isIndexing,
            results: results.compactMap { result in
                guard let channel = channels.first(where: { $0.code.caseInsensitiveCompare(result.program.channelCode) == .orderedSame })
                else { return nil }
                return guide.searchResult(result, channel: channel, now: now)
            }
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .setText(let newText):
            guard newText != text else { return }
            text = newText
            // 打ち直したら、外した条件も戻して読み直す
            removed = []
            isLiteral = false
            refresh()
        case .removeCondition(let condition):
            removed.insert(condition)
            refresh()
        case .searchLiterally:
            isLiteral = true
            refresh()
        }
    }

    /// 番組表を読み込み直したときに、探すための索引を作り直す (番組表の画面から呼ぶ)。
    /// 1 週間分で 1 秒ほどかかるので、番組表の表示を待たせないよう裏で作る
    func updateIndex(_ programs: [String: [MirakurunProgram]], loadedAt: Date?) {
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

    private func refresh() {
        var query = isLiteral ? ProgramSearchQuery(text: text) : ProgramSearchQuery(parsing: text)
        if removed.contains(.day) { query.dayOffset = nil }
        if removed.contains(.hours) { query.startHour = nil; query.endHour = nil }
        query.genres.removeAll { removed.contains(.genre($0)) }
        self.query = query
        results = query.isEmpty ? [] : index.search(query)
    }

    private var conditions: [Condition] {
        var conditions: [Condition] = []
        if query.dayOffset != nil { conditions.append(.day) }
        if query.startHour != nil || query.endHour != nil { conditions.append(.hours) }
        return conditions + query.genres.map(Condition.genre)
    }

    private func label(_ condition: Condition) -> String {
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
}

extension GuideSearchViewModel: Introspectable {
    public var introspectionName: String { "search" }

    /// 結果は多くなることがあるので、番組の id・名前・局・時刻・理由だけを見せる
    public var introspectionValue: Any {
        let state = state
        return JSONValue.object([
            "text": .string(state.text),
            "isLiteral": .bool(state.isLiteral),
            "isIndexing": .bool(state.isIndexing),
            "conditions": .array(state.conditions.map { .string($0.label) }),
            "results": .array(state.results.prefix(50).map { row in
                .object([
                    "program": .number(Double(row.program.id)),
                    "name": .string(row.program.name),
                    "channel": .string(row.channelCode),
                    "time": .string(row.timeText),
                    "reason": row.reason.map(JSONValue.string) ?? .null,
                    "isReserved": .bool(row.program.isReserved),
                ])
            }),
            "resultCount": .number(Double(state.results.count)),
        ])
    }

    public var isBusy: Bool { isIndexing }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("setText", "探す言葉を入れる (「明日の夜のドラマ」など)", parameters: ["text": "探す言葉"]),
            ActionDescription("removeCondition", "読み取った条件を外す", parameters: ["index": "conditions の何番目か (0 から)"]),
            ActionDescription("searchLiterally", "条件を読み取らず、打った言葉そのままで探す"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "setText": send(.setText(try arguments.string("text")))
        case "removeCondition":
            let index = try arguments.int("index")
            let conditions = state.conditions
            guard conditions.indices.contains(index) else { throw IntrospectionError.invalidArgument("index") }
            send(.removeCondition(conditions[index].condition))
        case "searchLiterally": send(.searchLiterally)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
