#if os(iOS)
import RegzaPresentation
import RegzaDesign
import SwiftUI

/// テレビから取得した視聴状況。録画再生中はシークできる
struct NowPlayingCard: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var seekPosition: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.state.isSearchingTV {
                status("テレビが見つからないため、探しています…", systemImage: "magnifyingglass")
            } else if let message = model.state.errorMessage {
                status(message, systemImage: "exclamationmark.triangle.fill", isWarning: true)
            } else if let nowPlaying = model.state.nowPlaying {
                switch nowPlaying.kind {
                case .recorded: playback(nowPlaying)
                case .broadcast: broadcast(nowPlaying)
                case .external: status(nowPlaying.statusText ?? "", systemImage: "cable.connector")
                case .standby: status(nowPlaying.statusText ?? "", systemImage: "moon.zzz")
                case .unknown: status(nowPlaying.statusText ?? "", systemImage: "tv")
                }
            } else {
                status("接続中…", systemImage: "tv")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Design.outer)
        .background {
            RoundedRectangle(cornerRadius: Design.cornerRadius + 4, style: .continuous)
                .fill(Surface.button)
                .overlay {
                    RoundedRectangle(cornerRadius: Design.cornerRadius + 4, style: .continuous)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                }
        }
    }

    private func status(_ text: String, systemImage: String, isWarning: Bool = false) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isWarning ? Color.orange : .secondary)
            .lineLimit(2)
    }

    /// `● みどりテレビ` のような見出し。緑の点は「いま映っている」の印
    private func sourceLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .lineLimit(1)
    }

    /// 進捗バーと、その両端の時刻
    private func timeline(progress: Double, leading: Text, trailing: Text) -> some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
                .tint(AppTheme.accent)
            HStack {
                leading
                Spacer()
                trailing
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func broadcast(_ nowPlaying: NowPlayingItem) -> some View {
        sourceLabel(
            nowPlaying.channelName.isEmpty ? "放送" : nowPlaying.channelName,
            systemImage: "antenna.radiowaves.left.and.right")
        if !nowPlaying.title.isEmpty {
            Text(nowPlaying.title)
                .font(.headline)
                .lineLimit(2)
        } else if !nowPlaying.genre.isEmpty {
            // 番組名が取れない機種では、ジャンルで何の番組かを示す
            Text(nowPlaying.genre)
                .font(.headline)
        }
        if nowPlaying.hasTimeline {
            let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
            timeline(
                progress: nowPlaying.progress,
                leading: Text(start, style: .time),
                trailing: Text(start.addingTimeInterval(TimeInterval(nowPlaying.duration)), style: .time)
            )
        }
    }

    @ViewBuilder
    private func playback(_ nowPlaying: NowPlayingItem) -> some View {
        sourceLabel(
            nowPlaying.channelName.isEmpty ? "録画番組" : "録画 · \(nowPlaying.channelName)",
            systemImage: "play.rectangle")
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
                    model.send(.seek(Int(seekPosition)))
                    self.seekPosition = nil
                }
            }
            HStack {
                Text(NowPlayingItem.durationText(Int(position)))
                Spacer()
                Text(NowPlayingItem.durationText(nowPlaying.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}
#endif
