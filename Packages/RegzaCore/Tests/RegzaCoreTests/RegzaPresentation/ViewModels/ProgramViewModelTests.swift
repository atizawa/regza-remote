import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// 番組の詳細の ViewModel
@MainActor
@Suite struct ProgramViewModelTests {
    let fixtures = ViewModelFixtures()

    @Test func programDetailExplainsRejectedReservation() async throws {
        let program = try TestData.futureProgram(startingIn: 3600)
        let programJSON = """
            [{"id":\(program.id),"eventId":\(program.eventId),"networkId":\(program.networkId),"serviceId":\(program.serviceId),"startAt":\(Int(program.start.timeIntervalSince1970 * 1000)),"duration":1800000,"name":"テスト番組"}]
            """
        let (remoteViewModel, guideUseCase, recordingUseCase, streamUseCase) = fixtures.makeHTTPModels { request in
            if request.url.path == "/api/programs" { return FakeHTTPTransport.response(200, programJSON) }
            return request.url.path.hasSuffix("reserves/new")
                ? FakeHTTPTransport.response(200, #"{"status":2}"#) : FakeHTTPTransport.response(200, #"{"status":0,"rsv_list":[]}"#)
        }
        await guideUseCase.saveGuideHost("192.0.2.2")
        await guideUseCase.loadGuidePrograms()
        let viewModel = ProgramDetailViewModel(
            remoteViewModel: remoteViewModel, guideUseCase: guideUseCase, recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            program: try #require(guideUseCase.program(id: program.id, channelCode: program.channelCode)),
            channel: TestData.channel(code: program.channelCode)
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
        let program = try TestData.futureProgram(startingIn: 3600)
        let programJSON = """
            [{"id":\(program.id),"eventId":\(program.eventId),"networkId":\(program.networkId),"serviceId":\(program.serviceId),"startAt":\(Int(program.start.timeIntervalSince1970 * 1000)),"duration":1800000,"name":"テスト番組"}]
            """
        let (remoteViewModel, guideUseCase, recordingUseCase, streamUseCase) = fixtures.makeHTTPModels { request in
            FakeHTTPTransport.response(200, request.url.path == "/api/programs" ? programJSON : list)
        }
        await guideUseCase.saveGuideHost("192.0.2.2")
        await guideUseCase.loadGuidePrograms()
        let viewModel = ProgramDetailViewModel(
            remoteViewModel: remoteViewModel, guideUseCase: guideUseCase, recordingUseCase: recordingUseCase, streamUseCase: streamUseCase,
            program: try #require(guideUseCase.program(id: program.id, channelCode: program.channelCode)),
            channel: TestData.channel(code: program.channelCode)
        )
        await fixtures.send(viewModel) { $0.send(.appear) }
        #expect(viewModel.state.isReserved)
        #expect(viewModel.state.reservationIsSeries == true)
        #expect(viewModel.state.reservedText == "連ドラ予約済み（毎週）")
    }
}
