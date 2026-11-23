import Foundation
public import Observation
public import PresentationCore
package import RegzaDomain
import RegzaStrings

/// 番組表の検索の画面の ViewModel。
/// 打った言葉から日付・時間帯・ジャンルを読み取り (「明日の夜のサッカー」→ 明日・18 時から・サッカー)、
/// 残りの言葉で全部の番組から探す
@MainActor
@Observable
public final class GuideSearchViewModel {
    public let remoteViewModel: RemoteViewModel
    private let guideUseCase: any GuideUseCaseProtocol

    package init(remoteViewModel: RemoteViewModel, guideUseCase: any GuideUseCaseProtocol) {
        self.remoteViewModel = remoteViewModel
        self.guideUseCase = guideUseCase
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
        let now = guideUseCase.clock.now
        return State(
            text: text,
            isBlank: text.trimmingCharacters(in: .whitespaces).isEmpty,
            conditions: conditions.map { ConditionChip(condition: $0, label: label($0)) },
            isLiteral: isLiteral,
            isIndexing: isIndexing,
            results: results.compactMap { result in
                guard remoteViewModel.channels.contains(where: { $0.code.caseInsensitiveCompare(result.channelCode) == .orderedSame })
                else {
                    return nil
                }
                return guideUseCase.searchResult(result, now: now)
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
        let loadedAt = guideUseCase.guideProgramsLoadedAt
        guard loadedAt != indexedAt || results.isEmpty else { return }
        indexedAt = loadedAt
        isIndexing = true
        Task {
            await guideUseCase.updateSearchIndex()
            guard loadedAt == indexedAt else { return }
            isIndexing = false
            refresh()
        }
    }

    package var restorationState: SearchRestorationState {
        SearchRestorationState(text: text, isLiteral: isLiteral, removed: removed)
    }

    package func restore(_ saved: SearchRestorationState) {
        text = saved.text
        isLiteral = saved.isLiteral
        removed = saved.removed
        refresh()
    }

    private func refresh() {
        var query = isLiteral ? ProgramSearchQuery(text: text) : ProgramSearchQuery(parsing: text, now: guideUseCase.clock.now)
        if removed.contains(.day) { query.dayOffset = nil }
        if removed.contains(.hours) {
            query.startHour = nil
            query.endHour = nil
        }
        query.genres.removeAll { removed.contains(.genre($0)) }
        self.query = query
        results = guideUseCase.search(query, channels: remoteViewModel.channels)
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
            case 0: return CoreStrings.dayToday
            case 1: return CoreStrings.dayTomorrow
            case 2: return CoreStrings.dayAfterTomorrow
            case let offset:
                let today = BroadcastDay.start(of: guideUseCase.clock.now)
                let day = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
                return day.formatted(.dateTime.locale(CoreStringTable.locale).month().day().weekday())
            }
        case .hours:
            let start = query.startHour.map(CoreStrings.searchHour) ?? ""
            let end = query.endHour.map(CoreStrings.searchHour) ?? ""
            return CoreStrings.searchHourRange(start, end)
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

    public var introspectionTable: [IntrospectionAction<Action>] {
        [
            IntrospectionAction("setText", "探す言葉を入れる (「明日の夜のドラマ」など)", .string("text", "探す言葉")) { .setText($0) },
            IntrospectionAction("removeCondition", "読み取った条件を外す", .int("index", "conditions の何番目か (0 から)")) { index in
                let conditions = self.state.conditions
                guard conditions.indices.contains(index) else { throw IntrospectionError.invalidArgument("index") }
                return .removeCondition(conditions[index].condition)
            },
            IntrospectionAction("searchLiterally", "条件を読み取らず、打った言葉そのままで探す", .searchLiterally),
        ]
    }
}
