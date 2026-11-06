#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 番組を探す画面。番組表のナビゲーションバーの虫眼鏡から開く
struct GuideSearchScreen: View {
    @Bindable var search: GuideSearchViewModel
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
    let search: GuideSearchViewModel
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
            if search.isBlank {
                ContentUnavailableView {
                    Label("番組を探す", systemImage: "magnifyingglass")
                } description: {
                    Text("1 週間分の番組から、番組名・出演者・説明で探します。\n「明日の夜のドラマ」「土曜 21時から」のように、日付・時間帯・ジャンルでも絞り込めます。")
                }
            } else if search.results.isEmpty, search.isIndexing {
                ProgressView("番組を読み込んでいます")
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
                    if let channel = search.channel(for: result.program) {
                        Button {
                            onSelect(result.program, channel)
                        } label: {
                            SearchResultRow(search: search, result: result, channel: channel)
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }
}

/// 読み取った条件。× で外せる
private struct ConditionChips: View {
    let search: GuideSearchViewModel

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
    let search: GuideSearchViewModel
    let result: ProgramSearchResult
    let channel: RegzaChannel

    var body: some View {
        let program = result.program
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(search.timeText(of: program))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(program.isOnAir() ? AppTheme.accent : .secondary)
                Text(channel.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if search.isReserved(program) {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("録画予約済み")
                }
            }
            Text(program.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            if let reason = search.reason(for: result) {
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
