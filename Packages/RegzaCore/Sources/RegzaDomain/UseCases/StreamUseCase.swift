import Foundation

/// ライブ視聴 (EPGStation): 配信を頼む・再生できるまで待つ・見続ける・止める
/// @mockable
@MainActor
public protocol StreamUseCaseProtocol: AnyObject {
    /// EPGStation のアドレス。未設定なら空
    var streamHost: String { get }

    /// 配信を頼める (EPGStation と番組表の両方を設定している)
    var canStream: Bool { get }

    func saveStreamHost(_ host: String)

    /// その局を EPGStation で見られるか
    func isPlayable(channelCode: String) -> Bool

    /// 前に止められずに残った、このアプリの配信を止めてから、その局の配信を頼む。配信の番号を返す
    func startLiveStream(channelCode: String) async throws(RegzaError) -> Int

    /// 再生できるようになるまで待ち、再生する URL を返す
    func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL

    /// まだ見ていることを知らせる (知らせないと EPGStation が配信を止める)
    func keep(streamID: Int) async

    /// 配信を止めてチューナーを空ける
    func stop(streamID: Int) async

    /// 止められずに残った、このアプリの配信を止める
    func cleanUp() async

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める
    func stopStalled() async
}

/// ライブ視聴 (EPGStation): 配信を頼む・再生できるまで待つ・見続ける・止める
@MainActor
public final class StreamUseCase: StreamUseCaseProtocol {
    private let streamRepository: any StreamRepositoryProtocol
    private let guideRepository: any GuideRepositoryProtocol

    public init(streamRepository: any StreamRepositoryProtocol, guideRepository: any GuideRepositoryProtocol) {
        self.streamRepository = streamRepository
        self.guideRepository = guideRepository
    }

    /// EPGStation のアドレス。未設定なら空
    public var streamHost: String { streamRepository.streamHost }
    /// 配信を頼める (EPGStation と番組表の両方を設定している)
    public var canStream: Bool { streamRepository.canStream && guideRepository.hasGuide }

    public func saveStreamHost(_ host: String) {
        streamRepository.saveStreamHost(host)
    }

    /// その局を EPGStation で見られるか
    public func isPlayable(channelCode: String) -> Bool {
        streamRepository.isPlayable(channelCode: channelCode)
    }

    /// 前に止められずに残った、このアプリの配信を止めてから、その局の配信を頼む。配信の番号を返す
    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        guard canStream else { throw .notConfigured }
        await streamRepository.cleanUp()
        guard canStream else { throw .notConfigured }
        return try await streamRepository.startLiveStream(channelCode: channelCode)
    }

    /// 再生できるようになるまで待ち、再生する URL を返す
    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL {
        guard canStream else { throw .notConfigured }
        return try await streamRepository.waitUntilReady(streamID: streamID)
    }

    /// まだ見ていることを知らせる (知らせないと EPGStation が配信を止める)
    public func keep(streamID: Int) async {
        await streamRepository.keep(streamID: streamID)
    }

    /// 配信を止めてチューナーを空ける
    public func stop(streamID: Int) async {
        await streamRepository.stop(streamID: streamID)
    }

    /// 止められずに残った、このアプリの配信を止める
    public func cleanUp() async {
        await streamRepository.cleanUp()
    }

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める
    public func stopStalled() async {
        await streamRepository.stopStalled()
    }
}
