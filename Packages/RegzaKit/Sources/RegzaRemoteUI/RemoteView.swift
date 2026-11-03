#if os(iOS)
import RegzaCore
import SwiftUI

/// アプリのルート画面
public struct RemoteView: View {
    @State private var model = RemoteViewModel()
    @State private var isShowingSettings = false
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if model.connection.isConfigured {
                    RemotePanel()
                } else {
                    ContentUnavailableView {
                        Label("テレビが未設定です", systemImage: "tv.badge.wifi")
                    } description: {
                        Text("REGZA の IP アドレスを入力し、テレビに表示される PIN で登録してください")
                    } actions: {
                        Button("設定する") { isShowingSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("REGZA")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.connection.isConfigured {
                        Button {
                            Task { await model.setLiveActivity(!model.isLiveActivityOn) }
                        } label: {
                            Image(systemName: model.isLiveActivityOn ? "capsule.fill" : "capsule")
                        }
                        .accessibilityLabel(model.isLiveActivityOn ? "Dynamic Island 表示を終了" : "Dynamic Island に表示")
                    }
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
        .environment(model)
        .tint(.orange)
        .sensoryFeedback(.impact(weight: .light), trigger: model.tapCount)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                model.startPolling()
            } else {
                model.stopPolling()
                // 閉じている間も Live Activity を更新できるよう、iOS に起こしてもらう時刻を予約する
                if phase == .background { model.scheduleBackgroundRefresh() }
            }
        }
    }
}

private struct RemotePanel: View {
    @State private var isShowingChannels = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                NowPlayingCard()

                HStack(spacing: 10) {
                    KeyButton(key: .power, tint: .red)
                    KeyButton(key: .input)
                    KeyButton(key: .mute)
                }

                HStack(spacing: 10) {
                    KeyButton(key: .terrestrial)
                    KeyButton(key: .bs)
                    KeyButton(key: .cs)
                    Button {
                        isShowingChannels = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(RemoteButtonStyle())
                    .accessibilityLabel("チャンネル一覧")
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(RegzaKey.numbers) { key in
                        KeyButton(key: key)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    RockerControl(title: "音量", up: .volumeUp, down: .volumeDown)
                        .frame(width: 72)
                    DirectionPad()
                        .frame(maxWidth: .infinity)
                    RockerControl(title: "CH", up: .channelUp, down: .channelDown,
                                  upImage: "chevron.up", downImage: "chevron.down")
                        .frame(width: 72)
                }

                HStack(spacing: 10) {
                    KeyButton(key: .back)
                    KeyButton(key: .guide)
                    KeyButton(key: .programInfo)
                    KeyButton(key: .exit)
                }

                HStack(spacing: 10) {
                    KeyButton(key: .blue, title: " ", tint: .blue)
                    KeyButton(key: .red, title: " ", tint: .red)
                    KeyButton(key: .green, title: " ", tint: .green)
                    KeyButton(key: .yellow, title: " ", tint: .yellow)
                }

                RemoteSection(title: "録画・再生") {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            KeyButton(key: .previousChapter)
                            KeyButton(key: .skipBackward)
                            KeyButton(key: .play)
                            KeyButton(key: .pause)
                            KeyButton(key: .skipForward)
                            KeyButton(key: .nextChapter)
                        }
                        HStack(spacing: 10) {
                            KeyButton(key: .rewind)
                            KeyButton(key: .stop)
                            KeyButton(key: .fastForward)
                            KeyButton(key: .record, tint: .red)
                        }
                        HStack(spacing: 10) {
                            KeyButton(key: .recordedList, showsIcon: false)
                            KeyButton(key: .timeShift, showsIcon: false)
                            KeyButton(key: .jumpToStart, showsIcon: false)
                        }
                    }
                }

                RemoteSection(title: "その他") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(Self.otherKeys) { key in
                            KeyButton(key: key, showsIcon: false)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $isShowingChannels) {
            ChannelListView()
        }
    }

    static let otherKeys: [RegzaKey] = [
        .display, .audio, .subtitle, .dData, .miniGuide, .channelNumber,
        .radioData, .programSearch, .regzaMenu, .settings, .quick, .screenSize,
        .multiScreen, .broadband, .newsNow, .pageUp, .pageDown, .threeD,
    ]
}
#endif
