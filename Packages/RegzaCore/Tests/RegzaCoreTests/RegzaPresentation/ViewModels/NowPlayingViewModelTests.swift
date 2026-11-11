import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// いま映っているものの詳細のシートの ViewModel
@MainActor
@Suite struct NowPlayingViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func offersPowerOnOnlyInStandby() throws {
        let channels = try GuideViewModelTests().channels()

        let standbyViewModel = fixtures.makeApp(nowPlaying: NowPlayingData(kind: .standby), channels: channels).nowPlayingViewModel
        #expect(standbyViewModel.state.canPowerOn)
        #expect(standbyViewModel.state.title == "テレビ")

        let broadcastViewModel = fixtures.makeApp(
            nowPlaying: NowPlayingData(kind: .broadcast, channelCode: "JP-G00000001", title: "見本の番組", description: "見本の説明"),
            channels: channels
        ).nowPlayingViewModel
        let state = broadcastViewModel.state
        #expect(!state.canPowerOn)
        #expect(state.title == "視聴中")
        #expect(state.description == "見本の説明")
        // 見本のときは配信できないので、アプリで見るは出さない。タイムシフトの設定もないので最初から見るも出さない
        #expect(state.playableChannelCode == nil)
        #expect(!state.canStartOver)
    }
}
