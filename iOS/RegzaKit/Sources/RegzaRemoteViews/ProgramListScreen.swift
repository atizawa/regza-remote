#if os(iOS)
import RegzaDesign
import RegzaPresentation
import SwiftUI

/// 1 チャンネルの番組表 (Mirakurun)。放送中の番組から日ごとに並べる
struct ProgramListScreen: View {
    @State private var viewModel: ProgramListViewModel

    init(viewModel: ProgramListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let state = viewModel.state
        content(state)
            .navigationTitle(state.channelName)
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.send(.appear) }
            .refreshable {
                viewModel.send(.reload)
                await waitWhileBusy(viewModel)
            }
    }

    @ViewBuilder
    private func content(_ state: ProgramListViewModel.State) -> some View {
        if let days = state.days {
            if days.isEmpty {
                ContentUnavailableView(
                    "番組表がありません", systemImage: "calendar",
                    description: Text("Mirakurun がこのチャンネルの番組表を持っていません。"))
            } else {
                List {
                    ForEach(days) { group in
                        Section {
                            ForEach(group.programs) { program in
                                NavigationLink(
                                    value: AppViewModel.Route.programDetail(programID: program.id, channelCode: state.channelCode)
                                ) {
                                    ProgramRow(program: program)
                                }
                            }
                        } header: {
                            Text(group.label)
                        }
                    }
                }
            }
        } else if let message = state.loadErrorMessage {
            ContentUnavailableView {
                Label("番組表を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { viewModel.send(.reload) }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 録画予約した番組に付ける印
struct ReservedBadge: View {
    var compact = false

    var body: some View {
        Label(compact ? "予約" : "録画予約済み", systemImage: "record.circle.fill")
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
            .labelStyle(.titleAndIcon)
    }
}

private struct ProgramRow: View {
    let program: ProgramItem
    private var isReserved: Bool { program.isReserved }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(program.startText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(program.isOnAir ? AppTheme.accent : .secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if isReserved {
                        ReservedBadge(compact: true)
                    }
                    if program.isOnAir {
                        Text("放送中").foregroundStyle(AppTheme.accent)
                    }
                    if let genre = program.genreName {
                        Text(genre)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
