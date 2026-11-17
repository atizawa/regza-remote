#if os(iOS)
import Design
import LiveActivity
import PresentationCore
import SwiftUI

extension View {
    /// 画面が読む環境値を渡す。組み立て (AppScreen) とプレビュー (FakePreview) で同じものを渡す
    /// - Parameters:
    ///   - navigator: 画面の移り変わりを頼む窓口 (アプリ全体の ViewModel)
    ///   - routeDestination: タブの中で開く画面 (組み立ては本物の画面、機能のプレビューは道の名前だけ)
    package func appEnvironment(
        navigator: any AppNavigator, remoteViewModel: RemoteViewModel, liveActivity: LiveActivityModel,
        routeDestination: RouteDestination
    ) -> some View {
        environment(\.appNavigator, navigator)
            .environment(remoteViewModel)
            .environment(liveActivity)
            .environment(\.routeDestination, routeDestination)
            .tint(AppTheme.accent)
    }
}
#endif
