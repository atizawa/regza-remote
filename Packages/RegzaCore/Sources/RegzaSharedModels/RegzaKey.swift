import Foundation
internal import RegzaStrings

/// REGZA のリモコンのキー (UI で使う形)。画面に出す名前とアイコンを持つ。
/// 値はキーの名前 (`power` など)。テレビに送るキーコードへの変換は Infrastructure がする (RegzaKey+Code)
public enum RegzaKey: String, CaseIterable, Identifiable, Sendable {
    // 数字
    case num1, num2, num3, num4
    case num5, num6, num7, num8
    case num9, num10, num11, num12

    // 基本
    case input
    case mute
    case power
    case audio
    case volumeUp
    case channelUp
    case display
    case volumeDown
    case channelDown
    case broadband
    case quick
    case multiScreen
    case screenSize

    // カーソル
    case back
    case exit
    case enter
    case up
    case down
    case right
    case left

    // 番組
    case channelNumber
    case radioData
    case guide
    case programInfo
    case miniGuide

    // カラー
    case blue, red, green, yellow

    // 放送切替
    case terrestrial
    case bs
    case cs

    // 録画・再生
    case pause
    case record
    case pageUp
    case pageDown
    case skipForward
    case skipBackward
    case nextChapter
    case previousChapter
    case recordedList
    case newsNow
    case stop
    case rewind
    case play
    case fastForward
    case timeShift
    case jumpToStart

    // メニュー
    case settings
    case regzaMenu
    case programSearch
    case threeD
    case dData
    case subtitle

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .num1: "1"
        case .num2: "2"
        case .num3: "3"
        case .num4: "4"
        case .num5: "5"
        case .num6: "6"
        case .num7: "7"
        case .num8: "8"
        case .num9: "9"
        case .num10: "10"
        case .num11: "11"
        case .num12: "12"
        case .input: CoreStrings.keyInput
        case .mute: CoreStrings.keyMute
        case .power: CoreStrings.keyPower
        case .audio: CoreStrings.keyAudio
        case .volumeUp: CoreStrings.keyVolumeUp
        case .channelUp: CoreStrings.keyChannelUp
        case .display: CoreStrings.keyDisplay
        case .volumeDown: CoreStrings.keyVolumeDown
        case .channelDown: CoreStrings.keyChannelDown
        case .broadband: CoreStrings.keyBroadband
        case .quick: CoreStrings.keyQuick
        case .multiScreen: CoreStrings.keyMultiScreen
        case .screenSize: CoreStrings.keyScreenSize
        case .back: CoreStrings.keyBack
        case .exit: CoreStrings.keyExit
        case .enter: CoreStrings.keyEnter
        case .up: CoreStrings.keyUp
        case .down: CoreStrings.keyDown
        case .right: CoreStrings.keyRight
        case .left: CoreStrings.keyLeft
        case .channelNumber: CoreStrings.keyChannelNumber
        case .radioData: CoreStrings.keyRadioData
        case .guide: CoreStrings.keyGuide
        case .programInfo: CoreStrings.keyProgramInfo
        case .miniGuide: CoreStrings.keyMiniGuide
        case .blue: CoreStrings.keyBlue
        case .red: CoreStrings.keyRed
        case .green: CoreStrings.keyGreen
        case .yellow: CoreStrings.keyYellow
        case .terrestrial: CoreStrings.keyTerrestrial
        case .bs: "BS"
        case .cs: "CS"
        case .pause: CoreStrings.keyPause
        case .record: CoreStrings.keyRecord
        case .pageUp: CoreStrings.keyPageUp
        case .pageDown: CoreStrings.keyPageDown
        case .skipForward: CoreStrings.keySkipForward
        case .skipBackward: CoreStrings.keySkipBackward
        case .nextChapter: CoreStrings.keyNextChapter
        case .previousChapter: CoreStrings.keyPreviousChapter
        case .recordedList: CoreStrings.keyRecordedList
        case .newsNow: CoreStrings.keyNewsNow
        case .stop: CoreStrings.keyStop
        case .rewind: CoreStrings.keyRewind
        case .play: CoreStrings.keyPlay
        case .fastForward: CoreStrings.keyFastForward
        case .timeShift: CoreStrings.keyTimeShift
        case .jumpToStart: CoreStrings.keyJumpToStart
        case .settings: CoreStrings.keySettings
        case .regzaMenu: CoreStrings.keyRegzaMenu
        case .programSearch: CoreStrings.keyProgramSearch
        case .threeD: "3D"
        case .dData: CoreStrings.keyDData
        case .subtitle: CoreStrings.keySubtitle
        }
    }

    public var systemImage: String? {
        switch self {
        case .power: "power"
        case .input: "rectangle.on.rectangle"
        case .mute: "speaker.slash.fill"
        case .volumeUp: "speaker.plus.fill"
        case .volumeDown: "speaker.minus.fill"
        case .channelUp: "chevron.up"
        case .channelDown: "chevron.down"
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .left: "chevron.left"
        case .right: "chevron.right"
        case .back: "arrow.uturn.backward"
        case .exit: "xmark"
        case .guide: "calendar"
        case .programInfo: "info.circle"
        case .display: "text.below.photo"
        case .pause: "pause.fill"
        case .play: "play.fill"
        case .stop: "stop.fill"
        case .rewind: "backward.fill"
        case .fastForward: "forward.fill"
        case .skipForward: "goforward.30"
        case .skipBackward: "gobackward.10"
        case .nextChapter: "forward.end.fill"
        case .previousChapter: "backward.end.fill"
        case .record: "record.circle"
        case .recordedList: "list.bullet.rectangle"
        case .timeShift: "clock.arrow.circlepath"
        case .settings: "gearshape"
        case .subtitle: "captions.bubble"
        case .audio: "waveform"
        case .programSearch: "magnifyingglass"
        default: nil
        }
    }

    /// 放送の種類を切り替えるキー (地デジ・BS・CS) なら、その放送の種類
    public var band: BroadcastBand? {
        switch self {
        case .terrestrial: .terrestrial
        case .bs: .bs
        case .cs: .cs
        default: nil
        }
    }

    public static let numbers: [RegzaKey] = [
        .num1, .num2, .num3, .num4, .num5, .num6,
        .num7, .num8, .num9, .num10, .num11, .num12,
    ]
}
