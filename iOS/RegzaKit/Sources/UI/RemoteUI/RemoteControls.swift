#if os(iOS)
import Localization
import PresentationCore
import Design
import SwiftUI
import UICommon

enum ButtonSize {
    case primary, regular, compact

    var height: CGFloat {
        switch self {
        case .primary: DesignDimensions.buttonPrimaryHeight
        case .regular: DesignDimensions.buttonRegularHeight
        case .compact: DesignDimensions.buttonCompactHeight
        }
    }
}

/// キーを 1 つ送るボタン
struct KeyButton: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
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
            remoteViewModel.send(.press(key))
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

/// 青・赤・緑・黄のカラーボタン。テレビのリモコンと同じく細長い色の帯にする
struct ColorKeyButton: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
    @Environment(\.remoteKeyTone) private var tone
    let key: RegzaKey
    let color: Color

    var body: some View {
        Button {
            remoteViewModel.send(.press(key))
        } label: {
            Capsule()
                .fill(color)
                .frame(height: DesignDimensions.remoteControlColorKeyHeight)
                .padding(.horizontal, DesignDimensions.remoteControlColorKeyInset)
                .frame(maxWidth: .infinity, minHeight: DesignDimensions.buttonCompactHeight)
        }
        .buttonStyle(RemoteButtonStyle(tone: tone))
        .accessibilityLabel(key.label)
    }
}

/// 音量・チャンネルの縦長ボタン
struct RockerControl: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
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
                .overlay { Capsule().stroke(RemoteBody.edge, lineWidth: DesignDimensions.remoteControlBorderWidth) }
        }
    }

    private func rockerButton(_ key: RegzaKey, image: String) -> some View {
        Button {
            remoteViewModel.send(.press(key))
        } label: {
            Image(systemName: image)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: DesignDimensions.remoteControlRockerHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
    }
}

/// 十字キーと決定
struct DirectionPad: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
    var diameter: CGFloat = 200

    var body: some View {
        ZStack {
            Circle().fill(RemoteBody.ring)
                .overlay { Circle().stroke(RemoteBody.edge, lineWidth: DesignDimensions.remoteControlBorderWidth) }
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
                remoteViewModel.send(.press(.enter))
            } label: {
                Text(AppStrings.remoteEnter)
                    .font(.headline)
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: diameter * 0.38, height: diameter * 0.38)
                    .background {
                        Circle().fill(RemoteBody.center)
                            .overlay { Circle().stroke(.white.opacity(0.25), lineWidth: DesignDimensions.remoteControlBorderWidth) }
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
            remoteViewModel.send(.press(key))
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

/// 見出し付きのまとまり
struct RemoteSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignDimensions.spacingItem) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black.opacity(0.6))
                .padding(.leading, 4)
            content
        }
    }
}
#endif
