#if os(iOS)
import Localization
import RegzaPresentation
import Design
import SwiftUI

/// 番組を探す画面。番組表のナビゲーションバーの虫眼鏡から開く
struct GuideSearchScreen: View {
    let guideSearchViewModel: GuideSearchViewModel
    let onSelect: (SearchResultItem) -> Void
    @State private var isPresented = false

    var body: some View {
        GuideSearchResults(guideSearchViewModel: guideSearchViewModel, onSelect: onSelect)
            .navigationTitle(AppStrings.searchTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(get: { guideSearchViewModel.state.text }, set: { guideSearchViewModel.send(.setText($0)) }),
                isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .always), prompt: AppStrings.searchPlaceholder
            )
            // 開いたらすぐ打てるようにする (前に探した言葉が残っていれば結果を見せる)
            .onAppear { if guideSearchViewModel.state.text.isEmpty { isPresented = true } }
    }
}

/// 検索の結果。時刻順に並べ、なぜ見つかったか (「〇〇 が出演」など) を添える
struct GuideSearchResults: View {
    let guideSearchViewModel: GuideSearchViewModel
    let onSelect: (SearchResultItem) -> Void

    var body: some View {
        let state = guideSearchViewModel.state
        List {
            if !state.conditions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ConditionChips(conditions: state.conditions) { guideSearchViewModel.send(.removeCondition($0)) }
                        Button(AppStrings.searchLiteral(state.text)) { guideSearchViewModel.send(.searchLiterally) }
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
                    Label(AppStrings.searchTitle, systemImage: "magnifyingglass")
                } description: {
                    Text(AppStrings.searchHelp)
                }
            } else if state.results.isEmpty, state.isIndexing {
                ProgressView(AppStrings.searchLoading)
            } else if state.results.isEmpty {
                ContentUnavailableView.search(text: state.text)
            }
        }
    }

    @ViewBuilder
    private func section(_ rows: [SearchResultItem]) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    Button {
                        onSelect(row)
                    } label: {
                        SearchResultRow(row: row)
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("search.result.\(row.program.id)")
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
                    .accessibilityLabel(AppStrings.searchConditions)
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
                    .accessibilityLabel(AppStrings.searchRemoveCondition(chip.label))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct SearchResultRow: View {
    let row: SearchResultItem

    var body: some View {
        let program = row.program
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(row.timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(program.isOnAir ? AppTheme.accent : .secondary)
                Text(row.channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if program.isReserved {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(AppStrings.reservationReserved)
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
