import SwiftUI

/// 今の時刻を決めた間隔で読み直し、中身を描き直す (Android の rememberCurrentTime に当たる)。
/// 時刻で変わる state (放送中か・予約できるか) は、content の中で読むと間隔ごとに読み直される。
/// state を読み直す間隔は、Android の橋渡しが state を読み直す間隔 (30 秒) とそろえる
package struct CurrentTimeView<Content: View>: View {
    private let intervalSeconds: TimeInterval
    private let content: (Date) -> Content

    package init(intervalSeconds: TimeInterval = 30, @ViewBuilder content: @escaping (Date) -> Content) {
        self.intervalSeconds = intervalSeconds
        self.content = content
    }

    package var body: some View {
        TimelineView(.periodic(from: .now, by: intervalSeconds)) { context in
            content(context.date)
        }
    }
}
