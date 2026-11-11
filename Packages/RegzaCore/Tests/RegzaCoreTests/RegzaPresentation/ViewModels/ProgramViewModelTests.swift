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
        let program = try fixtures.program(startingIn: 3600)
        let programJSON = """
            [{"id":\(program.id),"eventId":\(program.eventId),"networkId":\(program.networkId),"serviceId":\(program.serviceId),"startAt":\(Int(program.start.timeIntervalSince1970 * 1000)),"duration":1800000,"name":"テスト番組"}]
            """
        let (remote, guide, recording, stream) = fixtures.makeModels { request in
            if request.url.path == "/api/programs" { return ViewModelFixtures.ok(programJSON) }
            return request.url.path.hasSuffix("reserves/new")
                ? ViewModelFixtures.status(200, #"{"status":2}"#) : ViewModelFixtures.status(200, #"{"status":0,"rsv_list":[]}"#)
        }
        await guide.saveGuideHost("192.0.2.2")
        await guide.loadGuidePrograms()
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: try #require(guide.program(id: program.id, channelCode: program.channelCode)),
            channel: try fixtures.channel(code: program.channelCode)
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
        let program = try fixtures.program(startingIn: 3600)
        let programJSON = """
            [{"id":\(program.id),"eventId":\(program.eventId),"networkId":\(program.networkId),"serviceId":\(program.serviceId),"startAt":\(Int(program.start.timeIntervalSince1970 * 1000)),"duration":1800000,"name":"テスト番組"}]
            """
        let (remote, guide, recording, stream) = fixtures.makeModels { request in
            ViewModelFixtures.ok(request.url.path == "/api/programs" ? programJSON : list)
        }
        await guide.saveGuideHost("192.0.2.2")
        await guide.loadGuidePrograms()
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream,
            program: try #require(guide.program(id: program.id, channelCode: program.channelCode)),
            channel: try fixtures.channel(code: program.channelCode)
        )
        await fixtures.send(viewModel) { $0.send(.appear) }
        #expect(viewModel.state.isReserved)
        #expect(viewModel.state.reservationIsSeries == true)
        #expect(viewModel.state.reservedText == "連ドラ予約済み（毎週）")
    }
}
