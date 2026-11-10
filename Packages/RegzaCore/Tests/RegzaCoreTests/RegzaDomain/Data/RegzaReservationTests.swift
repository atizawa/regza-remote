import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

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
        #expect(list[0].isReservation(of: BroadcastID.epgContentID(networkId: 0, serviceId: 1, eventId: 2)))
        #expect(!list[0].isReservation(of: "JP-0000000000010003"))
        #expect(!list[0].isReservation(of: ""))
        #expect(list[0].isSeries)
        #expect(!list[0].isScheduled(now: Date(timeIntervalSince1970: 1_500_000_000)))
        #expect(list[1].repeatLabel == nil)
        #expect(list[1].isScheduled(now: Date(timeIntervalSince1970: 1_500_000_000)))
        #expect(list[1].end == Date(timeIntervalSince1970: 2_000_000_600))
    }
}
