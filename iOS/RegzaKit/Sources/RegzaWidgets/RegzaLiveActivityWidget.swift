#if os(iOS)
import ActivityKit
import AppIntents
import RegzaDesign
import RegzaLiveActivity
import RegzaPresentation
import RegzaRemoteIntents
import SwiftUI
import WidgetKit

/// Dynamic Island とロック画面に再生中の番組とリモコンボタンを表示する。
public struct RegzaLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RegzaActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(AppTheme.activityBackground.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // 番組が終わる時刻にシステムが stale として描き直すので、そこで次の番組の表示に切り替わる
            let state = context.state.displayed(isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(state.headerName(tvName: context.attributes.tvName))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "tv")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    // 左上は角丸で削られるので内側に寄せる
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    TitleText(state: state, isStale: context.isStale)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 左右の領域は狭く再生時間が折り返すため、時間は進捗バーの両端に出す
                    VStack(spacing: 8) {
                        if state.hasTimeline, !state.hasProgramEnded(isStale: context.isStale) {
                            PlaybackBar(state: state)
                        }
                        ActivityButtons(state: state)
                    }
                }
            } compactLeading: {
                Image(systemName: "tv")
                    .foregroundStyle(AppTheme.accent)
            } compactTrailing: {
                // コンパクト表示の幅はシステムに制限されるので、少し縮小して文字数を稼ぐ
                Text(compactTitle(state))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 72)
            } minimal: {
                if state.hasTimeline, !state.hasProgramEnded(isStale: context.isStale) {
                    PlaybackProgress(state: state, circular: true)
                } else {
                    Image(systemName: "tv")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .keylineTint(AppTheme.accent)
        }
    }

    /// コンパクト表示の右側。番組名は数文字で切れて読めないので、短くした局名 (`NHK総合`。収まらなければ `4ch` `BS181`) を出す。
    /// 録画の再生中は「録画」
    private func compactTitle(_ state: RegzaActivityAttributes.ContentState) -> String {
        if state.isRecordingPlayback { return "録画" }
        if let shortChannel = state.shortChannel, !shortChannel.isEmpty { return shortChannel }
        return "REGZA"
    }
}

extension RegzaActivityAttributes.ContentState {
    /// 機種によっては放送中の番組名が返らないので、代わりにチャンネル名を見出しにする
    fileprivate var showsChannelAsTitle: Bool {
        title.isEmpty && kind == .broadcast && !channelName.isEmpty
    }

    /// 番組名・チャンネル名・入力などを見出しに出せるか (つながらないときは直前に取得した情報)
    fileprivate var hasInfoHeadline: Bool {
        !title.isEmpty || showsChannelAsTitle || kind == .external || kind == .standby
    }

    /// 放送中の番組が終わったか。システムは staleDate (番組の終了時刻) に stale として描き直すので、
    /// アプリが止まっていてもこの時点で表示が切り替わる
    fileprivate func hasProgramEnded(isStale: Bool) -> Bool {
        // displayed(isStale:) と同じく、stale になっていれば終了時刻を過ぎている
        isStale && isConnected && programEnd != nil && hasPredictedNextProgram != true
    }

    /// 見出しの上の小さなラベル。見出しと同じチャンネル名を重ねて出さない
    fileprivate func headerName(tvName: String) -> String {
        channelName.isEmpty || showsChannelAsTitle ? tvName : channelName
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<RegzaActivityAttributes>

    var body: some View {
        let state = context.state.displayed(isStale: context.isStale)
        VStack(alignment: .leading, spacing: 10) {
            Label(state.headerName(tvName: context.attributes.tvName), systemImage: "tv")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            TitleText(state: state, isStale: context.isStale)
                .font(.headline)
                .foregroundStyle(.white)
            if state.hasTimeline, !state.hasProgramEnded(isStale: context.isStale) {
                PlaybackBar(state: state)
            }
            ActivityButtons(state: state)
        }
        .padding()
    }
}

private struct TitleText: View {
    let state: RegzaActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !state.title.isEmpty {
                Text(state.title).lineLimit(2)
                if !state.chapterName.isEmpty {
                    Text(state.chapterName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if state.showsChannelAsTitle {
                Text(state.channelName).lineLimit(1)
                if let genre = state.genre, !genre.isEmpty {
                    // 番組名が取れない機種では、ジャンルで何の番組かを示す
                    Text(genre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if state.kind == .external {
                Text("外部入力")
            } else if state.kind == .standby {
                Text("待機中")
            } else if !state.isConnected {
                Text("テレビに接続できません")
            } else if let lastCommand = state.lastCommand {
                Text("\(lastCommand) を送信しました")
            } else {
                Text("リモコン")
            }
            if !state.isConnected, state.hasInfoHeadline {
                // 直前の情報を出しているときは、つながっていないことを小さく添える
                Label("テレビに接続できません", systemImage: "wifi.exclamationmark")
                    .font(.caption2)
                    // 警告なのでテーマの色ではなく黄色にする
                    .foregroundStyle(.yellow)
            }
            if state.hasProgramEnded(isStale: isStale) {
                // 次の番組が分からなかったとき
                Text("番組が終わりました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // 次の番組の表示に切り替えたときは、番組が変わる時刻で stale になっているだけなので出さない
            if isStale, state.hasPredictedNextProgram != true {
                Text("アプリを開くと最新の状態に更新されます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 録画: `経過時間 ━━━━ 番組の長さ`、放送: `開始時刻 ━━━━ 終了時刻`
private struct PlaybackBar: View {
    let state: RegzaActivityAttributes.ContentState

    var body: some View {
        if state.kind == .broadcast {
            let start = state.updatedAt.addingTimeInterval(-TimeInterval(state.position))
            HStack(spacing: 8) {
                Text(start, style: .time).fixedSize()
                PlaybackProgress(state: state)
                Text(start.addingTimeInterval(TimeInterval(state.duration)), style: .time).fixedSize()
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else {
            elapsedBar
        }
    }

    private var elapsedBar: some View {
        HStack(spacing: 8) {
            Group {
                if let interval = state.playbackInterval {
                    // タイマー表示は幅いっぱいに広がるので幅を固定する
                    Text(timerInterval: interval, countsDown: false)
                        .frame(width: 52, alignment: .leading)
                } else {
                    Text(state.position.formattedDuration)
                        .frame(width: 52, alignment: .leading)
                }
            }
            PlaybackProgress(state: state)
            Text(state.duration.formattedDuration)
                .fixedSize()
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct PlaybackProgress: View {
    let state: RegzaActivityAttributes.ContentState
    var circular = false

    var body: some View {
        Group {
            if let interval = state.playbackInterval {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.progress)
            }
        }
        .modifier(ProgressStyleModifier(circular: circular))
        .tint(AppTheme.accent)
    }
}

private struct ProgressStyleModifier: ViewModifier {
    let circular: Bool

    func body(content: Content) -> some View {
        if circular {
            content.progressViewStyle(.circular)
        } else {
            content.progressViewStyle(.linear)
        }
    }
}

private struct ActivityButtons: View {
    let state: RegzaActivityAttributes.ContentState

    /// 押しやすいよう数を絞る。待機中は電源だけ、録画は再生操作、放送はチャンネルと音量
    private var keys: [RegzaKey] {
        if state.kind == .standby { return [.power] }
        return state.isRecordingPlayback
            ? [.skipBackward, state.isAdvancing ? .pause : .play, .skipForward]
            : [.channelDown, .channelUp, .volumeDown, .volumeUp]
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(keys) { key in
                Button(intent: RegzaKeyIntent(key)) {
                    Group {
                        switch key {
                        case .channelUp: Text("CH＋")
                        case .channelDown: Text("CH−")
                        // 待機中に出す唯一のボタンなので、何をするか文字で添える
                        case .power: Label("電源を入れる", systemImage: "power")
                        default: Image(systemName: key.systemImage ?? "circle")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.15), in: Capsule())
                .accessibilityLabel(key.label)
            }
        }
        .foregroundStyle(.white)
    }
}
#endif
