import Foundation

/// ライブ視聴 (EPGStation): 配信を頼む・再生できるまで待つ・見続ける・止める
@MainActor
public final class StreamUseCase {
    private let stream: any StreamRepository

    public init(stream: any StreamRepository) {
        self.stream = stream
    }

    /// EPGStation のアドレス。未設定なら空
    public var streamHost: String { stream.streamHost }
    /// 配信を頼める (EPGStation と番組表の両方を設定している)
    public var canStream: Bool { stream.canStream }

    public func saveStreamHost(_ host: String) {
        stream.saveStreamHost(host)
    }

    /// その局を EPGStation で見られるか
    public func isPlayable(channelCode: String) -> Bool {
        stream.isPlayable(channelCode: channelCode)
    }

    /// 前に止められずに残った、このアプリの配信を止めてから、その局の配信を頼む。配信の番号を返す
    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        await stream.cleanUp()
        return try await stream.startLiveStream(channelCode: channelCode)
    }

    /// 再生できるようになるまで待ち、再生する URL を返す
    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL {
        try await stream.waitUntilReady(streamID: streamID)
    }

    /// まだ見ていることを知らせる (知らせないと EPGStation が配信を止める)
    public func keep(streamID: Int) async {
        await stream.keep(streamID: streamID)
    }

    /// 配信を止めてチューナーを空ける
    public func stop(streamID: Int) async {
        await stream.stop(streamID: streamID)
    }

    /// 止められずに残った、このアプリの配信を止める
    public func cleanUp() async {
        await stream.cleanUp()
    }

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める
    public func stopStalled() async {
        await stream.stopStalled()
    }
}
