#if os(iOS)
import Design
import LiveActivity
import PresentationCore
import SwiftUI

extension View {
    /// 画面が読む環境値を渡す。組み立て (AppScreen) とプレビュー (FakePreview) で同じものを渡す
    /// - Parameter navigator: 画面の移り変わりを頼む窓口 (アプリ全体の ViewModel)
    package func appEnvironment(navigator: any AppNavigator, remoteViewModel: RemoteViewModel, liveActivity: LiveActivityModel) -> some View
    {
        environment(\.appNavigator, navigator)
            .environment(remoteViewModel)
            .environment(liveActivity)
            .tint(AppTheme.accent)
    }
}
#endif
