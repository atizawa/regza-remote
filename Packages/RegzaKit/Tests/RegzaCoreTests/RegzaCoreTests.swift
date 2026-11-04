import Foundation
import Testing
@testable import RegzaCore

@Suite struct MD5Tests {
    @Test func knownVectors() {
        #expect(MD5.hex("") == "d41d8cd98f00b204e9800998ecf8427e")
        #expect(MD5.hex("The quick brown fox jumps over the lazy dog") == "9e107d9d372bb6826bd81d3542a419d6")
        #expect(MD5.hex(String(repeating: "a", count: 1000)) == "cabe45dcc9ae5b66ba86600cca6b8ba8")
    }
}

@Suite struct DigestTests {
    // RFC 2617 3.5 の例
    let header = """
        Digest realm="testrealm@host.com", qop="auth,auth-int", \
        nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"
        """

    @Test func parsesChallenge() throws {
        let challenge = try #require(DigestChallenge(header: header))
        #expect(challenge.realm == "testrealm@host.com")
        #expect(challenge.nonce == "dcd98b7102dd2f0e8b11d0f600bfb0c093")
        #expect(challenge.qop == "auth")
        #expect(challenge.opaque == "5ccc069c403ebaf9f0171e9517f40e41")
    }

    @Test func rfcResponse() throws {
        let challenge = try #require(DigestChallenge(header: header))
        let authorization = challenge.authorization(
            method: "GET", uri: "/dir/index.html",
            user: "Mufasa", password: "Circle Of Life",
            nonceCount: 1, clientNonce: "0a4f113b"
        )
        #expect(authorization.contains("response=\"6629fae49393a05397450978507c4ef1\""))
        #expect(authorization.contains("nc=00000001"))
    }

    @Test func rejectsBasic() {
        #expect(DigestChallenge(header: "Basic realm=\"x\"") == nil)
    }
}

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

@Suite struct DiscoveryTests {
    /// `/public/feature` の応答の形 (値はダミー)
    let feature = """
        {"status":0,"device_type":"DTV","dtv_version":"0","id":"","ipc_version":"v2","mac":"00:00:00:00:00:00","model":"Z000","month":"Jan","region":"JP","size":"55","year":"2000","dtv_feature":["PVR"],"ipc_feature":["V1Support","PIN_Auth"]}
        """

    @Test func parsesFeature() throws {
        let device = try #require(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data(feature.utf8)))
        #expect(device.name == "REGZA 55Z000")
        #expect(device.supportsPIN)
        #expect(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data(#"{"status":0,"device_type":"BD"}"#.utf8)) == nil)
        #expect(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data("<html>".utf8)) == nil)
    }

    @Test func enumeratesSubnet() throws {
        let address = try #require(IPv4Network.parse("192.168.0.10"))
        let hosts = IPv4Network(address: address, mask: 0xFFFF_FF00).hosts
        #expect(hosts.count == 253)
        #expect(hosts.first == "192.168.0.1")
        #expect(hosts.last == "192.168.0.254")
        #expect(!hosts.contains("192.168.0.10"))
        // /16 は自分の /24 だけ調べる
        #expect(IPv4Network(address: address, mask: 0xFFFF_0000).hosts == hosts)
    }
}

@Suite struct PairingCryptoTests {
    func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    @Test func sha1() {
        #expect(hex(SHA1.digest(Array("abc".utf8))) == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect(hex(SHA1.digest([])) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    // RFC 6070
    @Test func pbkdf2() {
        let password = Array("password".utf8), salt = Array("salt".utf8)
        #expect(hex(SHA1.pbkdf2(password: password, salt: salt, iterations: 1, length: 20)) == "0c60c80f961f0e71f3a9b524af6012062fe037a6")
        #expect(hex(SHA1.pbkdf2(password: password, salt: salt, iterations: 4096, length: 20)) == "4b007901b765489abead49d926f721d065a429c1")
    }

    // FIPS-197 C.1
    @Test func aesBlock() throws {
        let key = try #require([UInt8](hex: "000102030405060708090a0b0c0d0e0f"))
        let block = try #require([UInt8](hex: "69c4e0d86a7b0430d8cdb78070b4c55a"))
        let aes = try #require(AES128(key: key))
        let plain = aes.decryptBlock(block)
        #expect(hex(plain) == "00112233445566778899aabbccddeeff")
    }

    /// Python の hashlib.pbkdf2_hmac と openssl enc -aes-128-cbc で作った値
    @Test func decryptsPassword() {
        let encrypted = "c4909140d2f5f81261a1bd1d715fdc2c53ce4586b6d6dde3f16390198fee8f2c"
        #expect(RegzaPairing.decryptPassword(encrypted, pin: "1234", salt: "abcdef0123456789") == "Ab3$xyZ9-Test.Password_01")
        #expect(RegzaPairing.decryptPassword(encrypted, pin: "1235", salt: "abcdef0123456789") == nil)
    }

    @Test func userID() {
        let parts = RegzaPairing.makeUserID().split(separator: "-")
        #expect(parts.count == 6)
        #expect(parts.allSatisfy { $0.count == 2 && UInt8($0, radix: 16) != nil })
        #expect(RegzaPairing.makeUserID() != RegzaPairing.makeUserID())
    }
}

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
        let nowPlaying = RegzaNowPlaying(playStatus: try decode(broadcast), now: now)
        #expect(nowPlaying.kind == .broadcast)
        #expect(nowPlaying.channelName == "日テレ１")
        #expect(nowPlaying.channelCode == "JP-G7fe20410")
        #expect(nowPlaying.title.isEmpty)
        #expect(nowPlaying.position == 600)
        #expect(nowPlaying.duration == 7800)
        #expect(nowPlaying.isAdvancing)
        #expect(nowPlaying.nextProgramStart == Date(timeIntervalSince1970: 1_793_671_800))
        #expect(nowPlaying.nextProgramDuration == 600)
        #expect(nowPlaying.programEnd == Date(timeIntervalSince1970: 1_793_664_000 + 7800))
    }

    @Test func recordedUsesPlayingAction() throws {
        let nowPlaying = RegzaNowPlaying(playStatus: try decode(recorded))
        #expect(nowPlaying.kind == .recorded)
        #expect(nowPlaying.title == "おかあさんといっしょ　ファミリーコンサート２０２６春〜きっと、あしたは〜")
        #expect(nowPlaying.channelName == "ＮＨＫＥテレ１東京")
        #expect(nowPlaying.position == 866)
        #expect(nowPlaying.duration == 3603)
        #expect(nowPlaying.isAdvancing)
        #expect(!nowPlaying.description.isEmpty)
        #expect(nowPlaying.programEnd == nil)
    }

    @Test func otherKinds() throws {
        #expect(RegzaNowPlaying(playStatus: try decode(#"{"status":0,"content_type":"external"}"#)).kind == .external)
        #expect(RegzaNowPlaying(playStatus: try decode(#"{"status":0,"content_type":"other"}"#)).kind == .standby)
    }
}

@Suite struct ChannelTests {
    let json = """
        {"status":0,"total":3,"channel_list":[\
        {"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","ex_channel_number":"DUV_011-1","ex_name_info":"テスト局","name":"テスト局１","network_type":"","show_setting":"SHOW_REPRESENT"},\
        {"channel_number":183,"rcu_channel_number":8,"channel":"JP-G00000002","ex_channel_number":"DBS_183","ex_name_info":"テストBS","name":"テストBS・１８３","network_type":"","show_setting":"SHOW"},\
        {"channel_number":55,"channel":"JP-G00000003","ex_channel_number":"DCS_055","name":"テストCS"}]}
        """

    @Test func decodesChannelList() throws {
        let channels = try #require(try JSONDecoder().decode(RegzaChannelList.self, from: Data(json.utf8)).channels)
        #expect(channels.map(\.band) == [.terrestrial, .bs, .cs])
        #expect(channels.map(\.formattedNumber) == ["011", "183", "055"])
        #expect(channels[0].isRepresentative)
        #expect(!channels[1].isRepresentative)
        #expect(channels[1].remoteNumber == 8)
        #expect(channels[2].remoteNumber == 0)
        #expect(channels[0].code == "JP-G00000001")
    }
}

@Suite struct ReservationTests {
    @Test func decodesReservations() throws {
        let json = """
            {"status":0,"rsv_list":[\
            {"rsv_id":"1","title":"テスト番組　＃２[字]","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":1000000000,"duration":1800,"repeat":"weekly","series_rec":"true"},\
            {"rsv_id":"2","title":"単発","channel":"JP-G00000002","start_time":2000000000,"duration":600,"repeat":"none","series_rec":"false"}]}
            """
        let list = try #require(try JSONDecoder().decode(RegzaReservationList.self, from: Data(json.utf8)).reservations)
        #expect(list[0].title == "テスト番組　＃２")
        #expect(list[0].repeatLabel == "毎週")
        #expect(list[0].epgContentID == "JP-0000000000010002")
        // Mirakurun から組み立てた ID と大文字・小文字が違っても同じ番組とみなす
        #expect(list[0].isReservation(of: "jp-0000000000010002"))
        #expect(list[0].isReservation(of: Mirakurun.epgContentID(networkId: 0, serviceId: 1, eventId: 2)))
        #expect(!list[0].isReservation(of: "JP-0000000000010003"))
        #expect(!list[0].isReservation(of: ""))
        #expect(list[0].isSeries)
        #expect(!list[0].isScheduled(now: Date(timeIntervalSince1970: 1_500_000_000)))
        #expect(list[1].repeatLabel == nil)
        #expect(list[1].isScheduled(now: Date(timeIntervalSince1970: 1_500_000_000)))
        #expect(list[1].end == Date(timeIntervalSince1970: 2_000_000_600))
    }
}

@Suite struct MirakurunTests {
    @Test func convertsTVIDs() throws {
        #expect(Mirakurun.channelCode(networkId: 0x7FE0, serviceId: 0x0400) == "JP-G7fe00400")
        #expect(Mirakurun.channelCode(networkId: 4, serviceId: 0xB7) == "JP-G000400b7")
        let ids = try #require(Mirakurun.ids(channelCode: "JP-G000400b7"))
        #expect(ids.networkId == 4 && ids.serviceId == 0xB7)
        #expect(Mirakurun.programID(epgContentID: "JP-00007fe1040820b6") == 32737 * 10_000_000_000 + 1032 * 100_000 + 0x20B6)
        // 番組の決まっていない ID (event_id 0xffff)
        #expect(Mirakurun.programID(epgContentID: "JP-00007fe30418ffff") == nil)
        #expect(Mirakurun.programID(epgContentID: "") == nil)
    }

    @Test func decodesProgram() throws {
        let json = """
            {"id":327370103200001,"eventId":1,"serviceId":1032,"networkId":32737,"startAt":1700000000000,"duration":1800000,\
            "name":"テスト番組🈑🈖[字]","description":"説明","extended":{"出演者":"テスト","番組内容":"内容"},\
            "genres":[{"lv1":7,"lv2":0,"un1":15,"un2":15}]}
            """
        let program = try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
        #expect(program.name == "テスト番組")
        #expect(program.channelCode == "JP-G7fe10408")
        #expect(program.epgContentID == "JP-00007fe104080001")
        #expect(Mirakurun.programID(epgContentID: program.epgContentID) == program.id)
        #expect(program.start == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(program.end == Date(timeIntervalSince1970: 1_700_001_800))
        #expect(program.extended.map(\.title) == ["番組内容", "出演者"])
        #expect(program.genreName == "アニメ")
        #expect(program.isOnAir(at: Date(timeIntervalSince1970: 1_700_000_100)))
        #expect(!program.isOnAir(at: Date(timeIntervalSince1970: 1_700_001_800)))
    }
}

@Suite struct SwitchingTests {
    @Test func switchingKeys() {
        #expect(RegzaKey.enter.mayStartContentSwitch)
        #expect(RegzaKey.play.mayStartContentSwitch)
        #expect(!RegzaKey.volumeUp.mayStartContentSwitch)
        #expect(!RegzaKey.num1.mayStartContentSwitch)
    }

    @Test func probeIgnoresPlaybackPosition() {
        let playing = RegzaStatus(text: "action=2\ntitle_no=100\ntitle_name=テスト\nch_code=G00000001\ntitle_time=10")
        var later = playing
        later.titleTime = 12
        #expect(RegzaRemote.Probe(playing) == RegzaRemote.Probe(later))
        // 切り替わりの最中は値が空になる
        let switching = RegzaStatus(text: "action=0\ntitle_no=0\ntitle_name=\nch_code=G00000000\ntitle_time=0")
        #expect(RegzaRemote.Probe(playing) != RegzaRemote.Probe(switching))
    }

    @Test func advancesWithoutPlayStatus() {
        let start = Date(timeIntervalSince1970: 1_000)
        let broadcast = RegzaNowPlaying(kind: .broadcast, position: 100, duration: 600, isAdvancing: true, updatedAt: start)
        let movedOn = RegzaRemote.advanced(broadcast, with: RegzaStatus(), now: start.addingTimeInterval(30))
        #expect(movedOn.position == 130)
        #expect(movedOn.updatedAt == start.addingTimeInterval(30))

        let recorded = RegzaNowPlaying(kind: .recorded, title: "テスト", position: 50, duration: 600, isAdvancing: false, updatedAt: start)
        let status = RegzaStatus(text: "action=2\ntitle_name=テスト\ntotal_time=600\ntitle_time=52")
        let played = RegzaRemote.advanced(recorded, with: status, now: start.addingTimeInterval(2))
        #expect(played.position == 52)
        #expect(played.isAdvancing)
    }
}

@Suite struct TimeshiftTests {
    // テレビの設定「平日 19 時〜翌 1 時、土日 8 時〜翌 1 時」のときの値
    let json = """
        {"status":0,"timeshift_enabled":"true","target_channel":["JP-G00000001"],"active_time_list":[\
        {"active_time":"00f80001","day_of_week":"mon"},{"active_time":"00f80001","day_of_week":"tue"},\
        {"active_time":"00f80001","day_of_week":"wed"},{"active_time":"00f80001","day_of_week":"thu"},\
        {"active_time":"00f80001","day_of_week":"fri"},{"active_time":"00ffff01","day_of_week":"sat"},\
        {"active_time":"00ffff01","day_of_week":"sun"}]}
        """

    func jst(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    @Test func startOverOnlyWhileRecording() throws {
        let settings = try JSONDecoder().decode(RegzaTimeshiftSettings.self, from: Data(json.utf8))
        let channel = "JP-G00000001"
        // 2026-11-04 は水曜日
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 21:00"), now: jst("2026-11-04 21:30")))
        // 録画は 19 時からなので、18:30 に始まった番組は最初からは見られない
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 18:30"), now: jst("2026-11-04 19:30")))
        // 平日の昼は録画していない
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 12:00"), now: jst("2026-11-04 12:10")))
        // 翌日 0 時台まではつながっている
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 23:30"), now: jst("2026-11-05 00:40")))
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-05 00:30"), now: jst("2026-11-05 01:10")))
        // 土曜は 8 時から
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-07 09:00"), now: jst("2026-11-07 09:20")))
        // 対象でない局
        #expect(!settings.canStartOver(channelCode: "JP-G00000002", programStart: jst("2026-11-04 21:00"), now: jst("2026-11-04 21:30")))
    }
}
