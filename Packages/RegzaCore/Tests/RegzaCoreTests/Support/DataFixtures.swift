import Foundation

@testable import RegzaDomain

/// UseCase のテストで使う、決まった日時・局・番組・予約
enum TestData {
    /// 2026-11-07 (土) のその時刻 (この端末の時間帯で)
    static func date(day: Int = 7, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// 決まった「今」(11/7 13:00)。表記や放送中かを、いつ走らせても同じにする
    static let now = date(hour: 13)

    /// 地デジの局と、そのサブチャンネル、BS、CS
    static func channels() throws -> [ChannelData] {
        let json = """
            [{"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","name":"テスト局１","ex_channel_number":"DUV_011-1","show_setting":"SHOW_REPRESENT"},
             {"channel_number":12,"rcu_channel_number":1,"channel":"JP-G00000011","name":"テスト局１サブ","ex_channel_number":"DUV_012-1","show_setting":"SHOW"},
             {"channel_number":181,"channel":"JP-G00040001","name":"テストBS","ex_channel_number":"DBS_181","show_setting":"SHOW_REPRESENT"},
             {"channel_number":55,"channel":"JP-G00060001","name":"テストCS","ex_channel_number":"DCS_055","show_setting":"SHOW"}]
            """
        return try JSONDecoder().decode([ChannelData].self, from: Data(json.utf8))
    }

    static func program(
        id: Int, networkId: Int = 0, serviceId: Int = 1, start: Date, minutes: Int = 45, name: String = "見本の番組", genre: Int? = nil
    ) throws -> ProgramData {
        let genres = genre.map { #","genres":[{"lv1":\#($0)}]"# } ?? ""
        let json = """
            {"id":\(id),"eventId":\(id),"networkId":\(networkId),"serviceId":\(serviceId),\
            "startAt":\(Int(start.timeIntervalSince1970 * 1000)),"duration":\(minutes * 60_000),"name":"\(name)"\(genres)}
            """
        return try JSONDecoder().decode(ProgramData.self, from: Data(json.utf8))
    }

    static func reservation(
        id: String, channelCode: String, epgContentID: String = "", start: Date, minutes: Int = 30, series: Bool = false
    ) throws -> ReservationData {
        let json = """
            {"rsv_id":"\(id)","title":"予約\(id)","channel":"\(channelCode)","epg_content_id":"\(epgContentID)",\
            "start_time":\(Int(start.timeIntervalSince1970)),"duration":\(minutes * 60)\(series ? #","repeat":"weekly","series_rec":"true""# : "")}
            """
        return try JSONDecoder().decode(ReservationData.self, from: Data(json.utf8))
    }
}

extension TestData {
    static let channelListJSON = """
        {"status":0,"total":2,"channel_list":[\
        {"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","ex_channel_number":"DUV_011-1","name":"テスト局１","show_setting":"SHOW_REPRESENT"},\
        {"channel_number":183,"rcu_channel_number":8,"channel":"JP-G00000002","ex_channel_number":"DBS_183","name":"テストBS","show_setting":"SHOW"}]}
        """
    nonisolated static let reservationListJSON = """
        {"status":0,"rsv_list":[\
        {"rsv_id":"1","title":"テスト番組","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":4000000000,"duration":1800}]}
        """

    /// 番組 (network 1・service 1・event 2)。テレビの番組 ID は JP-0000000100010002
    static func futureProgram(startingIn offset: TimeInterval) throws -> ProgramData {
        let start = Int((Date().timeIntervalSince1970 + offset) * 1000)
        let json = #"{"id":100010002,"eventId":2,"networkId":1,"serviceId":1,"startAt":\#(start),"duration":1800000,"name":"テスト番組"}"#
        return try JSONDecoder().decode(ProgramData.self, from: Data(json.utf8))
    }

    static func channel(code: String) -> ChannelItem {
        ChannelItem(
            code: code, name: "テスト局", numberText: "011", programName: nil,
            isNowPlaying: false, hasPrograms: false, canStartOver: false, isSubchannel: false)
    }
}
