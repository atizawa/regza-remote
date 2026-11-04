#if os(iOS)
import AVKit
import RegzaCore
import SwiftUI

/// EPGStation のライブ配信を iPhone で見る全画面の再生画面。
/// 開くと配信を頼み、準備ができたら iOS 標準のプレーヤーで再生する。閉じたら配信を止めてチューナーを空ける
struct LivePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let server: EPGStation
    let channel: RegzaChannel
    var programName: String?

    @State private var phase = Phase.preparing
    @State private var streamID: Int?

    private enum Phase {
        case preparing
        case playing(AVPlayer)
        case failed(String, canRetry: Bool)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .preparing:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("\(channel.name) の配信を準備しています…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("始まるまで 20 秒ほどかかります")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            case .playing(let player):
                // 再生中は標準のプレーヤーの × で閉じる (自前の閉じるボタンを重ねると 2 つになる)
                PlayerController(player: player) { dismiss() }
                    .ignoresSafeArea()
            case .failed(let message, let canRetry):
                ContentUnavailableView {
                    Label("再生できませんでした", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    if canRetry {
                        Button("準備できていない配信を止めて、もう一度試す") {
                            Task { await retryAfterStoppingStalled() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if !isPlaying {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .padding()
                .accessibilityLabel("閉じる")
            }
        }
        .task { await start() }
        .onDisappear { stop() }
    }

    private var isPlaying: Bool {
        if case .playing = phase { return true }
        return false
    }

    private func start() async {
        guard let channelID = EPGStation.channelID(channelCode: channel.code) else {
            phase = .failed("このチャンネルは EPGStation で見られません。", canRetry: false)
            return
        }
        do {
            // 前に止められずに残った、このアプリの配信を先に止める
            await LiveStreams.cleanUp(server)
            let streamID = try await server.startLiveStream(channelID: channelID)
            self.streamID = streamID
            LiveStreams.started(streamID)
            try await server.waitUntilReady(streamID: streamID)
            guard let url = server.playlistURL(streamID: streamID) else { throw RegzaError.invalidHost }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            let player = AVPlayer(url: url)
            player.play()
            phase = .playing(player)
            // 見ていることを知らせ続ける (知らせないと EPGStation が配信を止める)
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(10))
                try? await server.keep(streamID: streamID)
            }
        } catch is CancellationError {
            return
        } catch {
            // 始まらなかった配信は残さない
            if let streamID { await stop(streamID) }
            phase = .failed("""
                \(error.localizedDescription)
                EPGStation で同時に変換できる数の上限に達していると始まりません。ほかの画面で見ている配信を閉じるか、準備できないまま残っている配信を止めてから試してください。
                """, canRetry: true)
        }
    }

    private func retryAfterStoppingStalled() async {
        phase = .preparing
        await LiveStreams.stopStalled(server)
        await start()
    }

    private func stop() {
        if case .playing(let player) = phase { player.pause() }
        guard let streamID else { return }
        Task { await stop(streamID) }
    }

    private func stop(_ streamID: Int) async {
        self.streamID = nil
        if (try? await server.stop(streamID: streamID)) != nil {
            LiveStreams.stopped(streamID)
        }
    }
}

/// iOS 標準の再生画面 (ピクチャインピクチャ・AirPlay に対応)
private struct PlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    /// 標準の × ボタンで閉じられたとき
    var onClose: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
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
        context.coordinator.onClose = onClose
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        nonisolated(unsafe) var onClose: @MainActor () -> Void

        init(onClose: @escaping @MainActor () -> Void) {
            self.onClose = onClose
        }

        /// × ボタンで全画面表示を終えるとき、再生画面ごと閉じる
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
        ) {
            // デリゲートはメインスレッドで呼ばれる
            let close = onClose
            MainActor.assumeIsolated { close() }
        }

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
