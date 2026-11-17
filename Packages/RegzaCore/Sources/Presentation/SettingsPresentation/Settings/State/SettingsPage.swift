import Foundation
import PresentationCore

/// 設定の中で開く画面
public enum SettingsPage: String, Hashable, Codable, Sendable {
    case tv, guide, stream
}
