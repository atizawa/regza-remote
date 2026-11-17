public import Foundation

/// ロック画面や通知に出し続ける「いま映っているもの」(iOS の Live Activity、Android の Live Updates)。
/// リモコンの state から作り、番組が終わったあとの表示・見出し・出すボタンもここで決める。
/// アプリが止まっている間も OS が表示を続けるので、時刻を渡して、その時点で出すものを作れるようにしている
public struct LiveStatus: Equatable, Sendable {
    public var kind: NowPlayingKind
    public var channelName: String
    /// 狭い場所に出すチャンネル。短くした局名、収まらなければ番号
    public var shortChannel: String
    public var title: String
    public var chapterName: String
    /// 番組名が取れないときに添えるジャンル
    public var genre: String
    /// 再生位置と長さ (秒)。updatedAt の時点のもの
    public var position: Int
    public var duration: Int
    public var isAdvancing: Bool
    public var updatedAt: Date
    /// 放送中の次の番組の開始時刻・長さ (秒)・番組名。分からなければ nil・0・空
    public var nextProgramStart: Date?
    public var nextProgramDuration: Int
    public var nextTitle: String
    /// 番組の終了時刻を過ぎたので、次の番組が始まったものとして出している (テレビからは取っていない)
    public var hasPredictedNextProgram: Bool
    /// 直前に送ったボタン (「音量+」など)
    public var lastCommand: String?
    public var isConnected: Bool

    public init(
        kind: NowPlayingKind, channelName: String, shortChannel: String, title: String, chapterName: String, genre: String,
        position: Int, duration: Int, isAdvancing: Bool, updatedAt: Date, nextProgramStart: Date?, nextProgramDuration: Int,
        nextTitle: String, hasPredictedNextProgram: Bool, lastCommand: String?, isConnected: Bool
    ) {
        self.kind = kind
        self.channelName = channelName
        self.shortChannel = shortChannel
        self.title = title
        self.chapterName = chapterName
        self.genre = genre
        self.position = position
        self.duration = duration
        self.isAdvancing = isAdvancing
        self.updatedAt = updatedAt
        self.nextProgramStart = nextProgramStart
        self.nextProgramDuration = nextProgramDuration
        self.nextTitle = nextTitle
        self.hasPredictedNextProgram = hasPredictedNextProgram
        self.lastCommand = lastCommand
        self.isConnected = isConnected
    }

    public var isRecordingPlayback: Bool { kind == .recorded }

    /// 経過時間と進捗を出せるか (録画の再生・放送とも)
    public var hasTimeline: Bool { duration > 0 }

    /// updatedAt の時点の進み具合 (0〜1)
    public var progress: Double {
        duration > 0 ? min(1, Double(position) / Double(duration)) : 0
    }

    /// 再生が進んでいれば、位置 0 にあたる時刻 (録画は再生を始めた時刻、放送は番組の開始時刻)。止まっていれば nil
    public var playbackStart: Date? {
        guard isAdvancing, duration > position else { return nil }
        return updatedAt.addingTimeInterval(-TimeInterval(position))
    }

    /// 放送中の番組の開始時刻
    public var programStart: Date? {
        guard kind == .broadcast, duration > 0 else { return nil }
        return updatedAt.addingTimeInterval(-TimeInterval(position))
    }

    /// 放送中の番組の終了時刻
    public var programEnd: Date? {
        guard kind == .broadcast, duration > 0 else { return nil }
        return updatedAt.addingTimeInterval(TimeInterval(duration - position))
    }

    /// date の時点の進み具合 (0〜1)。再生が止まっていれば updatedAt の時点のもの
    public func progress(at date: Date) -> Double {
        guard let start = playbackStart else { return progress }
        return min(1, max(0, date.timeIntervalSince(start) / Double(duration)))
    }

    /// 番組が終わったあとに出すもの。次の番組が分かっていれば、同じチャンネルのまま次の番組が始まったものとして出す
    /// (チャンネルが変えられていたら、次にアプリが状態を取ったときに直る)。
    ///
    /// - Parameter isStale: OS が「表示が古くなった」として描き直している。iOS は番組の終了時刻に古くなるようにしており、
    ///   描き直しを少し前もって行うことがあるので、時刻だけでなくこれでも終わったと見なす (時刻だけで決める OS は false)
    public func displayed(isStale: Bool, at date: Date) -> LiveStatus {
        guard isConnected, let end = programEnd, isStale || end <= date,
            let nextStart = nextProgramStart, nextProgramDuration > 0
        else { return self }
        var next = self
        next.title = nextTitle
        next.chapterName = ""
        next.genre = ""
        next.updatedAt = nextStart
        next.position = 0
        next.duration = nextProgramDuration
        next.isAdvancing = true
        next.nextProgramStart = nil
        next.nextProgramDuration = 0
        next.nextTitle = ""
        next.hasPredictedNextProgram = true
        return next
    }

    /// 放送中の番組が終わったのに、次の番組が分からない (displayed で切り替えたあとに読む)
    public func hasProgramEnded(isStale: Bool, at date: Date) -> Bool {
        guard isConnected, !hasPredictedNextProgram, let end = programEnd else { return false }
        return isStale || end <= date
    }

    /// 機種によっては放送中の番組名が返らないので、代わりにチャンネル名を見出しにする
    public var showsChannelAsTitle: Bool {
        title.isEmpty && kind == .broadcast && !channelName.isEmpty
    }

    /// 見出しに出すもの
    public var headline: LiveHeadline {
        if !title.isEmpty { return .program }
        if showsChannelAsTitle { return .channel }
        switch kind {
        case .external: return .external
        case .standby: return .standby
        case .broadcast, .recorded, .unknown: break
        }
        if !isConnected { return .disconnected }
        return lastCommand == nil ? .remote : .sentCommand
    }

    /// 番組名・チャンネル名・入力などを見出しに出している (つながらないときは直前に取得した情報)。
    /// このときつながっていなければ、つながらないことを小さく添える
    public var hasInfoHeadline: Bool {
        switch headline {
        case .program, .channel, .external, .standby: true
        case .disconnected, .sentCommand, .remote: false
        }
    }

    /// 見出しの上の小さなラベル。見出しと同じチャンネル名を重ねて出さない
    public func headerName(tvName: String) -> String {
        channelName.isEmpty || showsChannelAsTitle ? tvName : channelName
    }

    /// 押しやすいよう数を絞ったボタン。待機中は電源だけ、録画は再生操作、放送はチャンネルと音量
    public var keys: [RegzaKey] {
        if kind == .standby { return [.power] }
        return isRecordingPlayback
            ? [.skipBackward, isAdvancing ? .pause : .play, .skipForward]
            : [.channelDown, .channelUp, .volumeDown, .volumeUp]
    }

    /// 3 つまでしか並べられない場所 (Android の通知) のボタン。放送は音量を消音にまとめる
    public var compactKeys: [RegzaKey] {
        guard kind != .standby, !isRecordingPlayback else { return keys }
        return [.channelDown, .channelUp, .mute]
    }
}
