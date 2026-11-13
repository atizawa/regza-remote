import RegzaApp

/// SceneStorage と共有 ViewModel の間をつなぐ。復帰のたびに古い入力を上書きしないよう、復元は初回だけ行う。
@MainActor
final class AppStateRestoration {
    private let appViewModel: AppViewModel
    private var hasRestored = false

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    func restore(_ json: String) {
        guard !hasRestored else { return }
        hasRestored = true
        appViewModel.restore(json)
    }

    /// 初回の読み戻し前に、空の初期状態で保存データを置き換えない。
    func save() -> String? {
        guard hasRestored else { return nil }
        return appViewModel.restorationJSON
    }
}
