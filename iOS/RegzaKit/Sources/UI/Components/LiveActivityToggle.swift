#if os(iOS)
import Localization
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
                Label(AppStrings.activityTitle, systemImage: "platter.filled.top.iphone")
            }
            .disabled(!LiveActivityController.areActivitiesEnabled)
            Text(
                LiveActivityController.areActivitiesEnabled
                    ? AppStrings.activityHelp
                    : AppStrings.activityDisabledHelp
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
#endif
