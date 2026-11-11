import Foundation

/// 録画サーバー EPGStation のライブ配信。EPGStation は配信を自動では止めないので、
/// このアプリが頼んだ配信を覚えておき、止められなかった配信はあとで止める
/// @mockable
@MainActor
public protocol StreamRepositoryProtocol: AnyObject {
    /// EPGStation のアドレス。未設定なら空
    var streamHost: String { get }
    /// 配信先が設定され、この Repository で配信できる。番組表との組み合わせは UseCase が判断する
    var canStream: Bool { get }

    func saveStreamHost(_ host: String)
    /// その局を EPGStation で見られるか (放送の ID を EPGStation のチャンネルの ID にできるか)
    func isPlayable(channelCode: String) -> Bool
    /// その局の配信を頼み、配信の番号を返す (このアプリの配信として覚える)
    func startLiveStream(channelCode: String) async throws(RegzaError) -> Int
    /// 再生できるようになるまで待ち、再生する HLS のプレイリストの URL を返す
    func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL
    /// まだ見ていることを知らせる (知らせないと EPGStation が配信を止める)
    func keep(streamID: Int) async
    /// 配信を止めてチューナーを空ける。止められたら、このアプリの配信として覚えるのをやめる
    func stop(streamID: Int) async
    /// 止められずに残った、このアプリの配信を止める
    func cleanUp() async
    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める。利用者が選んだときだけ使う
    func stopStalled() async
}
