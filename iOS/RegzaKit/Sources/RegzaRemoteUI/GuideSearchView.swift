#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 番組を探す画面。番組表のナビゲーションバーの虫眼鏡から開く
struct GuideSearchScreen: View {
    let search: GuideSearchViewModel
    let onSelect: (MirakurunProgram, RegzaChannel) -> Void
    @State private var isPresented = false

    var body: some View {
        GuideSearchResults(search: search, onSelect: onSelect)
            .navigationTitle("番組を探す")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(get: { search.state.text }, set: { search.send(.setText($0)) }), isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .always), prompt: "番組名・出演者・「明日の夜のドラマ」"
            )
            // 開いたらすぐ打てるようにする (前に探した言葉が残っていれば結果を見せる)
            .onAppear { if search.state.text.isEmpty { isPresented = true } }
    }
}

/// 検索の結果。時刻順に並べ、なぜ見つかったか (「〇〇 が出演」など) を添える
struct GuideSearchResults: View {
    let search: GuideSearchViewModel
    let onSelect: (MirakurunProgram, RegzaChannel) -> Void

    var body: some View {
        let state = search.state
        List {
            if !state.conditions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ConditionChips(conditions: state.conditions) { search.send(.removeCondition($0)) }
                        Button("「\(state.text)」をそのまま探す") { search.send(.searchLiterally) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            section(state.results)
        }
        .listStyle(.plain)
        .overlay {
            if state.isBlank {
                ContentUnavailableView {
                    Label("番組を探す", systemImage: "magnifyingglass")
                } description: {
                    Text("1 週間分の番組から、番組名・出演者・説明で探します。\n「明日の夜のドラマ」「土曜 21時から」のように、日付・時間帯・ジャンルでも絞り込めます。")
                }
            } else if state.results.isEmpty, state.isIndexing {
                ProgressView("番組を読み込んでいます")
            } else if state.results.isEmpty {
                ContentUnavailableView.search(text: state.text)
            }
        }
    }

    @ViewBuilder
    private func section(_ rows: [GuideSearchViewModel.Row]) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    Button {
                        onSelect(row.program, row.channel)
                    } label: {
                        SearchResultRow(row: row)
                    }
                    .tint(.primary)
                }
            }
        }
    }
}

/// 読み取った条件。× で外せる
private struct ConditionChips: View {
    let conditions: [GuideSearchViewModel.ConditionChip]
    let onRemove: (GuideSearchViewModel.Condition) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("読み取った条件")
                ForEach(conditions) { chip in
                    Button {
                        onRemove(chip.condition)
                    } label: {
                        HStack(spacing: 4) {
                            Text(chip.label)
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
                    .accessibilityLabel("\(chip.label) を外す")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct SearchResultRow: View {
    let row: GuideSearchViewModel.Row

    var body: some View {
        let program = row.program
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(row.timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(program.isOnAir() ? AppTheme.accent : .secondary)
                Text(row.channel.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if row.isReserved {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("録画予約済み")
                }
            }
            Text(program.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            if let reason = row.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
#endif
