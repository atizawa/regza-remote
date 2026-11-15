#if os(iOS)
import ActivityKit
import Foundation
import RegzaPresentation

public struct RegzaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// いま映っているものの種類 (NowPlayingKind と同じ値。Live Activity に保存するので Codable にする)
        public enum Kind: String, Codable, Sendable {
            case broadcast, recorded, external, standby, unknown
        }

        /// 古いバージョンで開始した Live Activity も読めるよう optional にしている
        public var kind: Kind?
        public var channelName: String
        public var title: String
        public var chapterName: String
        public var position: Int
        public var duration: Int
        public var isAdvancing: Bool
        public var updatedAt: Date
        /// 放送中の次の番組の開始時刻 (古いバージョンで開始した Live Activity にはない)
        public var nextProgramStart: Date?
        /// 次の番組の長さ (秒) と番組名。番組が終わった時刻に、アプリが止まっていても次の番組の表示に切り替える
        public var nextProgramDuration: Int?
        public var nextTitle: String?
        /// 放送中の番組のジャンル。番組名が取れないときに添える (前のバージョンの状態にはない)
        public var genre: String?
        /// Dynamic Island の狭い場所に出すチャンネル (`NHK総合`、収まらなければ `4ch` `BS181`)
        public var shortChannel: String?
        /// `displayed(isStale:)` で次の番組の表示に切り替えたもの (アプリからは送らない)。
        /// 前のバージョンの状態も読めるよう optional にしている
        public var hasPredictedNextProgram: Bool?
        /// 直前に送ったボタン
        public var lastCommand: String?
        public var isConnected: Bool

        /// リモコンの state (画面と同じもの) から作る
        public init(_ remote: RemoteState) {
            self.init(remote.liveStatus)
        }

        /// 出すもの (iOS と Android で共有の LiveStatus) から作る
        public init(_ status: LiveStatus) {
            kind = Kind(rawValue: status.kind.rawValue)
            channelName = status.channelName
            title = status.title
            chapterName = status.chapterName
            position = status.position
            duration = status.duration
            isAdvancing = status.isAdvancing
            updatedAt = status.updatedAt
            nextProgramStart = status.nextProgramStart
            nextProgramDuration = status.nextProgramDuration
            nextTitle = status.nextTitle
            genre = status.genre
            shortChannel = status.shortChannel
            hasPredictedNextProgram = status.hasPredictedNextProgram
            lastCommand = status.lastCommand
            isConnected = status.isConnected
        }

        /// 共有の LiveStatus に戻す。前のバージョンで開始した Live Activity にない値は、ないものとして読む
        public var status: LiveStatus {
            LiveStatus(
                kind: kind.flatMap { NowPlayingKind(rawValue: $0.rawValue) } ?? .unknown,
                channelName: channelName, shortChannel: shortChannel ?? "", title: title, chapterName: chapterName,
                genre: genre ?? "", position: position, duration: duration, isAdvancing: isAdvancing, updatedAt: updatedAt,
                nextProgramStart: nextProgramStart, nextProgramDuration: nextProgramDuration ?? 0, nextTitle: nextTitle ?? "",
                hasPredictedNextProgram: hasPredictedNextProgram ?? false, lastCommand: lastCommand, isConnected: isConnected)
        }

        public var isRecordingPlayback: Bool { status.isRecordingPlayback }

        /// 経過時間と進捗バーを出せるか (録画再生・放送とも)
        public var hasTimeline: Bool { status.hasTimeline }

        public var progress: Double { status.progress }

        /// 放送中の番組の終了時刻
        public var programEnd: Date? { status.programEnd }

        /// 番組が終わった後の表示 (LiveStatus.displayed)。放送中は staleDate を番組の終了時刻にしているので、
        /// stale になったら番組は終わっている
        public func displayed(isStale: Bool, at date: Date = Date()) -> ContentState {
            let displayed = status.displayed(isStale: isStale, at: date)
            return displayed == status ? self : ContentState(displayed)
        }

        /// 再生中なら Live Activity 側で時間を進められるよう、再生開始・終了時刻を逆算する
        public var playbackInterval: ClosedRange<Date>? {
            guard let start = status.playbackStart else { return nil }
            return start...start.addingTimeInterval(TimeInterval(duration))
        }
    }

    public var tvName: String

    public init(tvName: String) {
        self.tvName = tvName
    }
}
#endif
