import Foundation

/// REGZA のリモコンキーコード。
/// 参考: https://misomayo.info/on/2012/04/10
public enum RegzaKey: String, CaseIterable, Identifiable, Sendable {
    // 数字
    case num1 = "40BF01", num2 = "40BF02", num3 = "40BF03", num4 = "40BF04"
    case num5 = "40BF05", num6 = "40BF06", num7 = "40BF07", num8 = "40BF08"
    case num9 = "40BF09", num10 = "40BF0A", num11 = "40BF0B", num12 = "40BF0C"

    // 基本
    case input = "40BF0F"
    case mute = "40BF10"
    case power = "40BF12"
    case audio = "40BF13"
    case volumeUp = "40BF1A"
    case channelUp = "40BF1B"
    case display = "40BF1C"
    case volumeDown = "40BF1E"
    case channelDown = "40BF1F"
    case broadband = "40BF25"
    case quick = "40BF27"
    case multiScreen = "40BF29"
    case screenSize = "40BF2B"

    // カーソル
    case back = "40BF3B"
    case exit = "40BF3C"
    case enter = "40BF3D"
    case up = "40BF3E"
    case down = "40BF3F"
    case right = "40BF5B"
    case left = "40BF5F"

    // 番組
    case channelNumber = "40BF60"
    case radioData = "40BF6D"
    case guide = "40BF6E"
    case programInfo = "40BF71"
    case miniGuide = "40BF77"

    // カラー
    case blue = "40BF73", red = "40BF74", green = "40BF75", yellow = "40BF76"

    // 放送切替
    case terrestrial = "40BF7A"
    case bs = "40BF7C"
    case cs = "40BF7D"

    // 録画・再生
    case pause = "40BF50"
    case record = "40BF86"
    case pageUp = "40BE20"
    case pageDown = "40BE21"
    case skipForward = "40BE22"
    case skipBackward = "40BE23"
    case nextChapter = "40BE26"
    case previousChapter = "40BE27"
    case recordedList = "40BE28"
    case newsNow = "40BE29"
    case stop = "40BE2B"
    case rewind = "40BE2C"
    case play = "40BE2D"
    case fastForward = "40BE2E"
    case timeShift = "40BE35"
    case jumpToStart = "40BE47"

    // メニュー
    case settings = "40BFD0"
    case regzaMenu = "40BE34"
    case programSearch = "40BE36"
    case threeD = "40BE43"
    case dData = "43BC14"
    case subtitle = "43BC52"

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

    /// テレビの映像が切り替わることがあるキー (録画の再生を始める・止める、一覧を閉じるなど)。
    /// 送った直後は視聴状況を問い合わせない (`RegzaRemote.switchingQuietPeriod`)
    public var mayStartContentSwitch: Bool {
        switch self {
        case .enter, .play, .stop, .back, .exit, .jumpToStart, .timeShift, .recordedList: true
        default: false
        }
    }

    public static let numbers: [RegzaKey] = [
        .num1, .num2, .num3, .num4, .num5, .num6,
        .num7, .num8, .num9, .num10, .num11, .num12,
    ]
}
