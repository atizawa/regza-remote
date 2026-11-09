public import Foundation

/// ライブ視聴の配信の段階 (LivePlayerViewModel.Phase)
public enum LivePlayerPhase: Equatable, Sendable {
    case preparing
    /// 再生できる (HLS のプレイリストの URL)
    case ready(url: URL)
    case failed(message: String, canRetry: Bool)
}
