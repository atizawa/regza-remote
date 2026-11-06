#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビの録画予約の一覧
struct ReservationsView: View {
    @State private var viewModel: ReservationListViewModel
    /// 取り消すか確かめている予約
    @State private var canceling: RegzaReservation?

    init(viewModel: ReservationListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("録画予約")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .task { await viewModel.load() }
                .refreshable { await viewModel.load() }
                .confirmationDialog(
                    canceling.map { "「\($0.title)」の予約を取り消しますか？" } ?? "",
                    isPresented: Binding(get: { canceling != nil }, set: { if !$0 { canceling = nil } }),
                    titleVisibility: .visible,
                    presenting: canceling
                ) { reservation in
                    Button(reservation.isSeries ? "連ドラ予約を取り消す" : "予約を取り消す", role: .destructive) {
                        Task { await viewModel.cancel(reservation) }
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
        let now = Date()
        let scheduled = viewModel.scheduled(now: now)
        let waiting = viewModel.waiting(now: now)
        if let message = viewModel.loadErrorMessage {
            ContentUnavailableView {
                Label("録画予約を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { Task { await viewModel.load() } }
            }
        } else if !viewModel.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isEmpty {
            ContentUnavailableView("録画予約はありません", systemImage: "calendar")
        } else {
            List {
                if let cancelError = viewModel.cancelError {
                    Text(cancelError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if !scheduled.isEmpty {
                    Section("予定") {
                        ForEach(scheduled) { row($0, isScheduled: true) }
                    }
                }
                if !waiting.isEmpty {
                    Section {
                        ForEach(waiting) { row($0, isScheduled: false) }
                    } header: {
                        Text("次の回を待っている連ドラ予約")
                    } footer: {
                        Text("番組表に次の回が載ると、テレビが自動で予約します。日時は最後に録画した回のものです。")
                    }
                }
            }
        }
    }

    private func row(_ reservation: RegzaReservation, isScheduled: Bool) -> some View {
        rowContent(reservation, isScheduled: isScheduled)
            .swipeActions {
                Button("取り消す", role: .destructive) { canceling = reservation }
            }
    }

    private func rowContent(_ reservation: RegzaReservation, isScheduled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reservation.title)
                .lineLimit(2)
                .foregroundStyle(isScheduled ? .primary : .secondary)
            HStack(spacing: 6) {
                if isScheduled, reservation.start <= Date() {
                    Label("録画中", systemImage: "record.circle")
                        .foregroundStyle(.red)
                }
                Text(reservation.start, format: .dateTime.month().day().weekday().hour().minute())
                Text("〜")
                Text(reservation.end, format: .dateTime.hour().minute())
                if let repeatLabel = reservation.repeatLabel {
                    Text(repeatLabel)
                        .padding(.horizontal, 6)
                        .background(.fill.tertiary, in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let channelName = viewModel.channelName(of: reservation) {
                Text(channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
