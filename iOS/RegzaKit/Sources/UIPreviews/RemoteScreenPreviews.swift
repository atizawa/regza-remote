#if os(iOS)
import RegzaFakeServers
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("リモコン") {
    FakePreview()
}

#Preview("リモコン (録画を再生中)") {
    FakePreview(.recordedPlaying)
}

#Preview("リモコン (テレビにつながらない)") {
    FakePreview(.tvUnreachable)
}

#Preview("テレビが未登録") {
    FakePreview(.notRegistered)
}
#endif
