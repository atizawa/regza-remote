import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct MirakurunTests {
    @Test func convertsTVIDs() throws {
        #expect(BroadcastID.channelCode(networkId: 0x7FE0, serviceId: 0x0400) == "JP-G7fe00400")
        #expect(BroadcastID.channelCode(networkId: 4, serviceId: 0xB7) == "JP-G000400b7")
        let ids = try #require(BroadcastID.ids(channelCode: "JP-G000400b7"))
        #expect(ids.networkId == 4 && ids.serviceId == 0xB7)
        #expect(BroadcastID.programID(epgContentID: "JP-00007fe1040820b6") == 32737 * 10_000_000_000 + 1032 * 100_000 + 0x20B6)
        // 番組の決まっていない ID (event_id 0xffff)
        #expect(BroadcastID.programID(epgContentID: "JP-00007fe30418ffff") == nil)
        #expect(BroadcastID.programID(epgContentID: "") == nil)
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
        #expect(BroadcastID.programID(epgContentID: program.epgContentID) == program.id)
        #expect(program.start == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(program.end == Date(timeIntervalSince1970: 1_700_001_800))
        #expect(program.extended.map(\.title) == ["番組内容", "出演者"])
        #expect(program.genreName == "アニメ")
        #expect(program.isOnAir(at: Date(timeIntervalSince1970: 1_700_000_100)))
        #expect(!program.isOnAir(at: Date(timeIntervalSince1970: 1_700_001_800)))
    }
}
