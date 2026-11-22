import Foundation
import Testing

@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaApp
@testable import RegzaDomain

/// 時刻で決まる判断 (放送中か・予約できるか) が、注入した時計の時刻で決まり、番組の終わりの境目で切り替わること
@MainActor
@Suite struct ClockBoundaryTests {
    @Test func currentProgramSwitchesAtProgramEnd() throws {
        let program = try TestData.program(id: 1, start: TestData.date(hour: 13))
        let next = try TestData.program(id: 2, start: program.end)
        let time = TestClock(program.end.addingTimeInterval(-1))
        let guideUseCase = GuideUseCase(
            guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: [program, next]),
            recordingRepository: RecordingRepositoryProtocolMock(reservations: []), clock: time.clock)
        let channel = TestData.channel(code: program.channelCode)

        // 終わる 1 秒前は、その番組が放送中
        #expect(guideUseCase.currentProgram(for: channel)?.id == program.id)
        // 終わった時刻からは、次の番組 (終わりの時刻は含めない)
        time.now = program.end
        #expect(guideUseCase.currentProgram(for: channel)?.id == next.id)
    }

    @Test func programDetailDecisionsFollowInjectedClock() throws {
        let program = try TestData.program(id: 1, start: TestData.date(hour: 13))
        let time = TestClock(program.start.addingTimeInterval(-1))
        let guideRepository = GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: [program])
        let guideUseCase = GuideUseCase(
            guideRepository: guideRepository, recordingRepository: RecordingRepositoryProtocolMock(reservations: []), clock: time.clock)
        let recordingUseCase = RecordingUseCase(
            recordingRepository: RecordingRepositoryProtocolMock(reservations: []), guideRepository: guideRepository, clock: time.clock)
        let viewModel = ProgramDetailViewModel(
            remoteViewModel: AppFactory.makeRemoteViewModel(
                tvUseCase: TVUseCaseProtocolMock(clock: time.clock, connection: .init(host: "192.0.2.1"))),
            guideUseCase: guideUseCase, recordingUseCase: recordingUseCase,
            streamUseCase: StreamUseCase(streamRepository: StreamRepositoryProtocolMock(streamHost: ""), guideRepository: guideRepository),
            program: try #require(guideUseCase.program(id: program.id, channelCode: program.channelCode)),
            channel: TestData.channel(code: program.channelCode)
        )

        // 始まる前: 予約できるが、選局はできない
        #expect(viewModel.state.canReserve)
        #expect(!viewModel.state.canTune)
        // 始まった時刻から: 放送中なので選局できる
        time.now = program.start
        #expect(viewModel.state.canTune)
        #expect(viewModel.state.canReserve)
        // 終わる 1 秒前までは放送中
        time.now = program.end.addingTimeInterval(-1)
        #expect(viewModel.state.canTune)
        // 終わった時刻からは、選局も予約もできない
        time.now = program.end
        #expect(!viewModel.state.canTune)
        #expect(!viewModel.state.canReserve)
    }
}

/// 共有の Swift は今の時刻を `Date()` で直接読まず、組み立てが渡す時計 (AppClock) から読む (時刻の境目をテストで確かめられるように)。
/// 偽物のサーバーは場面を作るために今の時刻を使ってよい。待つ時間は ContinuousClock で測る
@Suite struct ClockUsageGuardTests {
    @Test func sharedSwiftReadsTimeOnlyFromAppClock() throws {
        let sources = FakeServersContractTests.repository.appending(path: "Packages/RegzaCore/Sources")
        let allowed: Set<String> = ["RegzaDomain/Data/AppClock.swift"]
        let paths = try FileManager.default.subpathsOfDirectory(atPath: sources.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") && !$0.hasPrefix("RegzaFakeServers/") && !allowed.contains($0) }
        #expect(!paths.isEmpty)
        for path in paths {
            let lines = try String(contentsOf: sources.appending(path: path), encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated()
            where line.contains("Date()") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                Issue.record("\(path):\(index + 1) が Date() を直接読んでいます。時計 (AppClock) から読んでください")
            }
        }
    }
}
