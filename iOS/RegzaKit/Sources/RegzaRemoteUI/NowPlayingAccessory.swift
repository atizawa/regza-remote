#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// タブバーの上に出すミニプレーヤー。どのタブでもテレビで映っているものが分かる。
/// iPhone で再生しているものと間違えないよう、テレビのアイコンとチャンネル名を添える
struct NowPlayingAccessory: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(AppViewModel.self) private var app
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
                    model.send(.press(key))
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
        .onTapGesture { app.send(.showNowPlaying) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("番組の詳細を開きます")
        .sheet(isPresented: Binding(get: { app.state.isShowingNowPlaying }, set: { if !$0 { app.send(.closeNowPlaying) } })) {
            NowPlayingDetailView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 表示する内容

    private var nowPlaying: RegzaNowPlaying? { model.state.nowPlaying }

    private var icon: String {
        switch nowPlaying?.kind {
        case .recorded: "play.rectangle"
        case .external: "cable.connector"
        case .standby: "moon.zzz"
        default: "tv"
        }
    }

    /// 上の小さな行: チャンネル名や「録画」 (文言は Android と同じ RegzaNowPlaying.captionText)
    private var caption: String? {
        if model.state.isSearchingTV || model.state.lastError != nil { return nil }
        return nowPlaying?.captionText
    }

    /// 下の大きな行: 番組名や状態 (文言は Android と同じ RegzaNowPlaying.headlineText)
    private var headline: String {
        if model.state.isSearchingTV { return "テレビを探しています…" }
        if model.state.lastError != nil { return "テレビに接続できません" }
        return nowPlaying?.headlineText ?? "接続中…"
    }

    private var progress: Double? {
        guard let nowPlaying, nowPlaying.hasTimeline, model.state.lastError == nil else { return nil }
        return nowPlaying.progress
    }

    /// 右端のボタン: 録画は再生/一時停止、放送は消音、待機中は電源
    private var trailingKey: RegzaKey? {
        guard let nowPlaying, model.state.lastError == nil else { return nil }
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

/// ミニプレーヤーを押したときの詳細。録画ならシークもできる
private struct NowPlayingDetailView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(GuideViewModel.self) private var guide
    @Environment(StreamViewModel.self) private var stream
    @Environment(AppViewModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.group) {
                    NowPlayingCard()
                    if let description = model.state.nowPlaying?.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    // 開いている間はミニプレーヤーの電源ボタンが隠れるので、ここでも入れられるようにする
                    if model.state.nowPlaying?.kind == .standby, model.state.lastError == nil {
                        Button {
                            model.send(.press(.power))
                        } label: {
                            Label("電源を入れる", systemImage: "power")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: Design.regularHeight)
                        }
                        .buttonStyle(RemoteButtonStyle())
                    }
                    if stream.canStream, model.state.nowPlaying?.kind == .broadcast, model.state.nowPlayingChannel != nil {
                        Button {
                            if let channel = model.state.nowPlayingChannel { app.send(.play(channel)) }
                        } label: {
                            Label("アプリで見る", systemImage: "play.tv")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: Design.regularHeight)
                        }
                        .buttonStyle(RemoteButtonStyle())
                    }
                    if guide.canStartOverNowPlaying {
                        Button {
                            guide.startOver()
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 閉じるだけの画面は、iOS 標準の × のボタンにそろえる
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .task {
                await guide.loadTimeshiftSettings()
                // いま映っているチャンネルを知るため
                model.send(.loadChannels(force: false))
            }
            // このシートを開いている間は、アプリで見る画面をシートの上から出す
            .fullScreenCover(isPresented: Binding(
                get: { app.state.playingChannel != nil },
                set: { if !$0 { app.send(.closePlayer) } }
            )) {
                if let player = app.player {
                    LivePlayerView(viewModel: player)
                }
            }
        }
    }

    /// 番組を映しているときだけ「視聴中」にする。待機中などはカードに状態が出るので、見出しはテレビとだけ書く
    private var title: String {
        guard !model.state.isSearchingTV, model.state.lastError == nil else { return "テレビ" }
        switch model.state.nowPlaying?.kind {
        case .broadcast, .recorded: return "視聴中"
        default: return "テレビ"
        }
    }
}
#endif
