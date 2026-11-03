#if os(iOS)
import RegzaCore
import SwiftUI

/// テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
struct ChannelListView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var band: RegzaChannel.Band = .terrestrial
    @State private var isLoading = false
    @State private var loadError: RegzaError?
    @State private var tuneError: String?
    /// 切り替え中のチャンネル
    @State private var tuning: RegzaChannel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("チャンネル")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
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
                .task { await load(force: false) }
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
            List {
                if bands.count > 1 {
                    Picker("放送", selection: $band) {
                        ForEach(bands, id: \.self) { band in
                            Text(band.label).tag(band)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if let tuneError {
                    Text(tuneError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Section {
                    ForEach(model.channels.filter { $0.band == band }) { channel in
                        row(channel)
                    }
                }
            }
        }
    }

    private func row(_ channel: RegzaChannel) -> some View {
        Button {
            Task { await tune(to: channel) }
        } label: {
            HStack(spacing: 12) {
                Text(channel.formattedNumber)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(channel.name)
                    // 同じ放送局のサブチャンネルは控えめに出す
                    .foregroundStyle(channel.isRepresentative || channel.band == .cs ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
                if tuning == channel {
                    ProgressView()
                } else if channel.code == model.nowPlaying?.channelCode {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .tint(.primary)
        .disabled(tuning != nil)
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
        // 開いたときは、いま映っているチャンネルの種類を選んでおく
        if let current = model.channels.first(where: { $0.code == model.nowPlaying?.channelCode }) {
            band = current.band
        } else if !bands.contains(band), let first = bands.first {
            band = first
        }
    }

    private func tune(to channel: RegzaChannel) async {
        tuning = channel
        defer { tuning = nil }
        tuneError = nil
        do {
            try await model.tune(to: channel)
            dismiss()
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
