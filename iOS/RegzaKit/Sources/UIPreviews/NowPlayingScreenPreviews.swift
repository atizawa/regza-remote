#if os(iOS)
import RegzaPresentation
import SwiftUI

// 画面のプレビュー (ファイル名の画面)。偽物の場面を選び、操作を送ってこの画面まで進める

#Preview("視聴中の詳細") {
    FakePreview { $0.send(.showNowPlaying) }
}
#endif
