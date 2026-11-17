#if os(iOS)
import Localization
import Design
import PresentationCore
import PlayerPresentation
import SwiftUI
import UICommon
#if DEBUG
import AppPresentation
#endif

/// ミニプレーヤーを押したときの詳細。録画ならシークもできる (組み立てがシートで出す)
package struct NowPlayingScreen: View {
    let viewModel: NowPlayingViewModel
    @Environment(\.appNavigator) private var navigator
    @Environment(\.dismiss) private var dismiss

    package init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel
    }

    package var body: some View {
        let state = viewModel.state
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignDimensions.spacingGroup) {
                    NowPlayingCard()
                    if let description = state.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    if state.canPowerOn {
                        actionButton(AppStrings.remotePowerOn, systemImage: "power") { viewModel.send(.powerOn) }
                    }
                    if let code = state.playableChannelCode {
                        actionButton(AppStrings.playerWatch, systemImage: "play.tv") { navigator.play(channelCode: code) }
                    }
                    if state.canStartOver {
                        actionButton(AppStrings.playerProgramFromStart, systemImage: "backward.end.alt") { viewModel.send(.startOver) }
                    }
                    LiveActivityToggle()
                        .padding(DesignDimensions.spacingOuter)
                        .background(
                            Surface.button, in: RoundedRectangle(cornerRadius: DesignDimensions.shapeCornerRadius, style: .continuous))
                }
                .padding(DesignDimensions.spacingOuter)
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
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: DesignDimensions.buttonRegularHeight)
        }
        .buttonStyle(RemoteButtonStyle())
    }
}

#if DEBUG
#Preview("視聴中の詳細") {
    FakePreview(
        setUp: { app in
            app.remoteViewModel.send(.refresh)
            await app.settle()
            app.send(.showNowPlaying)
        },
        content: { app in
            NowPlayingScreen(viewModel: app.nowPlayingViewModel)
        })
}
#endif
#endif
