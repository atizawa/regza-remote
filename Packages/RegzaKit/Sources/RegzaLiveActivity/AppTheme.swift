#if os(iOS)
import SwiftUI
import UIKit

/// アプリと Live Activity で共通の色 (どちらも暗い背景)。REGZA の公式サイトの深い緑 (#00442D) を基調にする
public enum AppTheme {
    /// ボタンや選択中の印などの色。アプリはダークモード固定 (Info.plist の UIUserInterfaceStyle) なので、
    /// 公式サイトの深い緑 (#00442D) では暗い背景で見えにくいため、明るめの緑にする
    public static let accent = Color(onDark)

    /// Live Activity の背景 (緑みのある黒)
    public static let activityBackground = Color(red: 0.01, green: 0.07, blue: 0.05)

    private static let onDark = UIColor(red: 0.114, green: 0.525, blue: 0.435, alpha: 1) // #1D866F
}
#endif
