#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビの録画予約の一覧
struct ReservationsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(ReservationsViewModel.self) private var recording
    @State private var loadError: RegzaError?
    @State private var hasLoaded = false
    /// 取り消すか確かめている予約
    @State private var canceling: RegzaReservation?
    @State private var cancelError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("録画予約")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .task { await load() }
                .refreshable { await load() }
                .confirmationDialog(
                    canceling.map { "「\($0.title)」の予約を取り消しますか？" } ?? "",
                    isPresented: Binding(get: { canceling != nil }, set: { if !$0 { canceling = nil } }),
                    titleVisibility: .visible,
                    presenting: canceling
                ) { reservation in
                    Button(reservation.isSeries ? "連ドラ予約を取り消す" : "予約を取り消す", role: .destructive) {
                        Task { await cancel(reservation) }
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
        let scheduled = recording.reservations.filter { $0.isScheduled(now: now) }
        let waiting = recording.reservations.filter { !$0.isScheduled(now: now) }
        if let loadError, recording.reservations.isEmpty {
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
        } else if recording.reservations.isEmpty {
            ContentUnavailableView("録画予約はありません", systemImage: "calendar")
        } else {
            List {
                if let cancelError {
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
            if let channel = model.channels.first(where: { $0.code == reservation.channelCode }) {
                Text(channel.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cancel(_ reservation: RegzaReservation) async {
        cancelError = nil
        do {
            try await recording.cancel(reservation)
        } catch {
            cancelError = "「\(reservation.title)」の予約を取り消せませんでした: \(error.localizedDescription)"
        }
    }

    private func load() async {
        defer { hasLoaded = true }
        // 局名を出すためにチャンネル一覧も読む (取れなくても予約は出す)
        try? await model.loadChannels()
        do {
            try await recording.loadReservations()
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
