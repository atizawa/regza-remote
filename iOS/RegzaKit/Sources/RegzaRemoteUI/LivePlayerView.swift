#if os(iOS)
import AVKit
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴)。
/// 縦向きでは映像の下に今の番組の情報と局の一覧を出し、局を押すとその局の配信に切り替える。横向きでは映像だけを出す。
/// 閉じたり局を切り替えたりしたら、前の配信を止めてチューナーを空ける
struct LivePlayerView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(GuideViewModel.self) private var guide
    @Environment(StreamViewModel.self) private var stream
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let server: EPGStation

    /// いま見ている局
    @State private var channel: RegzaChannel
    @State private var phase = Phase.preparing
    @State private var streamID: Int?
    /// 配信を頼んでから見終わるまでの処理 (局を切り替えたら止めて頼み直す)
    @State private var session: Task<Void, Never>?

    private enum Phase {
        case preparing
        case playing(AVPlayer)
        case failed(String, canRetry: Bool)
    }

    init(server: EPGStation, channel: RegzaChannel) {
        self.server = server
        _channel = State(initialValue: channel)
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
                                ProgramInfo(channel: channel)
                                ChannelPicker(current: channel) { switchChannel(to: $0) }
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
        .task {
            try? await model.loadChannels()
            await guide.loadGuidePrograms()
        }
        .onAppear { startSession() }
        .onDisappear { endSession() }
    }

    private var video: some View {
        ZStack {
            Color.black
            switch phase {
            case .preparing:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("\(channel.name) の配信を準備しています…（20 秒ほど）")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            case .playing(let player):
                PlayerController(player: player)
            case .failed(let message, let canRetry):
                VStack(spacing: 12) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    if canRetry {
                        Button("準備できていない配信を止めて、もう一度試す") {
                            Task {
                                await stream.stopStalled()
                                startSession()
                            }
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

    // MARK: - 配信

    private func startSession() {
        session?.cancel()
        let channel = channel
        session = Task { await run(channel) }
    }

    /// 前の配信を止めて、選んだ局の配信を頼み直す
    private func switchChannel(to newChannel: RegzaChannel) {
        guard newChannel != channel else { return }
        endSession()
        channel = newChannel
        startSession()
    }

    private func endSession() {
        session?.cancel()
        session = nil
        if case .playing(let player) = phase { player.pause() }
        phase = .preparing
        if let streamID {
            self.streamID = nil
            let server = server
            Task {
                if (try? await server.stop(streamID: streamID)) != nil { stream.stopped(streamID) }
            }
        }
    }

    private func run(_ channel: RegzaChannel) async {
        phase = .preparing
        guard let channelID = EPGStation.channelID(channelCode: channel.code) else {
            phase = .failed("このチャンネルは EPGStation で見られません。", canRetry: false)
            return
        }
        var requested: Int?
        do {
            // 前に止められずに残った、このアプリの配信を先に止める
            await stream.cleanUp()
            let streamID = try await server.startLiveStream(channelID: channelID)
            requested = streamID
            self.streamID = streamID
            stream.started(streamID)
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
            if let requested, streamID == requested {
                self.streamID = nil
                if (try? await server.stop(streamID: requested)) != nil { stream.stopped(requested) }
            }
            phase = .failed("""
                再生できませんでした。\(error.localizedDescription)
                EPGStation で同時に変換できる数の上限に達していると始まりません。ほかの画面で見ている配信を閉じるか、準備できないまま残っている配信を止めてから試してください。
                """, canRetry: true)
        }
    }
}

/// 見ている局の今の番組 (Mirakurun の番組表から)
private struct ProgramInfo: View {
    @Environment(GuideViewModel.self) private var guide
    let channel: RegzaChannel

    var body: some View {
        // 番組が変わったら表示も変える
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let program = guide.currentProgram(for: channel, at: context.date)
            VStack(alignment: .leading, spacing: 6) {
                Text(channel.name + (program == nil ? "" : " · 放送中"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(program?.name ?? channel.name)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let program {
                    HStack(spacing: 4) {
                        Text(program.start, format: .dateTime.hour().minute())
                        Text("〜")
                        Text(program.end, format: .dateTime.hour().minute())
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
    @Environment(RemoteViewModel.self) private var model
    @Environment(GuideViewModel.self) private var guide
    let current: RegzaChannel
    var onSelect: (RegzaChannel) -> Void

    /// EPGStation で見られる局 (Mirakurun が受信している局。番組表がまだなければ CS 以外)。サブチャンネルは代表だけ
    private var watchable: [RegzaChannel] {
        model.channels.filter { channel in
            guard channel.isRepresentative || channel.band == .cs else { return false }
            return guide.guidePrograms.isEmpty ? channel.band != .cs : guide.guidePrograms[channel.code] != nil
        }
    }

    private var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in watchable.contains { $0.band == band } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if bands.count > 1 {
                BandPicker(bands: bands)
            }
            let band = model.band(among: bands)
            ForEach(watchable.filter { $0.band == band }) { channel in
                Button {
                    onSelect(channel)
                } label: {
                    HStack(spacing: 12) {
                        Text(channel.formattedNumber)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.name)
                                .lineLimit(1)
                            if let program = guide.currentProgram(for: channel) {
                                Text(program.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if channel == current {
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
