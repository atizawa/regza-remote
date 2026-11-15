import Foundation
import Observation

/// condition が true になるまで待つ。見回らず、condition が読む @Observable な値が変わったときだけ確かめ直す。
/// 待っている Task が取り消されたら、true になっていなくても返る
@MainActor
func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
    while !condition(), !Task.isCancelled {
        await nextChange(of: condition)
    }
}

/// condition が読む値のどれかが変わるまで (または待っている Task が取り消されるまで) 待つ
@MainActor
private func nextChange(of condition: @escaping @MainActor () -> Bool) async {
    let signal = OneShot()
    await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            signal.wait(with: continuation)
            // onChange は値が変わる直前に呼ばれる。値は MainActor の上で変わるので、
            // 続きが MainActor で動くころには変わり終わっている
            withObservationTracking {
                _ = condition()
            } onChange: {
                signal.fire()
            }
        }
    } onCancel: {
        signal.fire()
    }
}

/// 待っている continuation を 1 回だけ再開する (値の変化と取り消しが重なっても、2 回再開しない)
private final class OneShot: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isFired = false

    func wait(with continuation: CheckedContinuation<Void, Never>) {
        let resumeNow = lock.withLock {
            if isFired { return true }
            self.continuation = continuation
            return false
        }
        if resumeNow { continuation.resume() }
    }

    func fire() {
        let waiting = lock.withLock {
            isFired = true
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume()
    }
}
