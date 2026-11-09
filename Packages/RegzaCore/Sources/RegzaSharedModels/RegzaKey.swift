import Foundation

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
        case .input: "入力切替"
        case .mute: "消音"
        case .power: "電源"
        case .audio: "音声切替"
        case .volumeUp: "音量＋"
        case .channelUp: "チャンネル＋"
        case .display: "画面表示"
        case .volumeDown: "音量−"
        case .channelDown: "チャンネル−"
        case .broadband: "ブロードバンド"
        case .quick: "クイック"
        case .multiScreen: "マルチ画面"
        case .screenSize: "画面サイズ"
        case .back: "戻る"
        case .exit: "終了"
        case .enter: "決定"
        case .up: "上"
        case .down: "下"
        case .right: "右"
        case .left: "左"
        case .channelNumber: "CH番号"
        case .radioData: "ラジオ/データ"
        case .guide: "番組表"
        case .programInfo: "番組説明"
        case .miniGuide: "ミニ番組表"
        case .blue: "青"
        case .red: "赤"
        case .green: "緑"
        case .yellow: "黄"
        case .terrestrial: "地デジ"
        case .bs: "BS"
        case .cs: "CS"
        case .pause: "一時停止"
        case .record: "録画"
        case .pageUp: "ページ上"
        case .pageDown: "ページ下"
        case .skipForward: "30秒送り"
        case .skipBackward: "10秒戻し"
        case .nextChapter: "次へスキップ"
        case .previousChapter: "前へスキップ"
        case .recordedList: "録画リスト"
        case .newsNow: "今すぐニュース"
        case .stop: "停止"
        case .rewind: "巻き戻し"
        case .play: "再生"
        case .fastForward: "早送り"
        case .timeShift: "タイムシフト"
        case .jumpToStart: "始めにジャンプ"
        case .settings: "設定メニュー"
        case .regzaMenu: "レグザメニュー"
        case .programSearch: "番組検索"
        case .threeD: "3D"
        case .dData: "dデータ"
        case .subtitle: "字幕"
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
