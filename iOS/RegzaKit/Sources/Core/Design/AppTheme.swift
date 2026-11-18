#if os(iOS)
import SwiftUI

/// アプリとウィジェットの共通色。Color Asset がOSの外観に応じて色を選ぶ。
public enum AppTheme {
    public static let accent = DesignColors.brandAccent
    /// Live Activity は映像を扱うため、背景を暗い緑で統一する。
    public static let activityBackground = DesignColors.brandActivityBackground
}
#endif
