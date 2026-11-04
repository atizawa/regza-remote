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
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(title ?? key.label)
                        .font(size == .compact ? .footnote.weight(.semibold) : .body.weight(.semibold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: size.height)
        }
        .buttonStyle(RemoteButtonStyle(isDestructive: isDestructive, isSelected: isSelected, isFilled: isFilled))
        .accessibilityLabel(key.label)
    }
}

/// リモコンのボタンの見た目。地の色は 1 色にし、色は選択中 (緑) と電源・録画 (赤) だけに使う
struct RemoteButtonStyle: ButtonStyle {
    var isDestructive = false
    var isSelected = false
    /// 電源のように、ボタン全体を赤く塗る
    var isFilled = false
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .background {
                if isFilled {
                    shape.fill(RemoteBody.power)
                } else if isSelected {
                    shape.fill(AppTheme.accent.opacity(0.22))
                } else {
                    shape.fill(RemoteBody.key)
                        .overlay { shape.fill(RemoteBody.keyHighlight) }
                }
            }
            .overlay {
                shape.stroke(isSelected ? AppTheme.accent : RemoteBody.edge, lineWidth: isSelected ? 1 : 0.5)
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        if isFilled { return .white }
        if isDestructive { return Color(red: 1.0, green: 0.27, blue: 0.27) }
        // 選択中は緑の枠と地で示し、文字は読みやすい白にする
        if isSelected { return .white }
        return .primary
    }
}

/// リモコンのタブの配色。テレビ付属のリモコンの写真から測った色に合わせる。
/// 本体はグレーで、十字キーのあたりだけ黒い帯になっている。ボタンは黒に白い文字、決定は銀色。
enum RemoteBody {
    /// 本体のグレー (#7B7A80 付近。写真の色は暗く写っていたので明るめにしている)
    static let background = LinearGradient(
        colors: [Color(red: 0.502, green: 0.498, blue: 0.518), Color(red: 0.447, green: 0.443, blue: 0.463)],
        startPoint: .top, endPoint: .bottom
    )
    /// 十字キーのあたりの黒い帯 (#33323A 付近)
    static let panel = Color(red: 0.200, green: 0.196, blue: 0.227)
    /// ボタンの地の色 (黒)
    static let key = Color(red: 0.110, green: 0.110, blue: 0.125)
    /// ボタンの上側のごく薄い光沢 (物のボタンらしく見せる)
    static let keyHighlight = LinearGradient(
        colors: [.white.opacity(0.08), .white.opacity(0)], startPoint: .top, endPoint: .center
    )
    /// ボタンの縁
    static let edge = Color.black.opacity(0.4)
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
        .buttonStyle(RemoteButtonStyle())
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
                .foregroundStyle(.secondary)
            rockerButton(down, image: downImage)
        }
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
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content
        }
    }
}
#endif
