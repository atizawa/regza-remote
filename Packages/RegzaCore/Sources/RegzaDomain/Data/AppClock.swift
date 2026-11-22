import Foundation

/// 今の時刻を返すもの。時刻で決まる判断 (放送中か・予約できるか・間隔が空いたか) は、`Date()` を直接読まずにこれから読む。
/// 組み立て (Factory) が 1 つだけ作って UseCase・Repository・通信に渡すので、テストでは時刻を決めて渡せる
public struct AppClock: Sendable {
    private let current: @Sendable () -> Date

    /// - Parameter now: 読むたびに今の時刻を返す
    public init(_ now: @escaping @Sendable () -> Date) {
        current = now
    }

    /// 今の時刻
    public var now: Date { current() }

    /// 端末の時計
    public static let system = AppClock { Date() }

    /// いつ読んでも同じ時刻を返す (テスト用)
    public static func fixed(_ date: Date) -> AppClock { AppClock { date } }
}
