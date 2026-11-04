#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 番組表の検索。打った言葉から日付・時間帯・ジャンルを読み取り (「明日の夜のサッカー」→ 明日・18 時から・サッカー)、
/// 残りの言葉で全部の番組から探す
@MainActor @Observable
final class GuideSearch {
    var text = "" {
        didSet {
            guard text != oldValue else { return }
            // 打ち直したら、外した条件も戻して読み直す
            removed = []
            isLiteral = false
            refresh()
        }
    }
    /// 読み取った条件 (外したものを除く)
    private(set) var query = ProgramSearchQuery()
    private(set) var results: [ProgramSearchResult] = []
    /// 条件を読み取らず、打った言葉そのままで探すか (「夜のニュース」という番組名を探すときなど)
    private(set) var isLiteral = false
    private var removed: Set<Condition> = []

    private var index = ProgramSearchIndex([])
    private var indexedAt: Date?

    /// 番組表を読み込み直したときに、探すための索引を作り直す (正規化に時間がかかるので裏で行う)
    func updateIndex(_ programs: [String: [MirakurunProgram]], loadedAt: Date?) async {
        guard loadedAt != indexedAt || index.isEmpty else { return }
        indexedAt = loadedAt
        let all = programs.values.flatMap { $0 }
        index = await Task.detached { ProgramSearchIndex(all) }.value
        refresh()
    }

    /// 読み取った条件から 1 つ外す
    func remove(_ condition: Condition) {
        removed.insert(condition)
        refresh()
    }

    /// 条件を読み取らず、打った言葉そのままで探す
    func searchLiterally() {
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
    enum Condition: Hashable {
        case day, hours, genre(Int)
    }

    var conditions: [Condition] {
        var conditions: [Condition] = []
        if query.dayOffset != nil { conditions.append(.day) }
        if query.startHour != nil || query.endHour != nil { conditions.append(.hours) }
        return conditions + query.genres.map(Condition.genre)
    }

    func label(_ condition: Condition) -> String {
        switch condition {
        case .day:
            switch query.dayOffset ?? 0 {
            case 0: return "今日"
            case 1: return "明日"
            case 2: return "あさって"
            case let offset:
                let today = ProgramSearch.broadcastDayStart(of: Date())
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

/// 番組を探す画面。番組表のナビゲーションバーの虫眼鏡から開く
struct GuideSearchScreen: View {
    @Bindable var search: GuideSearch
    let onSelect: (MirakurunProgram, RegzaChannel) -> Void
    @State private var isPresented = false

    var body: some View {
        GuideSearchResults(search: search, onSelect: onSelect)
            .navigationTitle("番組を探す")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $search.text, isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .always), prompt: "番組名・出演者・「明日の夜のドラマ」"
            )
            // 開いたらすぐ打てるようにする (前に探した言葉が残っていれば結果を見せる)
            .onAppear { if search.text.isEmpty { isPresented = true } }
    }
}

/// 検索の結果。時刻順に並べ、なぜ見つかったか (「〇〇 が出演」など) を添える
struct GuideSearchResults: View {
    @Environment(RemoteViewModel.self) private var model
    let search: GuideSearch
    let onSelect: (MirakurunProgram, RegzaChannel) -> Void

    var body: some View {
        List {
            if !search.conditions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ConditionChips(search: search)
                        Button("「\(search.text)」をそのまま探す") { search.searchLiterally() }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            section(search.results)
        }
        .listStyle(.plain)
        .overlay {
            if search.text.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView {
                    Label("番組を探す", systemImage: "magnifyingglass")
                } description: {
                    Text("1 週間分の番組から、番組名・出演者・説明で探します。\n「明日の夜のドラマ」「土曜 21時から」のように、日付・時間帯・ジャンルでも絞り込めます。")
                }
            } else if search.results.isEmpty {
                ContentUnavailableView.search(text: search.text)
            }
        }
    }

    @ViewBuilder
    private func section(_ results: [ProgramSearchResult]) -> some View {
        if !results.isEmpty {
            Section {
                ForEach(results) { result in
                    if let channel = channel(for: result.program) {
                        Button {
                            onSelect(result.program, channel)
                        } label: {
                            SearchResultRow(result: result, channel: channel)
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    private func channel(for program: MirakurunProgram) -> RegzaChannel? {
        model.channels.first { $0.code.caseInsensitiveCompare(program.channelCode) == .orderedSame }
    }
}

/// 読み取った条件。× で外せる
private struct ConditionChips: View {
    let search: GuideSearch

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("読み取った条件")
                ForEach(search.conditions, id: \.self) { condition in
                    Button {
                        search.remove(condition)
                    } label: {
                        HStack(spacing: 4) {
                            Text(search.label(condition))
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Surface.button, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(search.label(condition)) を外す")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct SearchResultRow: View {
    @Environment(RemoteViewModel.self) private var model
    let result: ProgramSearchResult
    let channel: RegzaChannel

    var body: some View {
        let program = result.program
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(program.isOnAir() ? AppTheme.accent : .secondary)
                Text(channel.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if model.isReserved(program) {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("録画予約済み")
                }
            }
            Text(program.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            if let reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    /// 「11/5(木) 21:00〜」。放送中は「放送中」
    private var timeText: String {
        if result.program.isOnAir() { return "放送中 〜\(result.program.end.formatted(.dateTime.hour().minute()))" }
        let day = result.program.start.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.defaultDigits).day().weekday())
        return "\(day) \(result.program.start.formatted(.dateTime.hour().minute()))〜"
    }

    /// 番組名に入っていれば言うまでもないので、出演者と説明のときだけ添える
    private var reason: String? {
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
#endif
