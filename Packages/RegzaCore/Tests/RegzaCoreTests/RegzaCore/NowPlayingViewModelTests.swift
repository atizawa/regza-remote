import Foundation
import Testing
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// いま映っているものの詳細のシートの ViewModel
@MainActor
@Suite struct NowPlayingViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func offersPowerOnOnlyInStandby() throws {
        let channels = try GuideViewModelTests().channels()

        let standby = fixtures.sampleApp(channels: channels, nowPlaying: RegzaNowPlaying(kind: .standby)).nowPlaying
        #expect(standby.state.canPowerOn)
        #expect(standby.state.title == "テレビ")

        let broadcast = fixtures.sampleApp(
            channels: channels,
            nowPlaying: RegzaNowPlaying(kind: .broadcast, channelCode: "JP-G00000001", title: "見本の番組", description: "見本の説明")
        ).nowPlaying
        let state = broadcast.state
        #expect(!state.canPowerOn)
        #expect(state.title == "視聴中")
        #expect(state.description == "見本の説明")
        // 見本のときは配信できないので、アプリで見るは出さない。タイムシフトの設定もないので最初から見るも出さない
        #expect(state.playableChannelCode == nil)
        #expect(!state.canStartOver)
    }
}
