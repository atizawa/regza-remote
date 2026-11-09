import Foundation
@testable import RegzaDomain

// 呼ばれたことを記録する偽物の Repository (UseCase のテストで使う)

/// 送ったキーと選局を記録するテレビ
@MainActor
final class RecordingTVRepository: TVRepositoryProtocol {
    var events: [String] = []
    var connection = RegzaConnection(host: "192.0.2.1")
    var channels: [RegzaChannel] = []
    var timeshiftSettings: RegzaTimeshiftSettings? { nil }
    var isSample: Bool { false }

    func loadChannels(force: Bool) async throws(RegzaError) {}
    func loadTimeshiftSettings() async {}
    func send(_ key: RegzaKey) async throws(RegzaError) { events.append("key \(key)") }

    func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        events.append("tune \(channel.code)")
        return nil
    }

    func seek(to seconds: Int) async throws(RegzaError) {}
    func refresh() async throws(RegzaError) -> RegzaNowPlaying { throw .notConfigured }
    func lastNowPlaying() async -> RegzaNowPlaying? { nil }
    func locateMovedTV() async -> RegzaConnection? { nil }
    func save(_ connection: RegzaConnection) async {}
    func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> { .failure(.notConfigured) }
    func pairingUserID() -> String { "" }
}

/// 頼んだ順番を記録する配信
@MainActor
final class RecordingStreamRepository: StreamRepositoryProtocol {
    var events: [String] = []
    var streamHost = "192.0.2.30"
    var canStream: Bool { true }

    func saveStreamHost(_ host: String) { streamHost = host }
    func isPlayable(channelCode: String) -> Bool { true }

    func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        events.append("start \(channelCode)")
        return 5
    }

    func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL { throw .notConfigured }
    func keep(streamID: Int) async {}
    func stop(streamID: Int) async { events.append("stop \(streamID)") }
    func cleanUp() async { events.append("cleanUp") }
    func stopStalled() async {}
}

/// テレビ 1 台と、192.0.2.2 で動いている EPGStation が見つかる機器探し
struct RecordingDeviceRepository: DeviceRepositoryProtocol {
    func devices() -> AsyncStream<RegzaDevice> {
        AsyncStream { continuation in
            continuation.yield(RegzaDevice(host: "192.0.2.10", model: "Z000", size: "55", supportsPIN: true))
            continuation.finish()
        }
    }

    func pairing(host: String, user: String) -> any PairingSession { SamplePairingSession() }
    func findGuideServers() async -> [String] { [] }
    func findStreamServers() async -> [String] { [] }
    func isStreamServer(host: String) async -> Bool { host == "192.0.2.2" }
}

struct SamplePairingSession: PairingSession {
    func start() async throws {}
    func confirm(pin: String) async throws -> RegzaConnection { RegzaConnection() }
    func cancel() async {}
}
