#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 画面全体で使う余白・大きさ。値はこの 3 段階だけにそろえる
enum Design {
    /// 画面の端
    static let outer: CGFloat = 16
    /// 同じまとまりのボタンの間
    static let item: CGFloat = 12
    /// まとまりの間
    static let group: CGFloat = 24

    /// ボタンの高さ: よく使う操作 / ふつう / まれな操作
    static let primaryHeight: CGFloat = 56
    static let regularHeight: CGFloat = 48
    static let compactHeight: CGFloat = 40

    static let cornerRadius: CGFloat = 16
}

enum ButtonSize {
    case primary, regular, compact

    var height: CGFloat {
        switch self {
        case .primary: Design.primaryHeight
        case .regular: Design.regularHeight
        case .compact: Design.compactHeight
        }
    }
}

/// キーを 1 つ送るボタン
struct KeyButton: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.remoteKeyTone) private var tone
    let key: RegzaKey
    var title: String?
    var size = ButtonSize.regular
    /// 電源・録画など、押すと困ることがある操作
    var isDestructive = false
    /// 電源ボタンのように赤く塗る
    var isFilled = false
    var showsIcon = true
    /// アイコンの下に小さく名前を添える
    var showsCaption = false
    var isSelected = false

    var body: some View {
        Button {
            model.send(key)
        } label: {
            VStack(spacing: 2) {
                if showsIcon, let image = key.systemImage {
                    Image(systemName: image)
                        .font(size == .compact ? .body.weight(.semibold) : .title3.weight(.semibold))
                    if showsCaption {
                        Text(title ?? key.label)
                            .font(.caption2)
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                } else {
                    Text(title ?? key.label)
                        .font(labelFont)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: size.height)
        }
        .buttonStyle(RemoteButtonStyle(isDestructive: isDestructive, isSelected: isSelected, isFilled: isFilled, tone: tone))
        .accessibilityLabel(key.label)
    }

    /// 数字のボタンは、実物のリモコンと同じく大きく太い字にする。
    /// 地デジ・BS・CS も数字と同じ太さにするが、数字が主役になるよう大きさはそのまま
    private var labelFont: Font {
        if RegzaKey.numbers.contains(key) { return .title2.weight(.heavy) }
        let weight: Font.Weight = [.terrestrial, .bs, .cs].contains(key) ? .heavy : .semibold
        return size == .compact ? .footnote.weight(weight) : .body.weight(weight)
    }
}

/// リモコンのボタンの見た目。置かれている場所の色に合わせ、色は選択中 (緑) と電源・録画 (赤) だけに使う
struct RemoteButtonStyle: ButtonStyle {
    var isDestructive = false
    var isSelected = false
    /// 電源のように、ボタン全体を赤く塗る
    var isFilled = false
    var tone = RemoteKeyTone.gray
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .background {
                if isFilled {
                    shape.fill(RemoteBody.power)
                } else if isSelected {
                    shape.fill(AppTheme.accent)
                } else {
                    shape.fill(tone == .gray ? RemoteBody.grayKey : RemoteBody.key)
                        .overlay { shape.fill(RemoteBody.keyHighlight) }
                }
            }
            .overlay {
                shape.stroke(RemoteBody.edge, lineWidth: 0.5)
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        // 選択中は緑の地に白い文字
        if isFilled || isSelected { return .white }
        switch tone {
        case .gray: return isDestructive ? Color(red: 0.75, green: 0.08, blue: 0.1) : .black
        case .black: return isDestructive ? Color(red: 1.0, green: 0.27, blue: 0.27) : .white
        }
    }
}

/// ボタンが置かれている場所。実物のリモコンと同じく、グレーの部分はグレーのボタンに黒い文字、
/// 黒い帯の部分は黒いボタンに白い文字にする
enum RemoteKeyTone {
    case gray, black
}

extension EnvironmentValues {
    @Entry var remoteKeyTone = RemoteKeyTone.gray
}

/// リモコンのタブの配色。テレビ付属のリモコンに合わせる。
/// 本体はグレーで、十字キーのあたりだけ黒い帯になっている。グレーの部分はグレーのボタンに黒い文字、
/// 黒い帯の部分は黒いボタンに白い文字、決定は銀色
enum RemoteBody {
    /// 本体のグレー (#ADACB2 付近)
    static let background = LinearGradient(
        colors: [Color(red: 0.690, green: 0.686, blue: 0.706), Color(red: 0.635, green: 0.631, blue: 0.651)],
        startPoint: .top, endPoint: .bottom
    )
    /// グレーの部分のボタン (本体より少し明るいグレー)
    static let grayKey = Color(red: 0.800, green: 0.796, blue: 0.812)
    /// 十字キーのあたりの黒い帯 (#33323A 付近)
    static let panel = Color(red: 0.200, green: 0.196, blue: 0.227)
    /// 黒い帯の部分のボタン (黒)
    static let key = Color(red: 0.110, green: 0.110, blue: 0.125)
    /// ボタンの上側のごく薄い光沢 (物のボタンらしく見せる)
    static let keyHighlight = LinearGradient(
        colors: [.white.opacity(0.12), .white.opacity(0)], startPoint: .top, endPoint: .center
    )
    /// ボタンの縁
    static let edge = Color.black.opacity(0.3)
    /// 十字キーの輪 (#212224 付近)
    static let ring = Color(red: 0.129, green: 0.133, blue: 0.141)
    /// 決定ボタンの銀色 (#919296 付近)
    static let center = LinearGradient(
        colors: [Color(red: 0.62, green: 0.62, blue: 0.64), Color(red: 0.52, green: 0.52, blue: 0.54)],
        startPoint: .top, endPoint: .bottom
    )
    /// 電源ボタンの赤
    static let power = Color(red: 0.78, green: 0.12, blue: 0.14)
}

/// 面の色
enum Surface {
    /// ボタンやカードの地の色。画面の背景から一段浮かせる
    static let button = Color(.secondarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)
}

/// 青・赤・緑・黄のカラーボタン。テレビのリモコンと同じく細長い色の帯にする
struct ColorKeyButton: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.remoteKeyTone) private var tone
    let key: RegzaKey
    let color: Color

    var body: some View {
        Button {
            model.send(key)
        } label: {
            Capsule()
                .fill(color)
                .frame(height: 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: Design.compactHeight)
        }
        .buttonStyle(RemoteButtonStyle(tone: tone))
        .accessibilityLabel(key.label)
    }
}

/// 音量・チャンネルの縦長ボタン
struct RockerControl: View {
    @Environment(RemoteViewModel.self) private var model
    let title: String
    let up: RegzaKey
    let down: RegzaKey
    var upImage = "plus"
    var downImage = "minus"

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(up, image: upImage)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            rockerButton(down, image: downImage)
        }
        // 黒い帯の上に置くので、文字は白にする
        .foregroundStyle(.white)
        .background {
            Capsule().fill(RemoteBody.key)
                .overlay { Capsule().fill(RemoteBody.keyHighlight) }
                .overlay { Capsule().stroke(RemoteBody.edge, lineWidth: 0.5) }
        }
    }

    private func rockerButton(_ key: RegzaKey, image: String) -> some View {
        Button {
            model.send(key)
        } label: {
            Image(systemName: image)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }
}

/// 十字キーと決定
struct DirectionPad: View {
    @Environment(RemoteViewModel.self) private var model
    var diameter: CGFloat = 200

    var body: some View {
        ZStack {
            Circle().fill(RemoteBody.ring)
                .overlay { Circle().stroke(RemoteBody.edge, lineWidth: 0.5) }
            VStack {
                arrow(.up)
                Spacer()
                arrow(.down)
            }
            HStack {
                arrow(.left)
                Spacer()
                arrow(.right)
            }
            // 実物のリモコンと同じく、真ん中だけ銀色の一段浮いたボタンにする
            Button {
                model.send(.enter)
            } label: {
                Text("決定")
                    .font(.headline)
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: diameter * 0.38, height: diameter * 0.38)
                    .background {
                        Circle().fill(RemoteBody.center)
                            .overlay { Circle().stroke(.white.opacity(0.25), lineWidth: 0.5) }
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        // 黒い帯の上に置くので、矢印は白にする
        .foregroundStyle(.white)
        .frame(width: diameter, height: diameter)
    }

    private func arrow(_ key: RegzaKey) -> some View {
        Button {
            model.send(key)
        } label: {
            Image(systemName: key.systemImage ?? "circle")
                .font(.title2.weight(.semibold))
                .frame(width: diameter * 0.3, height: diameter * 0.3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }
}

/// 番組表とチャンネル一覧の見出しのすぐ下に置く、放送の種類の切り替え。
/// 見出しの場所には置かず、画面の名前を残す
struct BandPicker: View {
    @Environment(RemoteViewModel.self) private var model
    let bands: [RegzaChannel.Band]

    var body: some View {
        Picker("放送", selection: Binding(
            get: { model.band(among: bands) ?? .terrestrial },
            set: { model.selectedBand = $0 }
        )) {
            ForEach(bands, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Design.outer)
        .padding(.vertical, 8)
    }
}

/// 見出し付きのまとまり
struct RemoteSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Design.item) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black.opacity(0.6))
                .padding(.leading, 4)
            content
        }
    }
}
#endif
