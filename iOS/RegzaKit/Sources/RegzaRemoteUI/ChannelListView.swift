#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
struct ChannelListView: View {
    @State private var viewModel: ChannelListViewModel
    @Environment(ReservationsViewModel.self) private var recording
    /// 開いている画面 (チャンネルの番組表 → 番組の詳細)。番組の詳細は値で開くので、番組表も同じ順番に積む
    @State private var path = NavigationPath()
    /// アプリで見ているチャンネル
    @State private var playerChannel: RegzaChannel?

    init(viewModel: ChannelListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("チャンネル")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await viewModel.load(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("読み込み直す")
                        .disabled(viewModel.isLoading)
                    }
                }
                .navigationDestination(for: RegzaChannel.self) { channel in
                    ChannelProgramsView(viewModel: ProgramListViewModel(
                        guide: viewModel.guide, recording: recording, channel: channel
                    ))
                }
                .fullScreenCover(item: $playerChannel) { channel in
                    if let player = viewModel.stream.livePlayer(for: channel) {
                        LivePlayerView(viewModel: player)
                    }
                }
                .task { await viewModel.appear() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.loadErrorMessage {
            ContentUnavailableView {
                Label("チャンネルを取得できません", systemImage: "list.bullet.rectangle")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { Task { await viewModel.load(force: true) } }
            }
        } else if viewModel.remote.channels.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if viewModel.bands.count > 1 {
                    BandPicker(bands: viewModel.bands)
                }
                list
            }
        }
    }

    private var list: some View {
        List {
            if let tuneError = viewModel.tuneError {
                Text(tuneError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Section {
                ForEach(viewModel.channels) { channel in
                    row(channel)
                }
            }
        }
    }

    private func row(_ channel: RegzaChannel) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.tune(to: channel) }
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
                        if let programName = viewModel.programName(for: channel) {
                            Text(programName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if viewModel.tuning == channel {
                        ProgressView()
                    } else if viewModel.isNowPlaying(channel) {
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
            .disabled(viewModel.tuning != nil)
            if viewModel.hasPrograms(channel) {
                Button {
                    path.append(channel)
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
            Task { await viewModel.tune(to: channel) }
        }
        if viewModel.canStream {
            Button("アプリで見る", systemImage: "play.tv") {
                playerChannel = channel
            }
        }
        if viewModel.canStartOver(channel) {
            Button("最初から見る", systemImage: "backward.end.alt") {
                Task { await viewModel.tune(to: channel, startOver: true) }
            }
        }
        if viewModel.hasPrograms(channel) {
            Button("番組表", systemImage: "calendar") {
                path.append(channel)
            }
        }
    }
}
#endif
