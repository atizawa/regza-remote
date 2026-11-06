#if os(iOS)
import RegzaCore
import SwiftUI

/// タブの中で開く画面。どの画面を開くかは AppViewModel の戻る道が決める
struct RouteView: View {
    @Environment(AppViewModel.self) private var app
    let route: AppViewModel.Route

    var body: some View {
        switch route {
        case .channelPrograms(let channel):
            ChannelProgramsView(viewModel: app.programList(for: channel))
        case .programDetail(let program, let channel):
            ProgramDetailView(viewModel: app.programDetail(program, channel: channel))
        case .search:
            GuideSearchScreen(search: app.guideGrid.search) { program, channel in
                app.send(.open(.programDetail(program, channel)))
            }
        }
    }
}

extension View {
    /// AppViewModel の戻る道の画面を出せるようにする
    func appRoutes() -> some View {
        navigationDestination(for: AppViewModel.Route.self) { RouteView(route: $0) }
    }
}

extension AppViewModel {
    /// タブの戻る道を NavigationStack につなぐ (戻るボタンやスワイプで戻ったときも AppViewModel に伝える)
    func path(of tab: Tab) -> Binding<[Route]> {
        Binding(get: { self.state.path(of: tab) }, set: { self.send(.setPath(tab, $0)) })
    }
}
#endif
