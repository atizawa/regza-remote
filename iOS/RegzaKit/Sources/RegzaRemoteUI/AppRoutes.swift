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

/// 引っ張って読み直す (refreshable) とき、送った操作の処理が終わるまで待つ (send はすぐに返るので)
@MainActor
func waitWhileBusy(_ viewModel: any Introspectable) async {
    try? await Task.sleep(for: .milliseconds(50))
    while viewModel.isBusy {
        try? await Task.sleep(for: .milliseconds(50))
    }
}

extension AppViewModel {
    /// タブの戻る道を NavigationStack につなぐ (戻るボタンやスワイプで戻ったときも AppViewModel に伝える)
    func path(of tab: Tab) -> Binding<[Route]> {
        Binding(get: { self.state.path(of: tab) }, set: { self.send(.setPath(tab, $0)) })
    }
}
#endif
