#if os(iOS)
import RegzaPresentation

/// 引っ張って読み直すとき、送った操作の処理が終わるまで待つ。
@MainActor
func waitWhileBusy(_ viewModel: any Introspectable) async {
    try? await Task.sleep(for: .milliseconds(50))
    while viewModel.isBusy {
        try? await Task.sleep(for: .milliseconds(50))
    }
}
#endif
