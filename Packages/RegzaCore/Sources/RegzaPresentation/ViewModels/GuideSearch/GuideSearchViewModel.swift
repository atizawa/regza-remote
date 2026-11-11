public import Foundation
public import Observation
package import RegzaDomain

/// 番組表の検索の画面の ViewModel。
/// 打った言葉から日付・時間帯・ジャンルを読み取り (「明日の夜のサッカー」→ 明日・18 時から・サッカー)、
/// 残りの言葉で全部の番組から探す
@MainActor
@Observable
public final class GuideSearchViewModel {
    public let remote: RemoteViewModel
    package let guide: any GuideUseCaseProtocol

    package init(remote: RemoteViewModel, guide: any GuideUseCaseProtocol) {
        self.remote = remote
        self.guide = guide
    }

    /// 画面に出す、読み取った条件
    public typealias Condition = GuideSearchCondition

    /// 画面に出すもの
    public typealias State = GuideSearchState

    /// 読み取った条件と、画面に出す名前
    public typealias ConditionChip = GuideSearchConditionChip

    /// 画面からの操作
    public typealias Action = GuideSearchAction

    private var text = ""
    private var query = ProgramSearchQuery()
    private var results: [SearchResultItem] = []
    private var isLiteral = false
    private var isIndexing = false
    @ObservationIgnored private var removed: Set<Condition> = []
    @ObservationIgnored private var indexedAt: Date?

    public var state: State {
        let now = Date()
        return State(
            text: text,
            isBlank: text.trimmingCharacters(in: .whitespaces).isEmpty,
            conditions: conditions.map { ConditionChip(condition: $0, label: label($0)) },
            isLiteral: isLiteral,
            isIndexing: isIndexing,
            results: results.compactMap { result in
                guard remote.channels.contains(where: { $0.code.caseInsensitiveCompare(result.channelCode) == .orderedSame }) else {
                    return nil
                }
                return guide.searchResult(result, now: now)
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
    func updateIndex() {
        let loadedAt = guide.guideProgramsLoadedAt
        guard loadedAt != indexedAt || results.isEmpty else { return }
        indexedAt = loadedAt
        isIndexing = true
        Task {
            await guide.updateSearchIndex()
            guard loadedAt == indexedAt else { return }
            isIndexing = false
            refresh()
        }
    }

    private func refresh() {
        var query = isLiteral ? ProgramSearchQuery(text: text) : ProgramSearchQuery(parsing: text)
        if removed.contains(.day) { query.dayOffset = nil }
        if removed.contains(.hours) {
            query.startHour = nil
            query.endHour = nil
        }
        query.genres.removeAll { removed.contains(.genre($0)) }
        self.query = query
        results = guide.search(query, channels: remote.channels)
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

extension GuideSearchViewModel: IntrospectableActions {
    public var introspectionName: String { "search" }

    /// 結果は多くなることがあるので、番組の id・名前・局・時刻・理由だけを見せる
    nonisolated public static func introspectionJSON(of state: State) -> JSONValue {
        return JSONValue.object([
            "text": .string(state.text),
            "isLiteral": .bool(state.isLiteral),
            "isIndexing": .bool(state.isIndexing),
            "conditions": .array(state.conditions.map { .string($0.label) }),
            "results": .array(
                state.results.prefix(50).map { row in
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

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "setText": return .setText(try arguments.string("text"))
        case "removeCondition":
            let index = try arguments.int("index")
            let conditions = state.conditions
            guard conditions.indices.contains(index) else { throw IntrospectionError.invalidArgument("index") }
            return .removeCondition(conditions[index].condition)
        case "searchLiterally": return .searchLiterally
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
