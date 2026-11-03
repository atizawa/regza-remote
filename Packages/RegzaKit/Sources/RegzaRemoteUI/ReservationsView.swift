#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビの録画予約の一覧
struct ReservationsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var loadError: RegzaError?
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("録画予約")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        let now = Date()
        let scheduled = model.reservations.filter { $0.isScheduled(now: now) }
        let waiting = model.reservations.filter { !$0.isScheduled(now: now) }
        if let loadError, model.reservations.isEmpty {
            ContentUnavailableView {
                Label("録画予約を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(loadError.recordingMessage)
            } actions: {
                Button("もう一度試す") { Task { await load() } }
            }
        } else if !hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.reservations.isEmpty {
            ContentUnavailableView("録画予約はありません", systemImage: "calendar")
        } else {
            List {
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
            if let channel = model.channels.first(where: { $0.code == reservation.channelCode }) {
                Text(channel.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        defer { hasLoaded = true }
        // 局名を出すためにチャンネル一覧も読む (取れなくても予約は出す)
        try? await model.loadChannels()
        do {
            try await model.loadReservations()
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

extension RegzaError {
    /// 録画まわりの画面に出すメッセージ
    var recordingMessage: String {
        switch self {
        case .httpStatus(404), .unsupported: "この機種は対応していません。"
        default: localizedDescription
        }
    }
}
#endif
