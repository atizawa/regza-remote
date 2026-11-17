#if os(iOS)
import PresentationCore
import SwiftUI

extension EnvironmentValues {
    /// 画面の移り変わりを頼む窓口 (組み立てとプレビューがアプリ全体の ViewModel を渡す)。
    /// 戻る道やシートの表示は組み立てが持ち、機能の画面はこの窓口に頼むだけにする
    @Entry package var appNavigator: any AppNavigator = UnsetNavigator()
}

/// 窓口を渡し忘れたときのもの (何もしない)
private final class UnsetNavigator: AppNavigator {
    nonisolated init() {}
    func push(_ route: AppRoute) {}
    func play(channelCode: String) {}
    func closePlayer() {}
    func showNowPlaying() {}
    func closeNowPlaying() {}
    func showSettings() {}
}
#endif
