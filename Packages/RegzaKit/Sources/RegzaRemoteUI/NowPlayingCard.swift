#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビから取得した視聴状況。録画再生中はシークできる
struct NowPlayingCard: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var seekPosition: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isSearchingTV {
                Label("テレビが見つからないため、探しています…", systemImage: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let error = model.lastError {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if let nowPlaying = model.nowPlaying {
                switch nowPlaying.kind {
                case .recorded: playback(nowPlaying)
                case .broadcast: broadcast(nowPlaying)
                case .external: Label("外部入力", systemImage: "cable.connector").font(.headline)
                case .standby: Label("待機中", systemImage: "moon.zzz").font(.headline)
                case .unknown:
                    Label("接続済み", systemImage: "tv")
                        .font(.headline)
                    Text("録画番組の再生中は、番組名と再生位置がここと Dynamic Island に表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("接続中…", systemImage: "tv")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func broadcast(_ nowPlaying: RegzaNowPlaying) -> some View {
        Label(nowPlaying.channelName.isEmpty ? "放送" : nowPlaying.channelName, systemImage: "antenna.radiowaves.left.and.right")
            .font(.headline)
            .foregroundStyle(.tint)
        if !nowPlaying.title.isEmpty {
            Text(nowPlaying.title)
                .font(.headline)
                .lineLimit(2)
        }
        if nowPlaying.hasTimeline {
            let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
            ProgressView(value: nowPlaying.progress)
            HStack {
                Text(start, style: .time)
                Spacer()
                Text(start.addingTimeInterval(TimeInterval(nowPlaying.duration)), style: .time)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        if let next = nowPlaying.nextProgramStart {
            Text("次の番組 \(next.formatted(date: .omitted, time: .shortened))〜")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func playback(_ nowPlaying: RegzaNowPlaying) -> some View {
        if !nowPlaying.channelName.isEmpty {
            Label(nowPlaying.channelName, systemImage: "tv")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        Text(nowPlaying.title)
            .font(.headline)
            .lineLimit(2)
        if !nowPlaying.chapterName.isEmpty {
            Text(nowPlaying.chapterName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if nowPlaying.duration > 0 {
            let position = seekPosition ?? Double(nowPlaying.position)
            Slider(
                value: Binding(get: { position }, set: { seekPosition = $0 }),
                in: 0...Double(nowPlaying.duration)
            ) { editing in
                if !editing, let seekPosition {
                    model.seek(to: Int(seekPosition))
                    self.seekPosition = nil
                }
            }
            HStack {
                Text(Int(position).formattedDuration)
                Spacer()
                Text(nowPlaying.duration.formattedDuration)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}
#endif
