#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
struct ChannelListView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.showRemote) private var showRemote
    @State private var isLoading = false
    @State private var loadError: RegzaError?
    @State private var tuneError: String?
    /// 切り替え中のチャンネル
    @State private var tuning: RegzaChannel?
    /// 番組表を開いているチャンネル
    @State private var guideChannel: RegzaChannel?

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
                    ChannelProgramsView(channel: channel) {
                        guideChannel = nil
                        showRemote()
                    }
                }
                .task {
                    await load(force: false)
                    await model.loadGuidePrograms()
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
                ForEach(model.channels.filter { $0.band == band }) { channel in
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

    private func tune(to channel: RegzaChannel) async {
        tuning = channel
        defer { tuning = nil }
        tuneError = nil
        do {
            try await model.tune(to: channel)
            showRemote()
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
