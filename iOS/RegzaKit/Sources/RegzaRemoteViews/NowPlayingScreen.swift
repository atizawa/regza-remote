#if os(iOS)
import RegzaDesign
import RegzaPresentation
import SwiftUI

/// ミニプレーヤーを押したときの詳細。録画ならシークもできる
struct NowPlayingScreen: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let viewModel = appViewModel.nowPlayingViewModel
        let state = viewModel.state
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.group) {
                    NowPlayingCard()
                    if let description = state.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    if state.canPowerOn {
                        actionButton("電源を入れる", systemImage: "power") { viewModel.send(.powerOn) }
                    }
                    if let code = state.playableChannelCode {
                        actionButton("アプリで見る", systemImage: "play.tv") { appViewModel.send(.play(channelCode: code)) }
                    }
                    if state.canStartOver {
                        actionButton("この番組を最初から見る", systemImage: "backward.end.alt") { viewModel.send(.startOver) }
                    }
                    LiveActivityToggle()
                        .padding(Design.outer)
                        .background(Surface.button, in: RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))
                }
                .padding(Design.outer)
            }
            .background(Surface.background)
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 閉じるだけの画面は、iOS 標準の × のボタンにそろえる
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .onAppear { viewModel.send(.appear) }
            // このシートを開いている間は、アプリで見る画面をシートの上から出す
            .fullScreenCover(
                isPresented: Binding(
                    get: { appViewModel.state.playingChannelCode != nil },
                    set: { if !$0 { appViewModel.send(.closePlayer) } }
                )
            ) {
                if let livePlayerViewModel = appViewModel.livePlayerViewModel {
                    LivePlayerScreen(viewModel: livePlayerViewModel)
                }
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Design.regularHeight)
        }
        .buttonStyle(RemoteButtonStyle())
    }
}
#endif
