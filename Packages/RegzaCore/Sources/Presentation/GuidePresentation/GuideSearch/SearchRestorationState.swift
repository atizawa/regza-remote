import Foundation
import PresentationCore

/// 番組を探す画面の、OS の画面復元に保存するもの (AppViewModel がまとめて保存する)
package struct SearchRestorationState: Codable {
    var text: String
    var isLiteral: Bool
    var removed: Set<GuideSearchCondition>
}
