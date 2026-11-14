#if os(iOS)
import Localization
import Design
import LiveActivity
import RegzaPresentation
import SwiftUI

/// アプリのルート画面。テレビを操作する「リモコン」と、見るための一覧 (番組表・チャンネル・録画予約) をタブで分ける。
/// ViewModel は組み立て (アプリ側の RootView) が作って渡す。画面は state を読み、send で操作するだけにする
public struct AppScreen: View {
    @State private var appViewModel: AppViewModel
    @State private var liveActivity: LiveActivityModel
    /// 開発用: 起動してすぐ開くライブ視聴 (組み立てが、起動引数から作る)
    private let debugPlayerViewModel: LivePlayerViewModel?
    @Environment(\.scenePhase) private var scenePhase

    public init(appViewModel: AppViewModel, liveActivity: LiveActivityModel, debugPlayerViewModel: LivePlayerViewModel? = nil) {
        _appViewModel = State(initialValue: appViewModel)
        _liveActivity = State(initialValue: liveActivity)
        self.debugPlayerViewModel = debugPlayerViewModel
    }

    private var remoteViewModel: RemoteViewModel { appViewModel.remoteViewModel }

    public var body: some View {
        Group {
            if remoteViewModel.state.isConfigured {
                TabView(selection: Binding(get: { appViewModel.state.tab }, set: { appViewModel.send(.selectTab($0)) })) {
                    NavigationStack {
                        RemoteScreen()
                            .navigationTitle(AppStrings.tabRemote)
                            // ボタンを上に詰めるため、大きな見出しにしない
                            .navigationBarTitleDisplayMode(.inline)
                            // 本体が明るいグレーなので、見出しと時計を黒い文字にする
                            .toolbarColorScheme(.light, for: .navigationBar)
                            .toolbar { remoteToolbar }
                    }
                    // 本体が明るいグレーなので、右上のボタンなども明るい背景用の色にする
                    .environment(\.colorScheme, .light)
                    .tabItem { Label(AppStrings.tabRemote, systemImage: "appletvremote.gen4.fill").accessibilityIdentifier("tab.remote") }
                    .tag(AppViewModel.Tab.remote)

                    GuideGridScreen(viewModel: appViewModel.guideGridViewModel)
                        .tabItem { Label(AppStrings.tabGuide, systemImage: "calendar").accessibilityIdentifier("tab.guide") }
                        .tag(AppViewModel.Tab.guide)

                    ChannelListScreen(viewModel: appViewModel.channelListViewModel)
                        .tabItem { Label(AppStrings.tabChannels, systemImage: "list.bullet").accessibilityIdentifier("tab.channels") }
                        .tag(AppViewModel.Tab.channels)

                    ReservationListScreen(viewModel: appViewModel.reservationListViewModel)
                        .tabItem {
                            Label(AppStrings.tabReservations, systemImage: "record.circle").accessibilityIdentifier("tab.reservations")
                        }
                        .tag(AppViewModel.Tab.reservations)
                }
                // どのタブでも、テレビで映っているものをミニプレーヤーで出す
                .tabViewBottomAccessory {
                    NowPlayingAccessory()
                }
                // 番組表や一覧を広く見せるため、下へスクロールしたらタブバーを小さくする
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                NavigationStack {
                    ContentUnavailableView {
                        Label(AppStrings.remoteUnconfigured, systemImage: "tv.badge.wifi")
                    } description: {
                        Text(AppStrings.remoteSetupHelp)
                    } actions: {
                        Button(AppStrings.commonConfigure) { appViewModel.send(.showSettings) }
                            .buttonStyle(.borderedProminent)
                    }
                    .toolbar { remoteToolbar }
                }
            }
        }
        .sheet(isPresented: Binding(get: { appViewModel.state.isShowingSettings }, set: { if !$0 { appViewModel.send(.closeSettings) } })) {
            if let settingsViewModel = appViewModel.settingsViewModel {
                SettingsScreen(settingsViewModel: settingsViewModel)
            }
        }
        // アプリで見る (ライブ視聴)。いま映っているものの詳細を開いているときは、そのシートの上から出す
        .fullScreenCover(
            isPresented: Binding(
                get: { appViewModel.state.playingChannelCode != nil && !appViewModel.state.isShowingNowPlaying },
                set: { if !$0 { appViewModel.send(.closePlayer) } }
            )
        ) {
            if let livePlayerViewModel = appViewModel.livePlayerViewModel {
                LivePlayerScreen(viewModel: livePlayerViewModel)
            }
        }
        // 開発用: 起動引数で指定したライブ視聴を、すぐ開く
        .fullScreenCover(isPresented: .constant(debugPlayerViewModel != nil)) {
            if let debugPlayerViewModel {
                LivePlayerScreen(viewModel: debugPlayerViewModel)
            }
        }
        .environment(appViewModel)
        .environment(remoteViewModel)
        .environment(liveActivity)
        .environment(\.showSettings, ShowSettingsAction { appViewModel.send(.showSettings) })
        .tint(AppTheme.accent)
        .sensoryFeedback(.impact(weight: .light), trigger: remoteViewModel.state.tapCount)
        .task {
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            await appViewModel.cleanUpStreams()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                remoteViewModel.send(.startPolling)
            } else {
                remoteViewModel.send(.stopPolling)
                // 閉じている間も Live Activity を更新できるよう、iOS に起こしてもらう時刻を予約する
                if phase == .background { liveActivity.scheduleBackgroundRefresh() }
            }
        }
    }

    @ToolbarContentBuilder
    private var remoteToolbar: some ToolbarContent {
        // Live Activity のオン・オフはアイコンだけでは分かりにくいので、視聴中の画面と設定画面のスイッチにしている
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                appViewModel.send(.showSettings)
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(AppStrings.settingsTitle)
            .accessibilityIdentifier("settings.open")
        }
    }
}

/// 設定画面を開く
struct ShowSettingsAction {
    let action: @MainActor () -> Void
    @MainActor func callAsFunction() { action() }
}

extension EnvironmentValues {
    @Entry var showSettings = ShowSettingsAction {}
}
#endif
