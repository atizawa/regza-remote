#if os(iOS)
import RegzaPresentation
import RegzaDesign
import SwiftUI

/// タブバーの上に出すミニプレーヤー。どのタブでもテレビで映っているものが分かる。
/// iPhone で再生しているものと間違えないよう、テレビのアイコンとチャンネル名を添える
struct NowPlayingAccessory: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 12) {
            ProgressIcon(systemImage: icon, progress: progress)
            VStack(alignment: .leading, spacing: 1) {
                // タブバーと重なって狭いとき (inline) は 1 行にする
                if placement != .inline, let caption {
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                }
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let key = trailingKey {
                Button {
                    remoteViewModel.send(.press(key))
                } label: {
                    Image(systemName: key.systemImage ?? "circle")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == .power ? "電源を入れる" : key.label)
            }
        }
        .padding(.horizontal, Design.outer)
        .contentShape(Rectangle())
        .onTapGesture { appViewModel.send(.showNowPlaying) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("番組の詳細を開きます")
        .sheet(
            isPresented: Binding(get: { appViewModel.state.isShowingNowPlaying }, set: { if !$0 { appViewModel.send(.closeNowPlaying) } })
        ) {
            NowPlayingScreen()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 表示する内容

    private var nowPlaying: NowPlayingItem? { remoteViewModel.state.nowPlaying }

    private var icon: String {
        switch nowPlaying?.kind {
        case .recorded: "play.rectangle"
        case .external: "cable.connector"
        case .standby: "moon.zzz"
        default: "tv"
        }
    }

    /// 上の小さな行: チャンネル名や「録画」 (文言は Android と同じ NowPlayingItem.captionText)
    private var caption: String? {
        if remoteViewModel.state.isSearchingTV || remoteViewModel.state.errorMessage != nil { return nil }
        return nowPlaying?.captionText
    }

    /// 下の大きな行: 番組名や状態 (文言は Android と同じ NowPlayingItem.headlineText)
    private var headline: String {
        if remoteViewModel.state.isSearchingTV { return "テレビを探しています…" }
        if remoteViewModel.state.errorMessage != nil { return "テレビに接続できません" }
        return nowPlaying?.headlineText ?? "接続中…"
    }

    private var progress: Double? {
        guard let nowPlaying, nowPlaying.hasTimeline, remoteViewModel.state.errorMessage == nil else { return nil }
        return nowPlaying.progress
    }

    /// 右端のボタン: 録画は再生/一時停止、放送は消音、待機中は電源
    private var trailingKey: RegzaKey? {
        guard let nowPlaying, remoteViewModel.state.errorMessage == nil else { return nil }
        switch nowPlaying.kind {
        case .recorded: return nowPlaying.isAdvancing ? .pause : .play
        case .broadcast: return .mute
        case .standby: return .power
        default: return nil
        }
    }
}

/// 進み具合の輪で囲んだアイコン
private struct ProgressIcon: View {
    let systemImage: String
    let progress: Double?

    var body: some View {
        ZStack {
            Circle().stroke(Color(.separator), lineWidth: 2)
            if let progress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}
#endif
