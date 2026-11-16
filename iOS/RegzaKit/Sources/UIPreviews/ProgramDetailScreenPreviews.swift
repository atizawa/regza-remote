#if os(iOS)
import RegzaFakeServers
import RegzaPresentation
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("番組の詳細") {
    FakePreview { app in
        app.send(.selectTab(.guide))
        app.guideGridViewModel.send(.load)
        await app.settle()
        app.send(.push(.programDetail(programID: FakeProgram.onAirID, channelCode: FakeProgram.channelCode)))
    }
}
#endif
