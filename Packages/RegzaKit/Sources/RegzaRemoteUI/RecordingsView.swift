#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビの DLNA サーバーにある録画番組をフォルダごとにたどる
struct RecordingsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var server: RegzaMediaServer?

    var body: some View {
        NavigationStack {
            Group {
                if let server {
                    RecordingFolderView(
                        server: server,
                        folder: RegzaRecordingFolder(id: RegzaMediaServer.rootID, title: "録画番組")
                    )
                }
            }
            .navigationDestination(for: RegzaRecordingFolder.self) { folder in
                if let server { RecordingFolderView(server: server, folder: folder) }
            }
            .navigationDestination(for: RegzaRecording.self) { recording in
                RecordingDetailView(recording: recording)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            if server == nil { server = model.mediaServer() }
        }
    }
}

private struct RecordingFolderView: View {
    let server: RegzaMediaServer
    let folder: RegzaRecordingFolder

    @State private var folders: [RegzaRecordingFolder] = []
    @State private var recordings: [RegzaRecording] = []
    @State private var total: Int?
    @State private var isLoading = false
    @State private var loadError: RegzaError?

    private static let pageSize = 50

    var body: some View {
        content
            .navigationTitle(folder.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if total == nil { await loadMore() }
            }
            .refreshable { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError, total == nil {
            ContentUnavailableView {
                Label("録画番組を取得できません", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(loadError.recordingMessage)
            } actions: {
                Button("もう一度試す") { Task { await loadMore() } }
            }
        } else if total == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if folders.isEmpty, recordings.isEmpty {
            ContentUnavailableView("録画番組はありません", systemImage: "film.stack")
        } else {
            List {
                ForEach(folders) { child in
                    NavigationLink(value: child) {
                        HStack {
                            Label(child.title, systemImage: "folder")
                            Spacer()
                            if let count = child.childCount {
                                Text("\(count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                ForEach(recordings) { recording in
                    NavigationLink(value: recording) {
                        RecordingRow(recording: recording)
                    }
                    .onAppear {
                        // 最後の行が見えたら次のページを読む
                        if recording == recordings.last { Task { await loadMore() } }
                    }
                }
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let loadError {
                    Button("続きを読み込めませんでした（\(loadError.recordingMessage)）。もう一度試す") {
                        Task { await loadMore() }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private var hasMore: Bool {
        guard let total else { return true }
        return folders.count + recordings.count < total
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await server.browse(folder.id, start: folders.count + recordings.count, count: Self.pageSize)
            folders += page.folders
            recordings += page.recordings
            // 返ってきた数が 0 なら、総数より少なくても打ち切る
            total = page.folders.isEmpty && page.recordings.isEmpty
                ? folders.count + recordings.count
                : page.total
            loadError = nil
        } catch {
            loadError = error as? RegzaError ?? .network(error.localizedDescription)
        }
    }

    private func reload() async {
        folders = []
        recordings = []
        total = nil
        await loadMore()
    }
}

private struct RecordingRow: View {
    let recording: RegzaRecording

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(recording.isUnwatched ? Color.orange : .clear)
                .frame(width: 8, height: 8)
                .accessibilityLabel(recording.isUnwatched ? "未視聴" : "")
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .lineLimit(2)
                RecordingCaption(recording: recording)
            }
        }
    }
}

/// `11月3日(火) 9:25 · ＮＨＫＥテレ · 30分`
private struct RecordingCaption: View {
    let recording: RegzaRecording

    var body: some View {
        HStack(spacing: 4) {
            if let date = recording.date {
                Text(date, format: .dateTime.month().day().weekday().hour().minute())
            }
            if !recording.channelName.isEmpty {
                Text("·")
                Text(recording.channelName).lineLimit(1)
            }
            if recording.duration > 0 {
                Text("·")
                Text(Duration.seconds(recording.duration), format: .units(allowed: [.hours, .minutes], width: .narrow))
                    .fixedSize()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct RecordingDetailView: View {
    @Environment(RemoteViewModel.self) private var model
    let recording: RegzaRecording

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.title)
                        .font(.headline)
                    RecordingCaption(recording: recording)
                    HStack(spacing: 6) {
                        if recording.isUnwatched {
                            Text("未視聴")
                                .foregroundStyle(.orange)
                        }
                        if !recording.genre.isEmpty {
                            Text(recording.genre)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
                if !recording.description.isEmpty {
                    Text(recording.description)
                        .font(.subheadline)
                }
            }
            Section {
                Button {
                    model.send(.recordedList)
                } label: {
                    Label("テレビの録画リストを開く", systemImage: "list.bullet.rectangle")
                }
            } footer: {
                Text("アプリから番組を指定して再生することはできません。テレビの録画リストから再生してください。")
            }
        }
        .navigationTitle("番組の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
