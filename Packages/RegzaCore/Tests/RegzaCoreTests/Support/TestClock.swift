import Foundation

@testable import RegzaDomain

/// テストで時刻を決めて進める時計。`clock` を UseCase・Repository に渡し、`now` を書き換えて時刻の境目を確かめる
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ now: Date) {
        current = now
    }

    var now: Date {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// 渡す時計 (読むたびに、いまの now を返す)
    var clock: AppClock { AppClock { [self] in now } }
}
