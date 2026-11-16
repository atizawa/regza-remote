#if os(iOS)
import LiveActivity
import RegzaFakeServers
import RegzaPresentation
import SwiftUI
import UI

/// 画面のプレビューの準備。振る舞いのテストと同じ偽物のテレビ・録画サーバー (RegzaFakeServers) で AppViewModel を組み立て、
/// 操作を送って見せたい画面まで進めてから、アプリと同じ AppScreen で描く (本物にはつながない)
struct FakePreview: View {
    @State private var appViewModel: AppViewModel
    @State private var liveActivity: LiveActivityModel
    @State private var isReady = false
    private let setUp: @MainActor (AppViewModel) async -> Void

    /// - Parameters:
    ///   - scenario: 偽物の場面
    ///   - setUp: 描く前に送る操作 (タブを選ぶ・画面を開くなど)。送ったあとは、通信などが終わるまで待ってから描く
    init(_ scenario: FakeScenario.Name = .standard, setUp: @escaping @MainActor (AppViewModel) async -> Void = { _ in }) {
        let appViewModel = FakeApp.makeAppViewModel(scenario: FakeScenario(scenario))
        _appViewModel = State(initialValue: appViewModel)
        _liveActivity = State(initialValue: LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel))
        self.setUp = setUp
    }

    var body: some View {
        if isReady {
            AppScreen(appViewModel: appViewModel, liveActivity: liveActivity)
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
    func settle() async {
        _ = await Introspector(root: self).waitUntilIdle()
    }
}

/// 偽物の 1 局目と、その局で放送中の番組
enum FakeProgram {
    static let channelCode = FakeCatalog.standard().stations[0].code
    static var onAirID: Int { FakeCatalog.standard().onAir(code: channelCode, at: Date())?.id ?? 0 }
}
#endif
