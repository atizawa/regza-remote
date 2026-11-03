#if os(iOS)
import ActivityKit
import Foundation
import RegzaCore

public struct RegzaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// 古いバージョンで開始した Live Activity も読めるよう optional にしている
        public var kind: RegzaNowPlaying.Kind?
        public var channelName: String
        public var title: String
        public var chapterName: String
        public var position: Int
        public var duration: Int
        public var isAdvancing: Bool
        public var updatedAt: Date
        /// 直前に送ったボタン
        public var lastCommand: String?
        public var isConnected: Bool

        public init(nowPlaying: RegzaNowPlaying?, lastCommand: RegzaKey?, isConnected: Bool) {
            kind = nowPlaying?.kind
            channelName = nowPlaying?.channelName ?? ""
            title = nowPlaying?.title ?? ""
            chapterName = nowPlaying?.chapterName ?? ""
            position = nowPlaying?.position ?? 0
            duration = nowPlaying?.duration ?? 0
            isAdvancing = nowPlaying?.isAdvancing ?? false
            updatedAt = nowPlaying?.updatedAt ?? Date()
            self.lastCommand = lastCommand?.label
            self.isConnected = isConnected
        }

        public var isRecordingPlayback: Bool { kind == .recorded }

        /// 経過時間と進捗バーを出せるか (録画再生・放送とも)
        public var hasTimeline: Bool { duration > 0 }

        public var progress: Double {
            duration > 0 ? min(1, Double(position) / Double(duration)) : 0
        }

        /// 再生中なら Live Activity 側で時間を進められるよう、再生開始・終了時刻を逆算する
        public var playbackInterval: ClosedRange<Date>? {
            guard isAdvancing, duration > position else { return nil }
            let start = updatedAt.addingTimeInterval(-TimeInterval(position))
            return start...start.addingTimeInterval(TimeInterval(duration))
        }
    }

    public var tvName: String

    public init(tvName: String) {
        self.tvName = tvName
    }
}
#endif
