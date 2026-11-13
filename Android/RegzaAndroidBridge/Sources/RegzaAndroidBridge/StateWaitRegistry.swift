import Observation

/// Kotlin の Flow ごとに state の変更を待つ。
/// Java の Future のキャンセルは Swift の Task に伝わらないため、終了は end(_:) で明示的に受け取る。
/// Swift Task 自体のキャンセルでも待機を終え、end(_:) で待機番号を解放する。
/// 開始前の終了と、結果を返してからの終了も扱い、待機番号は 1 回の next にだけ使う。
@MainActor
final class StateWaitRegistry {
    private var waits: [Int64: StateWait] = [:]

    var count: Int { waits.count }

    func next<State: Equatable>(after last: State?, waitID: Int64, read: @MainActor () -> State?) async -> State? {
        let changes = Changes()
        switch waits[waitID] {
        case .cancelled?:
            // Flow の終了が、swift-java がこの Task を MainActor で始めるより先だった。
            waits[waitID] = nil
            return nil
        case nil:
            waits[waitID] = .waiting(changes)
        case .waiting?, .completed?:
            preconditionFailure("同じ state の待機番号が重なっています: \(waitID)")
        }
        return await withTaskCancellationHandler {
            while true {
                if case .cancelled? = waits[waitID] {
                    waits[waitID] = nil
                    return nil
                }
                if Task.isCancelled {
                    // 後から来る end を開始前の終了と取り違えないよう、正常終了と同じく記録を残す。
                    waits[waitID] = .completed
                    return nil
                }
                let current = changes.track(read)
                if current != last {
                    // Kotlin が Future の結果を受け取って end を呼ぶまで、完了したことを覚えておく。
                    // 結果を返す直前に Flow が終了しても、後から来た end を開始前の終了と取り違えないため。
                    waits[waitID] = .completed
                    return current
                }
                await changes.wait()
            }
        } onCancel: {
            // ハンドラーは別スレッドでも呼ばれる。変更通知・end と同じ MainActor 上で待機を起こす。
            Task { @MainActor in changes.changed() }
        }
    }

    func end(_ id: Int64) {
        switch waits[id] {
        case .waiting(let changes):
            waits[id] = .cancelled
            changes.changed()
        case .completed?:
            waits[id] = nil
        case .cancelled?:
            break
        case nil:
            // swift-java が next の Task を始める前に、Flow の終了が届いた。
            waits[id] = .cancelled
        }
    }

    private enum StateWait {
        case waiting(Changes)
        case completed
        case cancelled
    }

    /// 読んだ値の変更を見張る。待ち始める前の通知も覚えておき、取りこぼさない。
    @MainActor
    private final class Changes {
        private var hasChanged = false
        private var waiter: CheckedContinuation<Void, Never>?

        func track<Value>(_ make: () -> Value) -> Value {
            hasChanged = false
            return withObservationTracking(make) { [weak self] in
                // 変わる直前に呼ばれるので、変わり終わってから知らせる。
                Task { @MainActor in self?.changed() }
            }
        }

        func wait() async {
            if hasChanged { return }
            await withCheckedContinuation { waiter = $0 }
        }

        func changed() {
            hasChanged = true
            waiter?.resume()
            waiter = nil
        }
    }
}
