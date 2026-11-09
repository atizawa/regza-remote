#if os(iOS)
import AVKit
import RegzaPresentation
import RegzaLiveActivity
import SwiftUI

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴)。
/// 縦向きでは映像の下に今の番組の情報と局の一覧を出し、局を押すとその局の配信に切り替える。横向きでは映像だけを出す。
/// 閉じたり局を切り替えたりしたら、前の配信を止めてチューナーを空ける
struct LivePlayerView: View {
    @State private var viewModel: LivePlayerViewModel
    /// 再生しているもの (ViewModel が出した URL の配信)
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(viewModel: LivePlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// 横向き (高さが狭い) なら映像だけにする
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        Group {
            if isLandscape {
                video
                    .ignoresSafeArea()
            } else {
                // ナビゲーションバーの左上の × で閉じる (映像の上には重ねない)
                NavigationStack {
                    VStack(spacing: 0) {
                        video
                            .aspectRatio(16 / 9, contentMode: .fit)
                        ScrollView {
                            VStack(alignment: .leading, spacing: Design.group) {
                                ProgramInfo(viewModel: viewModel)
                                ChannelPicker(viewModel: viewModel)
                            }
                            .padding(.vertical, Design.outer)
                        }
                    }
                    .background(Surface.background.ignoresSafeArea())
                    .navigationTitle("ライブ視聴")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // 閉じるだけの画面は、iOS 標準の × のボタンにそろえる
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) { dismiss() }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.send(.appear)
            viewModel.send(.start)
        }
        .onDisappear { viewModel.send(.end) }
        .onChange(of: viewModel.state.phase, initial: true) { _, phase in
            // 局を切り替えたり閉じたりしたら、前の配信の再生をやめる
            player?.pause()
            player = nil
            if case .ready(let url) = phase {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                let player = AVPlayer(url: url)
                player.play()
                self.player = player
            }
        }
    }

    private var video: some View {
        ZStack {
            Color.black
            let state = viewModel.state
            switch state.phase {
            case .preparing:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(state.preparingMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            case .ready:
                if let player {
                    PlayerController(player: player)
                }
            case .failed(let message, let canRetry):
                VStack(spacing: 12) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    if canRetry {
                        Button("準備できていない配信を止めて、もう一度試す") {
                            viewModel.send(.retryAfterStoppingStalled)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if isLandscape {
                        Button("閉じる") { dismiss() }
                    }
                }
                .padding()
            }
        }
    }
}

/// 見ている局の今の番組 (Mirakurun の番組表から)
private struct ProgramInfo: View {
    let viewModel: LivePlayerViewModel

    var body: some View {
        // 番組が変わったら表示も変える
        // state は読むたびに今の時刻で番組を求める
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let state = viewModel.state
            let program = state.program
            VStack(alignment: .leading, spacing: 6) {
                Text(state.channelName + (program == nil ? "" : " · 放送中"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(program?.name ?? state.channelName)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let program {
                    HStack(spacing: 4) {
                        Text(program.timeText)
                        if let genre = program.genreName { Text("· \(genre)") }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    ProgressView(timerInterval: program.start...program.end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(AppTheme.accent)
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding(.horizontal, Design.outer)
        }
    }
}

/// iPhone で見られる局の一覧。押すとその局に切り替える
private struct ChannelPicker: View {
    let viewModel: LivePlayerViewModel

    var body: some View {
        let state = viewModel.state
        VStack(alignment: .leading, spacing: 0) {
            if state.bands.count > 1 {
                BandPicker(bands: state.bands)
            }
            ForEach(state.channels) { row in
                Button {
                    viewModel.send(.switchChannel(row.code))
                } label: {
                    HStack(spacing: 12) {
                        Text(row.numberText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .lineLimit(1)
                            if let programName = row.programName {
                                Text(programName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if row.isNowPlaying {
                            Image(systemName: "play.fill")
                                .foregroundStyle(AppTheme.accent)
                                .accessibilityLabel("再生中")
                        }
                    }
                    .padding(.horizontal, Design.outer)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, Design.outer)
            }
        }
    }
}

/// iOS 標準の再生画面 (全画面・ピクチャインピクチャ・AirPlay に対応)
private struct PlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        /// ピクチャインピクチャから戻るときは、この再生画面のまま続ける
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }
    }
}
#endif
