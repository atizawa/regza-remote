import Foundation
import Testing

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import ReservationsPresentation
@testable import SettingsPresentation

/// いま映っているものの詳細のシートの ViewModel
@MainActor
@Suite struct NowPlayingViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func offersPowerOnOnlyInStandby() throws {
        let channels = try GuideViewModelTests().channels()

        let standbyViewModel = fixtures.makeApp(
            nowPlaying: NowPlayingData(kind: .standby, updatedAt: Date()), channels: channels
        ).nowPlayingViewModel
        #expect(standbyViewModel.state.canPowerOn)
        #expect(standbyViewModel.state.title == "テレビ")

        let broadcastViewModel = fixtures.makeApp(
            nowPlaying: NowPlayingData(
                kind: .broadcast, channelCode: "JP-G00000001", title: "見本の番組", description: "見本の説明", updatedAt: Date()),
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
