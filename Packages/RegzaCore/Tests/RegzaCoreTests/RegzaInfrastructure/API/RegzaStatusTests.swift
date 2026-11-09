import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct StatusTests {
    let text = """
        action=2
        title_no=12
        title_name=[字]アニメ　日常　＜新＞＜全１２回＞「日常の第一話」
        total_time=1502
        ch_code=G7fd10808
        ch_name=ＮＨＫＥテレ１大阪
        rec_day=2012-01-07T17:55:02
        genre=0700ffff
        title_time=29
        chapter_no=1
        chapter_time=26
        chapter_name=
        """

    @Test func parsesStatus() {
        let status = RegzaStatus(text: text)
        #expect(status.action == 2)
        #expect(status.totalTime == 1502)
        #expect(status.titleTime == 29)
        #expect(status.channelName == "ＮＨＫＥテレ１大阪")
        #expect(status.chapterName.isEmpty)
        #expect(status.isPlayingRecording)
    }

    @Test func idleStatus() {
        let status = RegzaStatus(text: "action=0\ntitle_name=null\ntotal_time=0\n")
        #expect(!status.isPlayingRecording)
    }

    @Test func nowPlayingDetectsAdvance() {
        var status = RegzaStatus(text: text)
        let first = RegzaNowPlaying(status: status, previous: nil)
        #expect(first.title == "アニメ　日常　＜新＞＜全１２回＞「日常の第一話」")
        #expect(!first.isAdvancing)

        status.titleTime = 31
        #expect(RegzaNowPlaying(status: status, previous: first).isAdvancing)

        status.titleTime = 29
        #expect(!RegzaNowPlaying(status: status, previous: first).isAdvancing)
    }

    @Test func legacyIdleIsUnknownKind() {
        let nowPlaying = RegzaNowPlaying(status: RegzaStatus(text: "action=0\n"), previous: nil)
        #expect(nowPlaying.kind == .unknown)
    }

    @Test func decodesShiftJIS() throws {
        let data = try #require("ch_name=ＮＨＫ総合".data(using: .shiftJIS))
        #expect(RegzaClient.decode(data) == "ch_name=ＮＨＫ総合")
    }
}
