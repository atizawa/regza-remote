public import Foundation

/// アプリのタブ
public enum AppTab: String, CaseIterable, Codable, Sendable {
    case remote, guide, channels, reservations
}
