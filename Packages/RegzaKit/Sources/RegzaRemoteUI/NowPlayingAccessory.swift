#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// タブバーの上に出すミニプレーヤー。どのタブでもテレビで映っているものが分かる。
/// iPhone で再生しているものと間違えないよう、テレビのアイコンとチャンネル名を添える
struct NowPlayingAccessory: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var isShowingDetail = false

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
                    model.send(key)
                } label: {
                    Image(systemName: key.systemImage ?? "circle")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key.label)
            }
        }
        .padding(.horizontal, Design.outer)
        .contentShape(Rectangle())
        .onTapGesture { isShowingDetail = true }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("番組の詳細を開きます")
        .sheet(isPresented: $isShowingDetail) {
            NowPlayingDetailView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 表示する内容

    private var nowPlaying: RegzaNowPlaying? { model.nowPlaying }

    private var icon: String {
        switch nowPlaying?.kind {
        case .recorded: "play.rectangle"
        case .external: "cable.connector"
        case .standby: "moon.zzz"
        default: "tv"
        }
    }

    /// 上の小さな行: チャンネル名や「録画」
    private var caption: String? {
        if model.isSearchingTV || model.lastError != nil { return nil }
        guard let nowPlaying else { return nil }
        switch nowPlaying.kind {
        case .broadcast:
            return nowPlaying.title.isEmpty ? nil : nowPlaying.channelName
        case .recorded:
            return nowPlaying.channelName.isEmpty ? "録画" : "録画 · \(nowPlaying.channelName)"
        default:
            return nil
        }
    }

    /// 下の大きな行: 番組名や状態
    private var headline: String {
        if model.isSearchingTV { return "テレビを探しています…" }
        if model.lastError != nil { return "テレビに接続できません" }
        guard let nowPlaying else { return "接続中…" }
        switch nowPlaying.kind {
        case .broadcast:
            if !nowPlaying.title.isEmpty { return nowPlaying.title }
            return nowPlaying.channelName.isEmpty ? "放送" : nowPlaying.channelName
        case .recorded: return nowPlaying.title
        case .external: return "外部入力"
        case .standby: return "待機中"
        case .unknown: return "接続済み"
        }
    }

    private var progress: Double? {
        guard let nowPlaying, nowPlaying.hasTimeline, model.lastError == nil else { return nil }
        return nowPlaying.progress
    }

    /// 右端のボタン: 録画は再生/一時停止、放送は消音
    private var trailingKey: RegzaKey? {
        guard let nowPlaying, model.lastError == nil else { return nil }
        switch nowPlaying.kind {
        case .recorded: return nowPlaying.isAdvancing ? .pause : .play
        case .broadcast: return .mute
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

/// ミニプレーヤーを押したときの詳細。録画ならシークもできる
private struct NowPlayingDetailView: View {
    @Environment(RemoteViewModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.group) {
                    NowPlayingCard()
                    if let description = model.nowPlaying?.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    if model.canStartOverNowPlaying {
                        Button {
                            model.startOver()
                        } label: {
                            Label("この番組を最初から見る", systemImage: "backward.end.alt")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: Design.regularHeight)
                        }
                        .buttonStyle(RemoteButtonStyle())
                    }
                    LiveActivityToggle()
                        .padding(Design.outer)
                        .background(Surface.button, in: RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))
                }
                .padding(Design.outer)
            }
            .background(Surface.background)
            .navigationTitle("視聴中")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadTimeshiftSettings() }
        }
    }
}
#endif
