#if os(iOS)
import RegzaPresentation
import SwiftUI

/// テレビの録画予約の一覧
struct ReservationListScreen: View {
    @State private var viewModel: ReservationListViewModel
    /// 取り消すか確かめている予約
    @State private var canceling: ReservationItem?

    init(viewModel: ReservationListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("録画予約")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .task { viewModel.send(.load) }
                .refreshable {
                    viewModel.send(.load)
                    await waitWhileBusy(viewModel)
                }
                .confirmationDialog(
                    canceling.map { "「\($0.title)」の予約を取り消しますか？" } ?? "",
                    isPresented: Binding(get: { canceling != nil }, set: { if !$0 { canceling = nil } }),
                    titleVisibility: .visible,
                    presenting: canceling
                ) { reservation in
                    Button(reservation.isSeries ? "連ドラ予約を取り消す" : "予約を取り消す", role: .destructive) {
                        viewModel.send(.cancel(reservation.id))
                    }
                } message: { reservation in
                    if reservation.isSeries {
                        Text("連ドラ予約なので、次の回以降も録画されなくなります。")
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let state = viewModel.state
        if let message = state.loadErrorMessage {
            ContentUnavailableView {
                Label("録画予約を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { viewModel.send(.load) }
            }
        } else if !state.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.isEmpty {
            ContentUnavailableView("録画予約はありません", systemImage: "calendar")
        } else {
            List {
                if let cancelError = state.cancelError {
                    Text(cancelError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if !state.scheduled.isEmpty {
                    Section("予定") {
                        ForEach(state.scheduled) { row($0) }
                    }
                }
                if !state.waiting.isEmpty {
                    Section {
                        ForEach(state.waiting) { row($0) }
                    } header: {
                        Text("次の回を待っている連ドラ予約")
                    } footer: {
                        Text("番組表に次の回が載ると、テレビが自動で予約します。日時は最後に録画した回のものです。")
                    }
                }
            }
        }
    }

    private func row(_ item: ReservationItem) -> some View {
        rowContent(item)
            .swipeActions {
                Button("取り消す", role: .destructive) { canceling = item }
            }
    }

    private func rowContent(_ item: ReservationItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .lineLimit(2)
                .foregroundStyle(item.isScheduled ? .primary : .secondary)
            HStack(spacing: 6) {
                if item.isRecording {
                    Label("録画中", systemImage: "record.circle")
                        .foregroundStyle(.red)
                }
                Text(item.timeText)
                if let repeatLabel = item.repeatLabel {
                    Text(repeatLabel)
                        .padding(.horizontal, 6)
                        .background(.fill.tertiary, in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let channelName = item.channelName {
                Text(channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
