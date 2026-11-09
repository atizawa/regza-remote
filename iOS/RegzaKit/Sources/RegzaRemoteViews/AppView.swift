#if os(iOS)
import RegzaLiveActivity
import RegzaPresentation
import SwiftUI

/// アプリのルート画面。テレビを操作する「リモコン」と、見るための一覧 (番組表・チャンネル・録画予約) をタブで分ける。
/// ViewModel は組み立て (RegzaRemoteUI の RemoteView) が作って渡す。画面は state を読み、send で操作するだけにする
public struct AppView: View {
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
                        RemotePanel()
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

                    GuideGridView(viewModel: app.guideGrid)
                        .tabItem { Label("番組表", systemImage: "calendar") }
                        .tag(AppViewModel.Tab.guide)

                    ChannelListView(viewModel: app.channelList)
                        .tabItem { Label("チャンネル", systemImage: "list.bullet") }
                        .tag(AppViewModel.Tab.channels)

                    ReservationsView(viewModel: app.reservationList)
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
                SettingsView(tv: settings.tv, servers: settings.servers)
            }
        }
        // アプリで見る (ライブ視聴)。いま映っているものの詳細を開いているときは、そのシートの上から出す
        .fullScreenCover(isPresented: Binding(
            get: { app.state.playingChannelCode != nil && !app.state.isShowingNowPlaying },
            set: { if !$0 { app.send(.closePlayer) } }
        )) {
            if let player = app.player {
                LivePlayerView(viewModel: player)
            }
        }
        // 開発用: 起動引数で指定したライブ視聴を、すぐ開く
        .fullScreenCover(isPresented: .constant(debugPlayer != nil)) {
            if let debugPlayer {
                LivePlayerView(viewModel: debugPlayer)
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

private struct RemotePanel: View {
    @Environment(RemoteViewModel.self) private var model
    @State private var isShowingMore = false

    var body: some View {
        ScrollView {
            // 実物のリモコンと同じく、電源 → 放送の種類と数字 → 十字キー・色ボタン → 再生 の順に並べる。
            // リモコンは手の感覚で押すので、再生中かどうかでボタンの位置を変えない
            // (再生が始まって並びが変わり、押そうとした場所に別のボタンが来て電源が切れたことがある)
            VStack(spacing: Design.group) {
                powerRow
                numberPanel
                navigationBand
                RemoteSection(title: "録画・再生") {
                    playbackPanel
                }
                moreSection
            }
            .padding(Design.outer)
        }
        .background(RemoteBody.background.ignoresSafeArea())
    }

    /// 十字キー・戻るなど・色ボタン。実物のリモコンと同じく、ここだけ端から端まで黒い帯にする
    private var navigationBand: some View {
        VStack(spacing: Design.item) {
            primaryControls
            navigationRow
            HStack(spacing: Design.item) {
                ColorKeyButton(key: .blue, color: .blue)
                ColorKeyButton(key: .red, color: .red)
                ColorKeyButton(key: .green, color: .green)
                ColorKeyButton(key: .yellow, color: .yellow)
            }
        }
        .padding(.vertical, Design.group)
        .padding(.horizontal, Design.outer)
        .environment(\.remoteKeyTone, .black)
        .background(RemoteBody.panel)
        .padding(.horizontal, -Design.outer)
    }

    /// 電源は誤って押さないよう左端に離し、入力切替・消音と並べる
    private var powerRow: some View {
        HStack(spacing: Design.item) {
            KeyButton(key: .power, isFilled: true)
                .frame(width: 88)
            Spacer(minLength: 0)
            KeyButton(key: .input, showsCaption: true)
                .frame(width: 88)
            KeyButton(key: .mute, showsCaption: true)
                .frame(width: 88)
        }
    }

    /// 音量・十字キー・チャンネル
    private var primaryControls: some View {
        HStack(alignment: .center, spacing: Design.item) {
            RockerControl(title: "音量", up: .volumeUp, down: .volumeDown)
                .frame(width: 64)
            DirectionPad(diameter: 196)
                .frame(maxWidth: .infinity)
            RockerControl(title: "CH", up: .channelUp, down: .channelDown,
                          upImage: "chevron.up", downImage: "chevron.down")
                .frame(width: 64)
        }
    }

    private var navigationRow: some View {
        HStack(spacing: Design.item) {
            KeyButton(key: .back, showsCaption: true)
            KeyButton(key: .guide, title: "テレビ番組表", showsCaption: true)
            KeyButton(key: .programInfo, title: "番組説明", showsCaption: true)
            KeyButton(key: .exit, showsCaption: true)
        }
    }

    /// 地デジ・BS・CS と 1〜12。テレビのリモコンと同じ 3 列
    private var numberPanel: some View {
        VStack(spacing: Design.item) {
            HStack(spacing: Design.item) {
                ForEach([RegzaKey.terrestrial, .bs, .cs]) { key in
                    KeyButton(key: key, size: .compact, isSelected: model.state.nowPlayingBand == key.band)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Design.item), count: 3),
                      spacing: Design.item) {
                ForEach(RegzaKey.numbers) { key in
                    KeyButton(key: key)
                }
            }
        }
    }

    private var playbackPanel: some View {
        VStack(spacing: Design.item) {
            HStack(spacing: Design.item) {
                KeyButton(key: .previousChapter, size: .primary)
                KeyButton(key: .skipBackward, size: .primary)
                KeyButton(key: model.state.nowPlaying?.isAdvancing == true ? .pause : .play, size: .primary)
                KeyButton(key: .skipForward, size: .primary)
                KeyButton(key: .nextChapter, size: .primary)
            }
            HStack(spacing: Design.item) {
                KeyButton(key: .rewind)
                KeyButton(key: .stop)
                KeyButton(key: .fastForward)
                KeyButton(key: .record, isDestructive: true)
            }
            HStack(spacing: Design.item) {
                KeyButton(key: .recordedList, size: .compact, showsIcon: false)
                KeyButton(key: .timeShift, size: .compact, showsIcon: false)
                KeyButton(key: .jumpToStart, size: .compact, showsIcon: false)
            }
        }
    }

    private var moreSection: some View {
        VStack(spacing: Design.item) {
            Button {
                withAnimation(.snappy) { isShowingMore.toggle() }
            } label: {
                HStack {
                    Text("その他の操作")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isShowingMore ? 180 : 0))
                }
                .foregroundStyle(.black.opacity(0.6))
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isShowingMore {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Design.item), count: 3),
                          spacing: Design.item) {
                    ForEach(Self.otherKeys) { key in
                        KeyButton(key: key, size: .compact, showsIcon: false)
                    }
                }
                .transition(.opacity)
            }
        }
    }


    static let otherKeys: [RegzaKey] = [
        .display, .audio, .subtitle, .dData, .miniGuide, .channelNumber,
        .radioData, .programSearch, .regzaMenu, .settings, .quick, .screenSize,
        .multiScreen, .broadband, .newsNow, .pageUp, .pageDown, .threeD,
    ]
}
#endif
