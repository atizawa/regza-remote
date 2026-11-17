#if os(iOS)
import Design
import LiveActivity
import RegzaPresentation
import SwiftUI

extension View {
    /// 画面が読む環境値を渡す。組み立て (AppScreen) とプレビュー (FakePreview) で同じものを渡す
    /// - Parameter routeDestination: タブの中で開く画面 (組み立ては本物の画面、機能のプレビューは道の名前だけ)
    package func appEnvironment(
        _ appViewModel: AppViewModel, liveActivity: LiveActivityModel, routeDestination: RouteDestination
    ) -> some View {
        environment(appViewModel)
            .environment(appViewModel.remoteViewModel)
            .environment(liveActivity)
            .environment(\.showSettings, ShowSettingsAction { appViewModel.send(.showSettings) })
            .environment(\.routeDestination, routeDestination)
            .tint(AppTheme.accent)
    }
}
#endif
