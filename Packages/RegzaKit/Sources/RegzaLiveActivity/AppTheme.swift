#if os(iOS)
import SwiftUI
import UIKit

/// アプリと Live Activity で共通の色。REGZA の公式サイトの深い緑 (#00442D) を基調にする
public enum AppTheme {
    /// ボタンや選択中の印などの色。ライトモードでは深い緑、ダークモードでは暗い背景でも見える明るめの緑
    public static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? onDark : onLight
    })

    /// Live Activity など、いつも暗い背景の上に出す緑
    public static let accentOnDark = Color(onDark)

    /// Live Activity の背景 (緑みのある黒)
    public static let activityBackground = Color(red: 0.01, green: 0.07, blue: 0.05)

    private static let onLight = UIColor(red: 0.000, green: 0.267, blue: 0.176, alpha: 1) // #00442D
    private static let onDark = UIColor(red: 0.114, green: 0.525, blue: 0.435, alpha: 1) // #1D866F
}
#endif
