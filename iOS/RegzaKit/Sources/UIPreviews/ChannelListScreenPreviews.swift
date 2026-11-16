#if os(iOS)
import RegzaFakeServers
import RegzaPresentation
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("チャンネル一覧") {
    FakePreview { $0.send(.selectTab(.channels)) }
}

#Preview("チャンネル一覧 (登録がない)") {
    FakePreview(.emptyChannels) { $0.send(.selectTab(.channels)) }
}
#endif
