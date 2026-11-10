#if os(iOS)
import RegzaDesign
import RegzaLiveActivity
import RegzaPresentation
import SwiftUI

/// アプリのルート画面。テレビを操作する「リモコン」と、見るための一覧 (番組表・チャンネル・録画予約) をタブで分ける。
/// ViewModel は組み立て (RegzaRemoteUI の RootView) が作って渡す。画面は state を読み、send で操作するだけにする
public struct AppScreen: View {
    @State private var app: AppViewModel
    @State private var liveActivity: LiveActivityModel
    /// 開発用: 起動してすぐ開くライブ視聴 (組み立てが、起動引数から作る)
    private let debugPlayer: LivePlayerViewModel?
    @Environment(\.scenePhase) private var scenePhase

    public init(app: AppViewModel, liveActivity: LiveActivityModel, debugPlayer: LivePlayerViewModel? = nil) {
        _app = State(initialValue: app)
        _liveActivity = State(initialValue: liveActivity)
        self.debugPlayer = debugPlayer
    }

    private var model: RemoteViewModel { app.remote }

    public var body: some View {
        Group {
            if model.state.isConfigured {
                TabView(selection: Binding(get: { app.state.tab }, set: { app.send(.selectTab($0)) })) {
                    NavigationStack {
                        RemoteScreen()
                            .navigationTitle("リモコン")
                            // ボタンを上に詰めるため、大きな見出しにしない
                            .navigationBarTitleDisplayMode(.inline)
                            // 本体が明るいグレーなので、見出しと時計を黒い文字にする
                            .toolbarColorScheme(.light, for: .navigationBar)
                            .toolbar { remoteToolbar }
                    }
                    // 本体が明るいグレーなので、右上のボタンなども明るい背景用の色にする
                    .environment(\.colorScheme, .light)
                    .tabItem { Label("リモコン", systemImage: "appletvremote.gen4.fill") }
                    .tag(AppViewModel.Tab.remote)

                    GuideGridScreen(viewModel: app.guideGrid)
                        .tabItem { Label("番組表", systemImage: "calendar") }
                        .tag(AppViewModel.Tab.guide)

                    ChannelListScreen(viewModel: app.channelList)
                        .tabItem { Label("チャンネル", systemImage: "list.bullet") }
                        .tag(AppViewModel.Tab.channels)

                    ReservationListScreen(viewModel: app.reservationList)
                        .tabItem { Label("録画予約", systemImage: "record.circle") }
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
                        Label("テレビが未設定です", systemImage: "tv.badge.wifi")
                    } description: {
                        Text("同じ Wi-Fi のテレビを探して、テレビに表示される PIN で登録してください")
                    } actions: {
                        Button("設定する") { app.send(.showSettings) }
                            .buttonStyle(.borderedProminent)
                    }
                    .toolbar { remoteToolbar }
                }
            }
        }
        .sheet(isPresented: Binding(get: { app.state.isShowingSettings }, set: { if !$0 { app.send(.closeSettings) } })) {
            if let settings = app.settings {
                SettingsScreen(settings: settings)
            }
        }
        // アプリで見る (ライブ視聴)。いま映っているものの詳細を開いているときは、そのシートの上から出す
        .fullScreenCover(
            isPresented: Binding(
                get: { app.state.playingChannelCode != nil && !app.state.isShowingNowPlaying },
                set: { if !$0 { app.send(.closePlayer) } }
            )
        ) {
            if let player = app.player {
                LivePlayerScreen(viewModel: player)
            }
        }
        // 開発用: 起動引数で指定したライブ視聴を、すぐ開く
        .fullScreenCover(isPresented: .constant(debugPlayer != nil)) {
            if let debugPlayer {
                LivePlayerScreen(viewModel: debugPlayer)
            }
        }
        .environment(app)
        .environment(model)
        .environment(liveActivity)
        .environment(\.showSettings, ShowSettingsAction { app.send(.showSettings) })
        .tint(AppTheme.accent)
        .sensoryFeedback(.impact(weight: .light), trigger: model.state.tapCount)
        .task {
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            await app.cleanUpStreams()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                model.send(.startPolling)
            } else {
                model.send(.stopPolling)
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
                app.send(.showSettings)
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("設定")
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
