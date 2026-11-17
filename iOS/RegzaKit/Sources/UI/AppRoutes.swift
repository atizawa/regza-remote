#if os(iOS)
import Localization
import GuideFeature
import ProgramFeature
import RegzaPresentation
import SwiftUI

/// タブの中で開く画面。どの画面を開くかは AppViewModel の戻る道が決める (機能の画面には、環境値 routeDestination で渡す)
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

#endif
