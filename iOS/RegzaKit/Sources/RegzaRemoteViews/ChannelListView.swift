#if os(iOS)
import RegzaPresentation
import RegzaLiveActivity
import SwiftUI

/// テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
struct ChannelListView: View {
    @State private var viewModel: ChannelListViewModel
    @Environment(AppViewModel.self) private var app

    init(viewModel: ChannelListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let state = viewModel.state
        NavigationStack(path: app.path(of: .channels)) {
            content(state)
                .navigationTitle("チャンネル")
                // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.send(.reload)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("読み込み直す")
                        .disabled(state.isLoading)
                    }
                }
                .appRoutes()
                .task { viewModel.send(.appear) }
        }
    }

    @ViewBuilder
    private func content(_ state: ChannelListViewModel.State) -> some View {
        if let message = state.loadErrorMessage {
            ContentUnavailableView {
                Label("チャンネルを取得できません", systemImage: "list.bullet.rectangle")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { viewModel.send(.reload) }
            }
        } else if state.hasNoChannels {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if state.bands.count > 1 {
                    BandPicker(bands: state.bands, selected: state.band)
                }
                list(state)
            }
        }
    }

    private func list(_ state: ChannelListViewModel.State) -> some View {
        List {
            if let tuneError = state.tuneError {
                Text(tuneError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Section {
                ForEach(state.rows) { row in
                    self.row(row, state: state)
                }
            }
        }
    }

    private func row(_ row: ChannelItem, state: ChannelListViewModel.State) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.send(.tune(row.code))
            } label: {
                HStack(spacing: 12) {
                    Text(row.numberText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            // 同じ放送局のサブチャンネルは控えめに出す
                            .foregroundStyle(row.isSubchannel ? .secondary : .primary)
                            .lineLimit(1)
                        if let programName = row.programName {
                            Text(programName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if state.tuningCode == row.code {
                        ProgressView()
                    } else if row.isNowPlaying {
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
            .disabled(state.tuningCode != nil)
            if row.hasPrograms {
                Button {
                    app.send(.open(.channelPrograms(channelCode: row.code)))
                } label: {
                    Image(systemName: "calendar")
                        // ボタンの色 (緑) が混ざらないよう、灰色に固定する
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(row.name) の番組表")
            }
        }
        // 押すとすぐ切り替わるので、切り替え以外は長押しのメニューにまとめる
        .contextMenu { menu(for: row, state: state) }
    }

    @ViewBuilder
    private func menu(for row: ChannelItem, state: ChannelListViewModel.State) -> some View {
        Button("切り替える", systemImage: "play.fill") {
            viewModel.send(.tune(row.code))
        }
        if state.canStream {
            Button("アプリで見る", systemImage: "play.tv") {
                app.send(.play(channelCode: row.code))
            }
        }
        if row.canStartOver {
            Button("最初から見る", systemImage: "backward.end.alt") {
                viewModel.send(.tuneFromStart(row.code))
            }
        }
        if row.hasPrograms {
            Button("番組表", systemImage: "calendar") {
                app.send(.open(.channelPrograms(channelCode: row.code)))
            }
        }
    }
}
#endif
