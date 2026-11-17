#if os(iOS)
import PresentationCore
import SwiftUI

/// タブの中で開く画面 (アプリ全体の戻る道)。機能の画面のモジュールはほかの機能の画面を知らないので、組み立て (AppUI) が渡す
package struct RouteDestination {
    let view: @MainActor (AppRoute) -> AnyView
    package init(_ view: @escaping @MainActor (AppRoute) -> AnyView) { self.view = view }
}

extension EnvironmentValues {
    /// 画面の移り変わりを頼む窓口 (組み立てとプレビューがアプリ全体の ViewModel を渡す)
    @Entry package var appNavigator: any AppNavigator = UnsetNavigator()
    @Entry package var routeDestination = RouteDestination { _ in AnyView(EmptyView()) }
}

/// 窓口を渡し忘れたときのもの (何もしない)
private final class UnsetNavigator: AppNavigator {
    nonisolated init() {}
    func routes(of tab: AppTab) -> [AppRoute] { [] }
    func setRoutes(_ routes: [AppRoute], of tab: AppTab) {}
    func push(_ route: AppRoute) {}
    func play(channelCode: String) {}
    var isPlaying: Bool { false }
    func closePlayer() {}
    var isShowingNowPlaying: Bool { false }
    func showNowPlaying() {}
    func closeNowPlaying() {}
    func showSettings() {}
}

extension View {
    /// アプリ全体の戻る道の画面を出せるようにする
    package func appRoutes() -> some View {
        modifier(AppRoutes())
    }
}

private struct AppRoutes: ViewModifier {
    @Environment(\.routeDestination) private var destination

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { destination.view($0) }
    }
}

extension AppNavigator {
    /// タブの戻る道を NavigationStack につなぐ (戻るボタンやスワイプで戻ったときも窓口に伝える)
    package func path(of tab: AppTab) -> Binding<[AppRoute]> {
        Binding(get: { self.routes(of: tab) }, set: { self.setRoutes($0, of: tab) })
    }
}
#endif
