import Foundation
import RegzaDomain

/// テレビの視聴状況の応答 (`status.htm`・`/v2/remote/play/status`) から、いま映っているもの (NowPlayingData) を作る
extension NowPlayingData {
    /// 旧 API (`status.htm`) から作る。
    /// `action` の値の意味は公開されていないため、前回からの再生位置の変化で再生中かを判定する
    init(status: RegzaStatus, previous: NowPlayingData?, now: Date = Date()) {
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
    init(playStatus: RegzaPlayStatus, now: Date = Date()) {
        switch playStatus.contentType {
        case "broadcast":
            let program = playStatus.currentProgram
            let start = program?.startTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            let duration = program?.duration ?? 0
            self.init(
                kind: .broadcast,
                channelName: program?.channelName ?? "",
                channelCode: program?.channel ?? "",
                title: Self.cleanTitle(program?.title ?? ""),
                description: program?.description ?? "",
                position: start.map { min(duration, max(0, Int(now.timeIntervalSince($0)))) } ?? 0,
                duration: duration,
                isAdvancing: start != nil && duration > 0,
                nextProgramStart: playStatus.nextProgram?.startTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                nextProgramDuration: playStatus.nextProgram?.duration ?? 0,
                genre: program?.genre?.first.flatMap(Self.genreName(code:)) ?? "",
                shortChannel: program.map { Self.shortChannelName($0.channelName ?? "") ?? Self.shortChannel(of: $0) } ?? "",
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

    /// 地デジはリモコンの番号 (`4ch`)、BS・CS は 3 桁の番号 (`BS181`)。種類は network_id で見分ける (BS は 4、CS は 6・7)
    static func shortChannel(of program: RegzaPlayStatus.Program) -> String {
        let networkId = program.channel.flatMap(BroadcastID.ids(channelCode:))?.networkId
        let number = program.channelNumber.map { String(format: "%03d", $0) } ?? ""
        switch networkId {
        case 4: return number.isEmpty ? "BS" : "BS\(number)"
        case 6, 7: return number.isEmpty ? "CS" : "CS\(number)"
        default:
            if let remote = program.remoteNumber, remote > 0 { return "\(remote)ch" }
            return number
        }
    }

    /// テレビの ARIB のジャンル (`00a8` なら 3 桁目の `a` が大分類) を名前にする
}
