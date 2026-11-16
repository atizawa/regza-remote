#if os(iOS)
import RegzaFakeServers
import RegzaPresentation
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("ライブ視聴") {
    FakePreview { $0.send(.play(channelCode: FakeProgram.channelCode)) }
}
#endif
