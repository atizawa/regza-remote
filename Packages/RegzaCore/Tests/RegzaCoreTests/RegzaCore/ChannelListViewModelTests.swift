import Foundation
import Testing
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// チャンネル一覧の ViewModel
@MainActor
@Suite struct ChannelListViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func channelListExplainsUnsupportedModel() async {
        let live = LiveModels(transport: FakeTransport { _ in ViewModelFixtures.status(404) })
        let viewModel = live.app.channelList
        await fixtures.send(viewModel) { $0.send(.reload) }
        #expect(viewModel.state.loadErrorMessage == "この機種はチャンネル一覧の取得に対応していません。")
        #expect(!viewModel.state.isLoading)
    }

    @Test func channelListExplainsRejectedTune() async throws {
        let live = LiveModels(transport: FakeTransport { request in
            request.url.path.hasSuffix("channel_list") ? ViewModelFixtures.status(200, ViewModelFixtures.channelList) : ViewModelFixtures.status(200, #"{"status":1}"#)
        })
        let viewModel = live.app.channelList
        await fixtures.send(viewModel) { $0.send(.reload) }
        #expect(viewModel.state.bands == [RegzaChannel.Band.terrestrial, .bs])
        let row = try #require(viewModel.state.rows.first)
        #expect(!row.isSubchannel)

        await fixtures.send(viewModel) { $0.send(.tune(row.code)) }

        #expect(viewModel.state.tuneError == "テスト局１ に切り替えられませんでした。テレビの電源が入っているか確認してください。")
        #expect(viewModel.state.tuningCode == nil)
        #expect(viewModel.state.rows.first?.isNowPlaying == false)
    }
}
