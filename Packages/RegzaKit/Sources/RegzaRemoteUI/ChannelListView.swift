#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
struct ChannelListView: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var isLoading = false
    @State private var loadError: RegzaError?
    @State private var tuneError: String?
    /// 切り替え中のチャンネル
    @State private var tuning: RegzaChannel?
    /// 番組表を開いているチャンネル
    @State private var guideChannel: RegzaChannel?
    /// アプリで見ているチャンネル
    @State private var playerChannel: RegzaChannel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("チャンネル")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await load(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("読み込み直す")
                        .disabled(isLoading)
                    }
                }
                .navigationDestination(item: $guideChannel) { channel in
                    ChannelProgramsView(channel: channel)
                }
                .fullScreenCover(item: $playerChannel) { channel in
                    if let server = model.streamServer() {
                        LivePlayerView(server: server, channel: channel)
                    }
                }
                .task {
                    await load(force: false)
                    await model.loadGuidePrograms()
                    // 長押しのメニューに「最初から見る」を出すかを決めるため
                    await model.loadTimeshiftSettings()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError, model.channels.isEmpty {
            ContentUnavailableView {
                Label("チャンネルを取得できません", systemImage: "list.bullet.rectangle")
            } description: {
                Text(message(for: loadError))
            } actions: {
                Button("もう一度試す") { Task { await load(force: true) } }
            }
        } else if model.channels.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if bands.count > 1 {
                    BandPicker(bands: bands)
                }
                list
            }
        }
    }

    private var list: some View {
        List {
            if let tuneError {
                Text(tuneError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Section {
                let band = model.band(among: bands)
                ForEach(channels(in: band)) { channel in
                    row(channel)
                }
            }
        }
    }

    private func row(_ channel: RegzaChannel) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await tune(to: channel) }
            } label: {
                HStack(spacing: 12) {
                    Text(channel.formattedNumber)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.name)
                            // 同じ放送局のサブチャンネルは控えめに出す
                            .foregroundStyle(channel.isRepresentative || channel.band == .cs ? .primary : .secondary)
                            .lineLimit(1)
                        if let program = model.currentProgram(for: channel) {
                            Text(program.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if tuning == channel {
                        ProgressView()
                    } else if channel.code == model.nowPlaying?.channelCode {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityLabel("視聴中")
                    }
                }
                .contentShape(Rectangle())
            }
            // 行の中に 2 つのボタンがあるので、行全体ではなくそれぞれが押されるようにする
            .buttonStyle(.borderless)
            .tint(.primary)
            .disabled(tuning != nil)
            if model.hasGuide, model.guidePrograms[channel.code] != nil {
                Button {
                    guideChannel = channel
                } label: {
                    Image(systemName: "calendar")
                        // ボタンの色 (緑) が混ざらないよう、灰色に固定する
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(channel.name) の番組表")
            }
        }
        // 押すとすぐ切り替わるので、切り替え以外は長押しのメニューにまとめる
        .contextMenu { menu(for: channel) }
    }

    @ViewBuilder
    private func menu(for channel: RegzaChannel) -> some View {
        Button("切り替える", systemImage: "play.fill") {
            Task { await tune(to: channel) }
        }
        if model.canStream {
            Button("アプリで見る", systemImage: "play.tv") {
                playerChannel = channel
            }
        }
        if let program = model.currentProgram(for: channel),
           model.canStartOver(channelCode: channel.code, programStart: program.start) {
            Button("最初から見る", systemImage: "backward.end.alt") {
                Task { await tune(to: channel, startOver: true) }
            }
        }
        if model.hasGuide, model.guidePrograms[channel.code] != nil {
            Button("番組表", systemImage: "calendar") {
                guideChannel = channel
            }
        }
    }

    /// 一覧に出すチャンネル。同じ局のサブチャンネルはふだん同じ番組なので、番組表と同じく局ごとにまとめ、
    /// 代表と違う番組を流しているときと、いま見ているときだけ出す
    private func channels(in band: RegzaChannel.Band?) -> [RegzaChannel] {
        let channels = model.channels.filter { $0.band == band }
        // CS はテレビから代表の印が来ないので、すべて出す
        guard band != .cs else { return channels }
        // リモコン番号ごとの代表。印のあるものを先に見て、なければ最初のもの
        var representatives: [Int: RegzaChannel] = [:]
        for channel in channels.filter(\.isRepresentative) + channels.filter({ !$0.isRepresentative })
        where channel.remoteNumber > 0 && representatives[channel.remoteNumber] == nil {
            representatives[channel.remoteNumber] = channel
        }
        return channels.filter { channel in
            guard channel.remoteNumber > 0, let representative = representatives[channel.remoteNumber],
                  representative != channel, channel.code != model.nowPlaying?.channelCode
            else { return true }
            // 番組名が分からなければ (Mirakurun が未設定など)、代表だけを出す
            guard let program = model.currentProgram(for: channel)?.name,
                  let representativeProgram = model.currentProgram(for: representative)?.name
            else { return false }
            return program != representativeProgram
        }
    }

    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    private var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in model.channels.contains { $0.band == band } }
    }

    private func load(force: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await model.loadChannels(force: force)
            loadError = nil
        } catch {
            loadError = error
        }
        // 放送の種類を選んでいなければ RemoteViewModel.band(among:) がいま見ている種類を選ぶ
    }

    private func tune(to channel: RegzaChannel, startOver: Bool = false) async {
        tuning = channel
        defer { tuning = nil }
        tuneError = nil
        do {
            // タブは移らない。切り替えたことはチェックの印とミニプレーヤーで分かる
            if !startOver {
                try await model.tune(to: channel)
            } else if channel.code == model.nowPlaying?.channelCode {
                model.startOver()
            } else {
                try await model.tuneAndStartOver(channel)
            }
        } catch .commandRejected {
            tuneError = "\(channel.name) に切り替えられませんでした。テレビの電源が入っているか確認してください。"
        } catch {
            tuneError = error.localizedDescription
        }
    }

    private func message(for error: RegzaError) -> String {
        switch error {
        case .httpStatus(404), .unsupported:
            "この機種はチャンネル一覧の取得に対応していません。"
        default:
            error.localizedDescription
        }
    }
}
#endif
