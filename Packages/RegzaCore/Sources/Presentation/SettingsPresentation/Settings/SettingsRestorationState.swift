import Foundation
import PresentationCore

/// 設定の画面の、OS の画面復元に保存するもの (AppViewModel がまとめて保存する)
package struct SettingsRestorationState: Codable {
    var path: [SettingsPage]
    var host: String
    var user: String
    var isShowingManualEntry: Bool
    var guideHost: String
    var streamHost: String
}
