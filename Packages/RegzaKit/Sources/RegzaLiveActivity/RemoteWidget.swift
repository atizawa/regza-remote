#if os(iOS)
import AppIntents
import RegzaCore
import SwiftUI
import WidgetKit

/// ホーム画面に置くリモコンのウィジェット (中・大)。番組名などは出さず、ボタンだけを並べる。
/// 大は数字まで並べて、実物のリモコンに近くする。小は置けるボタンが少なく、同じ操作はコントロールセンターのボタンで足りるので出さない。
/// (ウィジェットはすぐには更新されないので、今の番組は Live Activity に任せる)。
/// ボタンは RegzaKeyIntent でキーを送る (LiveActivityIntent なのでアプリのプロセスで動き、テレビの登録情報を使える)
public struct RemoteWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RegzaRemote.widget.remote", provider: Provider()) { _ in
            RemoteWidgetView()
                // リモコンのタブと同じ、明るいグレーの本体
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Palette.bodyTop, Palette.bodyBottom], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("リモコン")
        .description("アプリを開かずに、電源・音量・チャンネルを操作できます。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }

    /// 表示は変わらないので、1 つだけ出して更新しない
    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry { Entry(date: .now) }
        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [Entry(date: .now)], policy: .never))
        }
    }

    struct Entry: TimelineEntry {
        let date: Date
    }
}

/// リモコンのタブ (RegzaRemoteUI の RemoteBody) と同じ色
private enum Palette {
    static let bodyTop = Color(red: 0.690, green: 0.686, blue: 0.706)
    static let bodyBottom = Color(red: 0.635, green: 0.631, blue: 0.651)
    static let key = Color(red: 0.800, green: 0.796, blue: 0.812)
    static let power = Color(red: 0.78, green: 0.12, blue: 0.14)
    /// 大のウィジェットの下の黒い帯と、そこに置くボタン
    static let band = Color(red: 0.200, green: 0.196, blue: 0.227)
    static let blackKey = Color(red: 0.110, green: 0.110, blue: 0.125)
}

private struct RemoteWidgetView: View {
    @Environment(\.widgetFamily) private var family

    /// 大のウィジェットで、数字以外の段の高さ
    static let compactRowHeight: CGFloat = 30

    var body: some View {
        switch family {
        case .systemLarge:
            // 実物のリモコンと同じく、電源 → 地デジ・BS・CS → 数字 → 黒い帯に音量とチャンネル → 再生。
            // 数字を主役にするため、数字以外の段は低くそろえる
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    WidgetKey(key: .power, isCompact: true)
                    Spacer(minLength: 0)
                    WidgetKey(key: .input, isCompact: true)
                    WidgetKey(key: .mute, isCompact: true)
                }
                .frame(height: Self.compactRowHeight)
                HStack(spacing: 6) {
                    WidgetKey(key: .terrestrial, title: "地デジ", isCompact: true)
                    WidgetKey(key: .bs, title: "BS", isCompact: true)
                    WidgetKey(key: .cs, title: "CS", isCompact: true)
                }
                .frame(height: Self.compactRowHeight)
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<4, id: \.self) { row in
                        GridRow {
                            ForEach(0..<3, id: \.self) { column in
                                let key = RegzaKey.numbers[row * 3 + column]
                                WidgetKey(key: key, title: key.label, isNumber: true)
                            }
                        }
                    }
                }
                HStack(spacing: 6) {
                    WidgetKey(key: .volumeDown, isOnBand: true)
                    WidgetKey(key: .volumeUp, isOnBand: true)
                    WidgetKey(key: .channelDown, title: "CH−", isOnBand: true)
                    WidgetKey(key: .channelUp, title: "CH＋", isOnBand: true)
                }
                .frame(height: Self.compactRowHeight)
                .padding(5)
                .background(Palette.band, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                // 再生と一時停止は、今の状態が分からないので別々のボタンにする
                HStack(spacing: 6) {
                    WidgetKey(key: .skipBackward, isCompact: true)
                    WidgetKey(key: .play, isCompact: true)
                    WidgetKey(key: .pause, isCompact: true)
                    WidgetKey(key: .skipForward, isCompact: true)
                }
                .frame(height: Self.compactRowHeight)
            }
        default:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    WidgetKey(key: .power)
                    WidgetKey(key: .input)
                    WidgetKey(key: .mute)
                }
                HStack(spacing: 8) {
                    WidgetKey(key: .channelDown, title: "CH−")
                    WidgetKey(key: .channelUp, title: "CH＋")
                    WidgetKey(key: .volumeDown)
                    WidgetKey(key: .volumeUp)
                }
            }
        }
    }
}

/// ウィジェットのボタン。グレーに黒い字、電源だけ赤に白い記号 (実物のリモコンと同じ)
private struct WidgetKey: View {
    let key: RegzaKey
    var title: String?
    /// 数字は大きく太い字にする
    var isNumber = false
    /// 黒い帯の上のボタン (黒に白い字)
    var isOnBand = false
    /// 地デジ・BS・CS のように、数字より小さく見せるボタン
    var isCompact = false

    var body: some View {
        Button(intent: RegzaKeyIntent(key)) {
            Group {
                if let title {
                    Text(title).font(labelFont)
                } else {
                    Image(systemName: key.systemImage ?? "circle")
                        .font(isOnBand || isCompact ? .body.weight(.semibold) : .title3.weight(.semibold))
                }
            }
            .foregroundStyle(key == .power || isOnBand ? Color.white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background, in: RoundedRectangle(cornerRadius: isCompact ? 10 : 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }

    /// 数字がいちばん大きく見えるよう、黒い帯の文字は一段小さくする
    private var labelFont: Font {
        if isNumber { return .title.weight(.heavy) }
        return isOnBand || isCompact ? .subheadline.weight(.heavy) : .headline.weight(.heavy)
    }

    private var background: Color {
        if key == .power { return Palette.power }
        return isOnBand ? Palette.blackKey : Palette.key
    }
}
#endif
