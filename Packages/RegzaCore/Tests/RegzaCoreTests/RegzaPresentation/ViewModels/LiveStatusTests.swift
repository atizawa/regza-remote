import Foundation
import Testing

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaSharedModels
@testable import ReservationsPresentation
@testable import SettingsPresentation

/// ロック画面や通知に出すもの (iOS の Live Activity と Android の Live Updates で同じになることの確認)
@Suite struct LiveStatusTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func item(
        kind: NowPlayingKind = .broadcast, channelName: String = "テスト局", title: String = "番組A",
        position: Int = 600, duration: Int = 1800, isAdvancing: Bool = true, nextStart: Date? = nil
    ) -> NowPlayingItem {
        NowPlayingItem(
            kind: kind, channelName: channelName, channelCode: "", title: title, description: "", chapterName: "第1話",
            genre: "ドラマ", position: position, duration: duration, isAdvancing: isAdvancing, updatedAt: now,
            nextProgramStart: nextStart, nextProgramDuration: nextStart == nil ? 0 : 3600, nextTitle: nextStart == nil ? "" : "番組B",
            shortChannel: "テスト", captionText: nil, headlineText: title, statusText: nil)
    }

    func state(_ nowPlaying: NowPlayingItem?, isConnected: Bool = true, lastCommand: String? = nil) -> RemoteState {
        RemoteState(isConfigured: true, nowPlaying: nowPlaying, isConnected: isConnected, lastCommandLabel: lastCommand)
    }

    @Test func broadcastTimes() {
        let status = state(item()).liveStatus
        #expect(status.programStart == now.addingTimeInterval(-600))
        #expect(status.programEnd == now.addingTimeInterval(1200))
        #expect(status.playbackStart == now.addingTimeInterval(-600))
        #expect(status.progress(at: now.addingTimeInterval(300)) == 0.5)
        #expect(status.progress(at: now.addingTimeInterval(9999)) == 1)
    }

    @Test func recordingStopsWhileDisconnected() {
        // つながらない間は録画の再生位置が分からないので止めておく。放送は時刻から進めてよい
        #expect(state(item(kind: .recorded), isConnected: false).liveStatus.playbackStart == nil)
        #expect(state(item(kind: .broadcast), isConnected: false).liveStatus.playbackStart != nil)
        #expect(state(item(kind: .recorded), isConnected: false).liveStatus.progress(at: now.addingTimeInterval(600)) == 600.0 / 1800)
    }

    @Test func switchesToNextProgramAfterEnd() {
        let nextStart = now.addingTimeInterval(1200)
        let status = state(item(nextStart: nextStart)).liveStatus

        #expect(status.displayed(isStale: false, at: now) == status)
        let next = status.displayed(isStale: false, at: nextStart.addingTimeInterval(1))
        #expect(next.title == "番組B")
        #expect(next.chapterName.isEmpty)
        #expect(next.programStart == nextStart)
        #expect(next.programEnd == nextStart.addingTimeInterval(3600))
        #expect(next.hasPredictedNextProgram)
        #expect(!next.hasProgramEnded(isStale: true, at: nextStart.addingTimeInterval(1)))
        // OS が少し前もって描き直すときは、古くなったことで終わったと見なす
        #expect(status.displayed(isStale: true, at: now).title == "番組B")
    }

    @Test func programEndedWithoutNextProgram() {
        let status = state(item()).liveStatus
        let end = now.addingTimeInterval(1200)
        #expect(status.displayed(isStale: false, at: end) == status)
        #expect(!status.hasProgramEnded(isStale: false, at: now))
        #expect(status.hasProgramEnded(isStale: false, at: end))
        // つながらないときは、直前の情報を出しているだけなので「終わりました」とは言わない
        #expect(!state(item(), isConnected: false).liveStatus.hasProgramEnded(isStale: false, at: end))
    }

    @Test func headlines() {
        #expect(state(item()).liveStatus.headline == .program)
        #expect(state(item(title: "")).liveStatus.headline == .channel)
        #expect(state(item(kind: .external, channelName: "", title: "")).liveStatus.headline == .external)
        #expect(state(item(kind: .standby, channelName: "", title: "")).liveStatus.headline == .standby)
        #expect(state(nil, isConnected: false).liveStatus.headline == .disconnected)
        #expect(state(nil, lastCommand: "音量+").liveStatus.headline == .sentCommand)
        #expect(state(nil).liveStatus.headline == .remote)
        #expect(state(item(), isConnected: false).liveStatus.hasInfoHeadline)
        #expect(!state(nil, isConnected: false).liveStatus.hasInfoHeadline)
        #expect(state(item(title: "")).liveStatus.headerName(tvName: "REGZA") == "REGZA")
        #expect(state(item()).liveStatus.headerName(tvName: "REGZA") == "テスト局")
    }

    @Test func keys() {
        #expect(state(item()).liveStatus.keys == [.channelDown, .channelUp, .volumeDown, .volumeUp])
        #expect(state(item()).liveStatus.compactKeys == [.channelDown, .channelUp, .mute])
        #expect(state(item(kind: .recorded)).liveStatus.compactKeys == [.skipBackward, .pause, .skipForward])
        #expect(state(item(kind: .recorded, isAdvancing: false)).liveStatus.keys == [.skipBackward, .play, .skipForward])
        #expect(state(item(kind: .standby)).liveStatus.compactKeys == [.power])
    }
}
