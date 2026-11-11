import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

/// 実機の `/v2/remote/play/status` のレスポンス (録画の ID はダミー値に置き換え済み)
@Suite struct PlayStatusTests {
    let broadcast = """
        {"status":0,"content_type":"broadcast","epg_info_current":{"channel_number":41,"duration":7800,"rcu_channel_number":4,"start_time":1793664000,"channel":"JP-G7fe20410","channel_name":"日テレ１","description":"","epg_content_id":"JP-00007fe20410299d","prg_rsv_id":"","prg_rsv_type":"none","title":"","genre":["0022","0004","0052"]},"epg_info_next":{"channel_number":41,"duration":600,"rcu_channel_number":4,"start_time":1793671800,"channel":"JP-G7fe20410","channel_name":"日テレ１","description":"","epg_content_id":"JP-00007fe20410299e","prg_rsv_id":"","prg_rsv_type":"none","title":"","genre":["0024"]},"recorded_prg_info":null,"playing_action_info":null}
        """

    let recorded = """
        {"status":0,"content_type":"recorded","recorded_prg_info":{"channel_number":21,"duration":3600,"rcu_channel_number":2,"rec_copy_num":10,"rec_start_time":1782727198,"start_time":1782727200,"channel":"JP-G7fe10408","channel_name":"ＮＨＫＥテレ１東京","description":"ファミリーコンサートを中継収録して放送！","rec_content_id":"00000000","rec_storage_id":"0000","title":"おかあさんといっしょ　ファミリーコンサート２０２６春〜きっと、あしたは〜[字]","genre":["00a8"]},"playing_action_info":{"action":2,"chapter_index":0,"position":866,"total_time":3603,"chapter_name":"","play_state":"play","chapter_time":null,"chapter_position":null},"epg_info_current":null,"epg_info_next":null}
        """

    func decode(_ json: String) throws -> RegzaPlayStatus {
        try JSONDecoder().decode(RegzaPlayStatus.self, from: Data(json.utf8))
    }

    @Test func broadcastUsesProgramTimes() throws {
        let now = Date(timeIntervalSince1970: 1_793_664_000 + 600)
        let nowPlaying = NowPlayingData(playStatus: try decode(broadcast), now: now)
        #expect(nowPlaying.kind == .broadcast)
        #expect(nowPlaying.channelName == "日テレ１")
        #expect(nowPlaying.channelCode == "JP-G7fe20410")
        #expect(nowPlaying.title.isEmpty)
        #expect(nowPlaying.position == 600)
        #expect(nowPlaying.duration == 7800)
        #expect(nowPlaying.isAdvancing)
        #expect(nowPlaying.nextProgramStart == Date(timeIntervalSince1970: 1_793_671_800))
        #expect(nowPlaying.nextProgramDuration == 600)
        // "0022" の大分類 2 は情報/ワイドショー
        #expect(nowPlaying.genre == "情報")
        // 局名が短くなれば局名を出す
        #expect(nowPlaying.shortChannel == "日テレ")
        #expect(nowPlaying.programEnd == Date(timeIntervalSince1970: 1_793_664_000 + 7800))
    }

    @Test func recordedUsesPlayingAction() throws {
        let nowPlaying = NowPlayingData(playStatus: try decode(recorded))
        #expect(nowPlaying.kind == .recorded)
        #expect(nowPlaying.title == "おかあさんといっしょ　ファミリーコンサート２０２６春〜きっと、あしたは〜")
        #expect(nowPlaying.channelName == "ＮＨＫＥテレ１東京")
        #expect(nowPlaying.position == 866)
        #expect(nowPlaying.duration == 3603)
        #expect(nowPlaying.isAdvancing)
        #expect(!nowPlaying.description.isEmpty)
        #expect(nowPlaying.programEnd == nil)
    }

    @Test func shortChannelNames() {
        #expect(NowPlayingData.shortChannelName("ＮＨＫ総合１・東京") == "NHK総合")
        #expect(NowPlayingData.shortChannelName("ＮＨＫＥテレ１東京") == "NHKEテレ")
        #expect(NowPlayingData.shortChannelName("ＴＢＳ１") == "TBS")
        #expect(NowPlayingData.shortChannelName("ＴＯＫＹＯ　ＭＸ１") == "TOKYO MX")
        #expect(NowPlayingData.shortChannelName("ＢＳフジ・１８１") == "BSフジ")
        #expect(NowPlayingData.shortChannelName("テレビ朝日") == "テレビ朝日")
        #expect(NowPlayingData.shortChannelName("ザ・シネマ") == "ザ・シネマ")
        #expect(NowPlayingData.shortChannelName("ＮＥＷＳ２４") == "NEWS24")
        #expect(NowPlayingData.shortChannelName("−") == nil)
        // 収まらない長さなら nil (番号で出す)
        #expect(NowPlayingData.shortChannelName("とても長い放送局の名前") == nil)
    }

    @Test func shortChannelForSatellite() throws {
        let bs =
            #"{"status":0,"content_type":"broadcast","epg_info_current":{"channel":"JP-G000400b5","channel_number":181,"rcu_channel_number":8,"start_time":1700000000,"duration":600}}"#
        #expect(NowPlayingData(playStatus: try decode(bs)).shortChannel == "BS181")
        let cs =
            #"{"status":0,"content_type":"broadcast","epg_info_current":{"channel":"JP-G00070037","channel_number":55,"start_time":1700000000,"duration":600}}"#
        #expect(NowPlayingData(playStatus: try decode(cs)).shortChannel == "CS055")
    }

    @Test func otherKinds() throws {
        #expect(NowPlayingData(playStatus: try decode(#"{"status":0,"content_type":"external"}"#)).kind == .external)
        #expect(NowPlayingData(playStatus: try decode(#"{"status":0,"content_type":"other"}"#)).kind == .standby)
    }
}
