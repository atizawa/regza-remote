#if os(iOS)
import LiveActivity
import SwiftUI

/// ロック画面と Dynamic Island に表示するかのスイッチ (Live Activity)
struct LiveActivityToggle: View {
    @Environment(LiveActivityModel.self) private var liveActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                isOn: Binding(
                    get: { liveActivity.isOn },
                    set: { isOn in Task { await liveActivity.set(isOn) } }
                )
            ) {
                Label("ロック画面と Dynamic Island に表示", systemImage: "platter.filled.top.iphone")
            }
            .disabled(!LiveActivityController.areActivitiesEnabled)
            Text(
                LiveActivityController.areActivitiesEnabled
                    ? "アプリを閉じていても、番組名とリモコンのボタンを表示します。"
                    : "iPhone の「設定」→「REGZAリモコン」で「ライブアクティビティ」をオンにすると使えます。"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
#endif
