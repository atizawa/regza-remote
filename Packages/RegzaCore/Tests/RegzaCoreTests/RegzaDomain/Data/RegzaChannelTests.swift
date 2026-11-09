import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

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

@Suite struct SubchannelGroupingTests {
    /// テスト用のチャンネル (値はダミー)。remote はリモコン番号、representative は代表の印
    private func channel(_ number: Int, remote: Int, representative: Bool = false) -> RegzaChannel {
        let json = """
            {"channel":"JP-G\(number)","channel_number":\(number),"rcu_channel_number":\(remote),"name":"局\(number)",\
            "ex_channel_number":"DUV_\(number)","show_setting":"\(representative ? "SHOW_REPRESENT" : "SHOW")"}
            """
        return try! JSONDecoder().decode(RegzaChannel.self, from: Data(json.utf8))
    }

    @Test func keepsRepresentativeEvenIfNotFirst() {
        let channels = [channel(12, remote: 1), channel(11, remote: 1, representative: true), channel(21, remote: 2)]
        #expect(channels.groupingSubchannels().map(\.number) == [11, 21])
    }

    @Test func keepsFirstWhenNoRepresentative() {
        let channels = [channel(11, remote: 1), channel(12, remote: 1), channel(13, remote: 1)]
        #expect(channels.groupingSubchannels().map(\.number) == [11])
    }

    @Test func keepsChannelsWithoutRemoteNumber() {
        let channels = [channel(55, remote: 0), channel(56, remote: 0)]
        #expect(channels.groupingSubchannels().map(\.number) == [55, 56])
    }

    @Test func channelListShowsWatchedSubchannelAndDifferentProgram() {
        let channels = [channel(11, remote: 1, representative: true), channel(12, remote: 1), channel(13, remote: 1)]
        let watching = RegzaChannel.channelList(channels, in: .terrestrial, nowPlayingChannelCode: "JP-G12")
        #expect(watching.map(\.number) == [11, 12])
        let programs = [11: "ニュース", 12: "ニュース", 13: "野球中継"]
        let different = RegzaChannel.channelList(channels, in: .terrestrial, nowPlayingChannelCode: nil) { programs[$0.number] }
        #expect(different.map(\.number) == [11, 13])
    }

    @Test func preferredBand() {
        let bands: [RegzaChannel.Band] = [.terrestrial, .bs]
        #expect(RegzaChannel.Band.preferred(among: bands, selected: .bs, nowPlaying: .terrestrial) == .bs)
        #expect(RegzaChannel.Band.preferred(among: bands, selected: nil, nowPlaying: .bs) == .bs)
        // 選んでいたものがなければ、いま見ているもの、それもなければ最初のもの
        #expect(RegzaChannel.Band.preferred(among: bands, selected: .cs, nowPlaying: nil) == .terrestrial)
    }

    @Test func showsSubchannelsTheCallerAsksFor() {
        let channels = [channel(11, remote: 1, representative: true), channel(12, remote: 1), channel(13, remote: 1)]
        let shown = channels.groupingSubchannels { subchannel, representative in
            #expect(representative.number == 11)
            return subchannel.number == 13
        }
        #expect(shown.map(\.number) == [11, 13])
    }
}
