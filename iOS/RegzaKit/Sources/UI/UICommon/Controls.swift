#if os(iOS)
import Design
import Localization
import PresentationCore
import SwiftUI

// いくつもの画面で使うボタンの見た目・面の色・放送の種類の切り替え

/// リモコンのボタンの見た目。置かれている場所の色に合わせ、色は選択中 (緑) と電源・録画 (赤) だけに使う
package struct RemoteButtonStyle: ButtonStyle {
    let isDestructive: Bool
    let isSelected: Bool
    /// 電源のように、ボタン全体を赤く塗る
    let isFilled: Bool
    let tone: RemoteKeyTone
    let shape: AnyShape

    package init(
        isDestructive: Bool = false, isSelected: Bool = false, isFilled: Bool = false, tone: RemoteKeyTone = .gray,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: DesignDimensions.shapeCornerRadius, style: .continuous))
    ) {
        self.isDestructive = isDestructive
        self.isSelected = isSelected
        self.isFilled = isFilled
        self.tone = tone
        self.shape = shape
    }

    package func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, DesignDimensions.remoteControlKeyInset)
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
                shape.stroke(RemoteBody.edge, lineWidth: DesignDimensions.remoteControlBorderWidth)
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
        case .gray: return isDestructive ? DesignColors.remoteDestructiveOnGray : .black
        case .black: return isDestructive ? DesignColors.remoteDestructiveOnBlack : .white
        }
    }
}

/// ボタンが置かれている場所。実物のリモコンと同じく、グレーの部分はグレーのボタンに黒い文字、
/// 黒い帯の部分は黒いボタンに白い文字にする
package enum RemoteKeyTone {
    case gray, black
}

extension EnvironmentValues {
    @Entry package var remoteKeyTone = RemoteKeyTone.gray
}

/// 面の色
package enum Surface {
    /// ボタンやカードの地の色。画面の背景から一段浮かせる
    package static let button = DesignColors.semanticSurface
    package static let background = DesignColors.semanticBackground
}

/// 番組表とチャンネル一覧の見出しのすぐ下に置く、放送の種類の切り替え。
/// 見出しの場所には置かず、画面の名前を残す。選んでいるものは、それぞれの画面の state が持つ
package struct BandPicker: View {
    @Environment(RemoteViewModel.self) private var remoteViewModel
    let bands: [BroadcastBand]
    let selected: BroadcastBand?

    package init(bands: [BroadcastBand], selected: BroadcastBand?) {
        self.bands = bands
        self.selected = selected
    }

    package var body: some View {
        Picker(
            AppStrings.broadcastTitle,
            selection: Binding(
                get: { selected ?? .terrestrial },
                set: { remoteViewModel.send(.selectBand($0)) }
            )
        ) {
            ForEach(bands, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignDimensions.spacingOuter)
        .padding(.vertical, 8)
    }
}
#endif
