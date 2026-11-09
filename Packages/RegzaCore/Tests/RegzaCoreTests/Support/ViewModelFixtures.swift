import Foundation
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// ViewModel のテストで使う、テレビの応答の見本と、画面の ViewModel の組み立て
@MainActor
struct ViewModelFixtures {
    nonisolated static let channelList = """
        {"status":0,"total":2,"channel_list":[\
        {"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","ex_channel_number":"DUV_011-1","name":"テスト局１","show_setting":"SHOW_REPRESENT"},\
        {"channel_number":183,"rcu_channel_number":8,"channel":"JP-G00000002","ex_channel_number":"DBS_183","name":"テストBS","show_setting":"SHOW"}]}
        """
    nonisolated static let reservationList = """
        {"status":0,"rsv_list":[\
        {"rsv_id":"1","title":"テスト番組","channel":"JP-G00000001","epg_content_id":"JP-0000000000010002","start_time":4000000000,"duration":1800}]}
        """

    nonisolated static func ok(_ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }

    func makeModels(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse)
        -> (RemoteViewModel, GuideUseCase, RecordingUseCase, StreamUseCase) {
        let live = LiveModels(transport: FakeTransport(respond))
        return (live.remote, live.guide, live.recording, live.stream)
    }

    /// 見本の Repository でつないだもの (テレビにつながない)
    func sampleApp(channels: [RegzaChannel], nowPlaying: RegzaNowPlaying? = nil, programs: [MirakurunProgram] = []) -> AppViewModel {
        AppViewModel.sample(
            connection: RegzaConnection(host: "192.0.2.1"), nowPlaying: nowPlaying, channels: channels,
            guideHost: programs.isEmpty ? "" : "192.0.2.2", programs: programs
        )
    }

    nonisolated static func status(_ code: Int, _ body: String = "") -> HTTPResponse {
        HTTPResponse(statusCode: code, headers: [:], body: Data(body.utf8))
    }

    /// 番組 (network 1・service 1・event 2)。テレビの番組 ID は JP-0000000100010002
    func program(startingIn offset: TimeInterval) throws -> MirakurunProgram {
        let start = Int((Date().timeIntervalSince1970 + offset) * 1000)
        let json = #"{"id":100010002,"eventId":2,"networkId":1,"serviceId":1,"startAt":\#(start),"duration":1800000,"name":"テスト番組"}"#
        return try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
    }

    func channel(code: String) throws -> RegzaChannel {
        let json = #"{"channel_number":11,"channel":"\#(code)","name":"テスト局"}"#
        return try JSONDecoder().decode(RegzaChannel.self, from: Data(json.utf8))
    }

    /// 操作を送り、処理が終わるまで待つ
    func send<Model: Introspectable>(_ viewModel: Model, _ send: (Model) -> Void) async {
        send(viewModel)
        _ = await Introspector(root: viewModel).waitUntilIdle()
    }
}
