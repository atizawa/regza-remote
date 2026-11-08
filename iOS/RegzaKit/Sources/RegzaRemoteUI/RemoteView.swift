#if os(iOS)
import RegzaApp
import RegzaSample
import RegzaLiveActivity
import SwiftUI

/// アプリのルート画面。テレビを操作する「リモコン」と、見るための一覧 (番組表・チャンネル・録画予約) をタブで分ける
public struct RemoteView: View {
    @State private var app: AppViewModel
    @State private var liveActivity: LiveActivityModel
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        // Live Activity のボタン (App Intents) と同じ保存先とリモコンを使う
        var app = AppViewModel(store: RegzaRemoteService.store, remote: RegzaRemoteService.remote)
        #if DEBUG
        // 開発用: 起動引数 -SampleData YES で、テレビにつながない見本の Repository で組み立てる
        if SampleData.isEnabled { app = SampleData.makeApp() }
        #endif
        let liveActivity = LiveActivityModel(remote: app.remote)
        app.remote.observer = liveActivity
        #if DEBUG
        if let tab = SampleData.initialTab { app.send(.selectTab(tab)) }
        // 開発用: 起動引数 -ShowSettings YES で設定画面を開いておく
        if UserDefaults.standard.bool(forKey: "ShowSettings") { app.send(.showSettings) }
        #endif
        _app = State(initialValue: app)
        _liveActivity = State(initialValue: liveActivity)
    }

    private var model: RemoteViewModel { app.remote }

    public var body: some View {
        Group {
            if model.state.connection.isConfigured {
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
            get: { app.state.playingChannel != nil && !app.state.isShowingNowPlaying },
            set: { if !$0 { app.send(.closePlayer) } }
        )) {
            if let player = app.player {
                LivePlayerView(viewModel: player)
            }
        }
        #if DEBUG
        // 開発用: 起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で、すぐ再生画面を開く
        .fullScreenCover(isPresented: .constant(DebugLive.channel != nil)) {
            if let host = DebugLive.host, let channel = DebugLive.channel {
                LivePlayerView(viewModel: DebugLive.player(host: host, channel: channel, app: app))
            }
        }
        #endif
        .environment(app)
        .environment(model)
        .environment(liveActivity)
        .environment(\.showSettings, ShowSettingsAction { app.send(.showSettings) })
        .tint(AppTheme.accent)
        .sensoryFeedback(.impact(weight: .light), trigger: model.state.tapCount)
        .task {
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            await app.stream.cleanUp()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // 終了するときも止めてみる (届かなければ次に開いたときに止める)
            if app.stream.canStream {
                let store = RegzaRemoteService.store
                let server = EPGStation(host: store.streamHost)
                let semaphore = DispatchSemaphore(value: 0)
                Task.detached {
                    await EPGStationStreamRepository.cleanUp(server, store: store)
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 2)
            }
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
                    KeyButton(key: key, size: .compact, isSelected: currentBand == band(for: key))
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

    /// いま見ている放送の種類 (チャンネル一覧から分かるときだけ)
    private var currentBand: RegzaChannel.Band? {
        guard let code = model.state.nowPlaying?.channelCode, !code.isEmpty else { return nil }
        return model.state.channels.first { $0.code == code }?.band
    }

    private func band(for key: RegzaKey) -> RegzaChannel.Band? {
        switch key {
        case .terrestrial: .terrestrial
        case .bs: .bs
        case .cs: .cs
        default: nil
        }
    }

    static let otherKeys: [RegzaKey] = [
        .display, .audio, .subtitle, .dData, .miniGuide, .channelNumber,
        .radioData, .programSearch, .regzaMenu, .settings, .quick, .screenSize,
        .multiScreen, .broadband, .newsNow, .pageUp, .pageDown, .threeD,
    ]
}
#if DEBUG
private enum DebugLive {
    static var host: String? { UserDefaults.standard.string(forKey: "LiveHost") }
    static var channel: RegzaChannel? {
        guard let code = UserDefaults.standard.string(forKey: "LiveChannel") else { return nil }
        let json = #"[{"channel":"\#(code)","name":"確認用","channel_number":1}]"#
        return (try? JSONDecoder().decode([RegzaChannel].self, from: Data(json.utf8)))?.first
    }

    /// 確かめたい EPGStation につなぐライブ視聴 (保存してある設定は変えない)
    @MainActor
    static func player(host: String, channel: RegzaChannel, app: AppViewModel) -> LivePlayerViewModel {
        // EPGStation は番組表を設定しているときだけ使うので、見本の番組表を設定済みにしておく
        let guide = SampleGuideRepository(guideHost: "確認用", programs: [])
        let stream = StreamUseCase(stream: EPGStationStreamRepository(store: DebugStore(streamHost: host), guide: guide))
        return LivePlayerViewModel(remote: app.remote, guide: app.guide, stream: stream, channel: channel)
    }
}

/// 確認用のライブ視聴だけで使う、保存しない保存先
private final class DebugStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [Int] = []
    let streamHostValue: String

    init(streamHost: String) {
        streamHostValue = streamHost
    }

    func load() -> RegzaConnection { RegzaConnection() }
    func save(_ connection: RegzaConnection) {}
    func pairingUserID() -> String { "" }

    var guideHost: String {
        get { "" }
        set {}
    }

    var streamHost: String {
        get { streamHostValue }
        set {}
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { streams } }
        set { lock.withLock { streams = newValue } }
    }
}
#endif
#endif
