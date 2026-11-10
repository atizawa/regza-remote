#if os(iOS)
import RegzaDesign
import RegzaPresentation
import SwiftUI

/// リモコンの画面。実物の REGZA のリモコンと同じ並びでボタンを出し、押したキーをテレビに送る
struct RemoteScreen: View {
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
