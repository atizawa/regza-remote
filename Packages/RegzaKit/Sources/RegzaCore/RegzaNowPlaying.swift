import Foundation

/// 画面や Live Activity に出すための視聴状況。
public struct RegzaNowPlaying: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// 地デジ・BS・CS の放送
        case broadcast
        /// 録画番組の再生
        case recorded
        /// HDMI などの外部入力
        case external
        /// 待機中など
        case standby
        /// 旧 API で録画再生中でないとき (放送か外部入力かは分からない)
        case unknown
    }

    public var kind: Kind
    public var channelName: String
    public var title: String
    public var description: String
    public var chapterName: String
    /// 再生位置・放送開始からの経過 (秒)
    public var position: Int
    /// 番組の長さ (秒)
    public var duration: Int
    /// 再生位置が進んでいるか
    public var isAdvancing: Bool
    /// 放送中の次の番組の開始時刻
    public var nextProgramStart: Date?
    public var updatedAt: Date

    public init(
        kind: Kind = .unknown, channelName: String = "", title: String = "", description: String = "",
        chapterName: String = "", position: Int = 0, duration: Int = 0, isAdvancing: Bool = false,
        nextProgramStart: Date? = nil, updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.channelName = channelName
        self.title = title
        self.description = description
        self.chapterName = chapterName
        self.position = position
        self.duration = duration
        self.isAdvancing = isAdvancing
        self.nextProgramStart = nextProgramStart
        self.updatedAt = updatedAt
    }

    /// 旧 API (`status.htm`) から作る。
    /// `action` の値の意味は公開されていないため、前回からの再生位置の変化で再生中かを判定する
    public init(status: RegzaStatus, previous: RegzaNowPlaying?, now: Date = Date()) {
        let title = Self.cleanTitle(status.titleName)
        let sameTitle = previous?.title == title && previous?.duration == status.totalTime
        self.init(
            kind: status.isPlayingRecording ? .recorded : .unknown,
            channelName: status.channelName,
            title: title,
            chapterName: status.chapterName,
            position: status.titleTime,
            duration: status.totalTime,
            isAdvancing: sameTitle && (previous.map { status.titleTime > $0.position } ?? false),
            updatedAt: now
        )
    }

    /// v2 API (`/v2/remote/play/status`) から作る
    public init(playStatus: RegzaPlayStatus, now: Date = Date()) {
        switch playStatus.contentType {
        case "broadcast":
            let program = playStatus.currentProgram
            let start = program?.startTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            let duration = program?.duration ?? 0
            self.init(
                kind: .broadcast,
                channelName: program?.channelName ?? "",
                title: Self.cleanTitle(program?.title ?? ""),
                description: program?.description ?? "",
                position: start.map { min(duration, max(0, Int(now.timeIntervalSince($0)))) } ?? 0,
                duration: duration,
                isAdvancing: start != nil && duration > 0,
                nextProgramStart: playStatus.nextProgram?.startTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                updatedAt: now
            )
        case "recorded":
            let program = playStatus.recordedProgram
            let action = playStatus.playingAction
            self.init(
                kind: .recorded,
                channelName: program?.channelName ?? "",
                title: Self.cleanTitle(program?.title ?? ""),
                description: program?.description ?? "",
                chapterName: action?.chapterName ?? "",
                position: action?.position ?? 0,
                duration: action?.totalTime ?? program?.duration ?? 0,
                isAdvancing: action?.playState == "play",
                updatedAt: now
            )
        case "external":
            self.init(kind: .external, updatedAt: now)
        default:
            self.init(kind: .standby, updatedAt: now)
        }
    }

    public var isRecordingPlayback: Bool { kind == .recorded }

    /// 経過時間と進捗バーを出せるか
    public var hasTimeline: Bool { duration > 0 }

    /// 放送中の番組の終了時刻
    public var programEnd: Date? {
        guard kind == .broadcast, duration > 0 else { return nil }
        return updatedAt.addingTimeInterval(TimeInterval(duration - position))
    }

    public var progress: Double {
        duration > 0 ? min(1, Double(position) / Double(duration)) : 0
    }

    /// `[字]` `[新]` などの番組記号を取り除く
    static func cleanTitle(_ title: String) -> String {
        var result = title
        while let open = result.firstIndex(where: { $0 == "[" || $0 == "［" }),
              let close = result[open...].firstIndex(where: { $0 == "]" || $0 == "］" }),
              result.distance(from: open, to: close) <= 3 {
            result.removeSubrange(open...close)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
