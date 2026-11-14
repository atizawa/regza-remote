#if os(iOS)
import Localization
import RegzaPresentation
import SwiftUI

/// タブの中で開く画面。どの画面を開くかは AppViewModel の戻る道が決める
struct RouteView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let route: AppViewModel.Route

    var body: some View {
        switch route {
        case .channelPrograms(let channelCode):
            if let viewModel = appViewModel.programList(channelCode: channelCode) {
                ProgramListScreen(viewModel: viewModel)
            } else {
                ContentUnavailableView(AppStrings.channelMissing, systemImage: "list.bullet")
            }
        case .programDetail(let programID, let channelCode):
            if let viewModel = appViewModel.programDetail(programID: programID, channelCode: channelCode) {
                ProgramDetailScreen(viewModel: viewModel)
            } else {
                ContentUnavailableView(AppStrings.programMissing, systemImage: "calendar.badge.exclamationmark")
            }
        case .search:
            GuideSearchScreen(guideSearchViewModel: appViewModel.guideGridViewModel.guideSearchViewModel) { row in
                appViewModel.send(.push(.programDetail(programID: row.program.id, channelCode: row.channelCode)))
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
