import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct NowPlayingTextTests {
    @Test func broadcastWithTitle() {
        let nowPlaying = NowPlayingData(kind: .broadcast, channelName: "テスト局", title: "テスト番組")
        #expect(nowPlaying.captionText == "テスト局")
        #expect(nowPlaying.headlineText == "テスト番組")
        #expect(nowPlaying.statusText == nil)
    }

    /// 番組名が取れない機種では、局名を大きく出し、上にジャンルを添える (同じ局名は重ねない)
    @Test func broadcastWithoutTitle() {
        let withGenre = NowPlayingData(kind: .broadcast, channelName: "テスト局", genre: "ニュース／報道")
        #expect(withGenre.captionText == "ニュース／報道")
        #expect(withGenre.headlineText == "テスト局")
        let withoutGenre = NowPlayingData(kind: .broadcast, channelName: "テスト局")
        #expect(withoutGenre.captionText == nil)
        #expect(NowPlayingData(kind: .broadcast).headlineText == "放送")
    }

    @Test func recorded() {
        let nowPlaying = NowPlayingData(kind: .recorded, channelName: "テスト局", title: "録画した番組")
        #expect(nowPlaying.captionText == "録画 · テスト局")
        #expect(nowPlaying.headlineText == "録画した番組")
        #expect(NowPlayingData(kind: .recorded, title: "録画した番組").captionText == "録画")
    }

    @Test func notShowingProgram() {
        #expect(NowPlayingData(kind: .standby).headlineText == "待機中")
        #expect(NowPlayingData(kind: .standby).captionText == nil)
        #expect(NowPlayingData(kind: .external).statusText == "外部入力")
        #expect(NowPlayingData(kind: .unknown).statusText == "接続済み")
    }
}
