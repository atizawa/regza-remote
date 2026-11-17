#if os(iOS)
import RegzaPresentation
import SwiftUI

/// 設定画面を開く
package struct ShowSettingsAction {
    let action: @MainActor () -> Void
    package init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    @MainActor package func callAsFunction() { action() }
}

/// タブの中で開く画面 (AppViewModel の戻る道)。機能の画面のモジュールはほかの機能の画面を知らないので、組み立て (AppUI) が渡す
package struct RouteDestination {
    let view: @MainActor (AppViewModel.Route) -> AnyView
    package init(_ view: @escaping @MainActor (AppViewModel.Route) -> AnyView) { self.view = view }
}

extension EnvironmentValues {
    @Entry package var showSettings = ShowSettingsAction {}
    @Entry package var routeDestination = RouteDestination { _ in AnyView(EmptyView()) }
}

extension View {
    /// AppViewModel の戻る道の画面を出せるようにする
    package func appRoutes() -> some View {
        modifier(AppRoutes())
    }
}

private struct AppRoutes: ViewModifier {
    @Environment(\.routeDestination) private var destination

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppViewModel.Route.self) { destination.view($0) }
    }
}

extension AppViewModel {
    /// タブの戻る道を NavigationStack につなぐ (戻るボタンやスワイプで戻ったときも AppViewModel に伝える)
    package func path(of tab: Tab) -> Binding<[Route]> {
        Binding(get: { self.state.path(of: tab) }, set: { self.send(.setPath(tab, $0)) })
    }
}
#endif
