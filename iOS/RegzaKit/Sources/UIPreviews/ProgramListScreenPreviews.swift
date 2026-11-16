#if os(iOS)
import RegzaFakeServers
import RegzaPresentation
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("1 局の番組表") {
    FakePreview { app in
        app.send(.selectTab(.channels))
        app.send(.push(.channelPrograms(channelCode: FakeProgram.channelCode)))
    }
}
#endif
