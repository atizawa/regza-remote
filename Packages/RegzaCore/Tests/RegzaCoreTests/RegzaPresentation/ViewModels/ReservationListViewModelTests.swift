import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
@testable import RegzaSample

/// 録画予約の一覧の ViewModel
@MainActor
@Suite struct ReservationListViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func reservationListSplitsScheduledAndWaiting() async {
        let list = """
            {"status":0,"rsv_list":[\
            {"rsv_id":"1","title":"これからの番組","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":4000000000,"duration":1800},\
            {"rsv_id":"2","title":"次の回待ち","channel":"JP-G00000009","epg_content_id":"JP-0000000000010003","start_time":1000000000,"duration":1800,"repeat":"weekly","series_rec":"true"}]}
            """
        let (remoteViewModel, _, recordingUseCase, _) = fixtures.makeModels { request in
            request.url.path.hasSuffix("channel_list")
                ? ViewModelFixtures.status(200, ViewModelFixtures.channelList) : ViewModelFixtures.status(200, list)
        }
        let viewModel = ReservationListViewModel(remoteViewModel: remoteViewModel, recordingUseCase: recordingUseCase)
        await fixtures.send(viewModel) { $0.send(.load) }

        let state = viewModel.state
        #expect(state.hasLoaded)
        // 読み終わったら、引っ張って読み直したときの印を消す
        #expect(!state.isLoading)
        #expect(state.scheduled.map(\.id) == ["1"])
        #expect(state.waiting.map(\.id) == ["2"])
        #expect(state.scheduled.first?.channelName == "テスト局１")
        #expect(state.scheduled.first?.isRecording == false)
        // チャンネル一覧にない局は名前を出さない
        #expect(state.waiting.first?.channelName == nil)
    }
}
