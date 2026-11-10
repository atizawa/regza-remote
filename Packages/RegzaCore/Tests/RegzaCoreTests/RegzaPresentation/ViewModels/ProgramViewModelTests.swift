import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
@testable import RegzaSample

/// 番組の詳細の ViewModel
@MainActor
@Suite struct ProgramViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func programDetailExplainsRejectedReservation() async throws {
        let (remote, guide, recording, stream) = fixtures.makeModels { request in
            request.url.path.hasSuffix("reserves/new")
                ? ViewModelFixtures.status(200, #"{"status":2}"#) : ViewModelFixtures.status(200, #"{"status":0,"rsv_list":[]}"#)
        }
        let program = try fixtures.program(startingIn: 3600)
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: program, channel: try fixtures.channel(code: program.channelCode)
        )
        #expect(viewModel.state.canReserve)
        #expect(!viewModel.state.canTune)

        await fixtures.send(viewModel) { $0.send(.reserve(series: false)) }

        #expect(viewModel.state.message == "テレビが予約を受け付けませんでした (2)。テレビの予約一覧や録画機器を確認してください。")
        #expect(viewModel.state.reserving == nil)
        #expect(viewModel.state.reserveCount == 0)
    }

    @Test func programDetailDescribesSeriesReservation() async throws {
        let list =
            #"{"status":0,"rsv_list":[{"rsv_id":"1","title":"テスト番組","channel":"JP-G00010001","epg_content_id":"JP-0000000100010002","start_time":4000000000,"duration":1800,"repeat":"weekly","series_rec":"true"}]}"#
        let (remote, guide, recording, stream) = fixtures.makeModels { _ in ViewModelFixtures.status(200, list) }
        let program = try fixtures.program(startingIn: 3600)
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: program, channel: try fixtures.channel(code: program.channelCode)
        )
        await fixtures.send(viewModel) { $0.send(.appear) }
        #expect(viewModel.state.isReserved)
        #expect(viewModel.state.reservationIsSeries == true)
        #expect(viewModel.state.reservedText == "連ドラ予約済み（毎週）")
    }
}
