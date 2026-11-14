public import Foundation

/// アプリ全体の状態 (AppViewModel.State)。画面の移り変わりは、タブごとの path (開いた画面を順に積んだもの) で表す。
/// SwiftUI の NavigationStack(path:) にも、Compose の back stack にもそのまま渡せる
public struct AppState: Equatable, Sendable {
    public var appearance: AppAppearance = .system
    public var tab: AppTab = .remote
    /// タブごとの path (最後が手前の画面)。swift-java は辞書を Java にできないので公開せず、path(of:) で読ませる
    var paths: [AppTab: [AppRoute]] = [:]
    public var isShowingSettings: Bool = false
    /// いま映っているものの詳細のシート
    public var isShowingNowPlaying: Bool = false
    /// アプリで見ている局 (ライブ視聴の全画面)。ライブ視聴の中で局を切り替えたら、その局になる
    public var playingChannelCode: String?

    /// タブの path。空ならタブの最初の画面を出している
    public func path(of tab: AppTab) -> [AppRoute] { paths[tab] ?? [] }
}
