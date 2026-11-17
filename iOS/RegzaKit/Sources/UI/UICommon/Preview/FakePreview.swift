#if os(iOS) && DEBUG
import LiveActivity
import AppPresentation
import PresentationCore
import RegzaFakeServers
import SwiftUI

/// 画面のプレビューの準備 (Debug のビルドだけ。偽物は iOS のリリースのビルドでは中身がなくなるので、リリース版には入らない)。
/// 振る舞いのテストと同じ偽物のテレビ・録画サーバー (RegzaFakeServers) で AppViewModel を組み立て、操作を送ってから、
/// 組み立て (AppUI) と同じ環境値を渡して画面を描く (本物にはつながない)
package struct FakePreview<Content: View>: View {
    @State private var appViewModel: AppViewModel
    @State private var liveActivity: LiveActivityModel
    @State private var isReady = false
    private let setUp: @MainActor (AppViewModel) async -> Void
    private let content: @MainActor (AppViewModel) -> Content

    /// - Parameters:
    ///   - scenario: 偽物の場面
    ///   - setUp: 描く前に送る操作 (読み込む・画面の ViewModel を作るなど)。送ったあとは、通信などが終わるまで待ってから描く
    ///   - content: 描く画面
    package init(
        _ scenario: FakeScenario.Name = .standard,
        setUp: @escaping @MainActor (AppViewModel) async -> Void = { _ in },
        @ViewBuilder content: @escaping @MainActor (AppViewModel) -> Content
    ) {
        let appViewModel = FakeApp.makeAppViewModel(scenario: FakeScenario(scenario))
        _appViewModel = State(initialValue: appViewModel)
        _liveActivity = State(initialValue: LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel))
        self.setUp = setUp
        self.content = content
    }

    package var body: some View {
        if isReady {
            content(appViewModel)
                .environment(appViewModel)
                // ほかの機能の画面は機能の画面のモジュールから見えないので、開いた先は道の名前だけを出す (アプリ全体のプレビューでは本物の画面)
                .appEnvironment(
                    navigator: appViewModel, remoteViewModel: appViewModel.remoteViewModel, liveActivity: liveActivity,
                    routeDestination: RouteDestination { route in AnyView(Text(route.id).foregroundStyle(.secondary)) })
        } else {
            ProgressView()
                .task {
                    await setUp(appViewModel)
                    await appViewModel.settle()
                    isReady = true
                }
        }
    }
}

extension AppViewModel {
    /// 送った操作の通信などが終わるまで待つ
    package func settle() async {
        _ = await Introspector(root: self).waitUntilIdle()
    }
}

/// 偽物の 1 局目と、その局で放送中の番組
package enum FakeProgram {
    package static let channelCode = FakeCatalog.standard().stations[0].code
    package static var onAirID: Int { FakeCatalog.standard().onAir(code: channelCode, at: Date())?.id ?? 0 }
}
#endif
