import Observation
import Testing

@testable import RegzaAndroidBridge

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct StateWaitRegistryTests {
    @Observable fileprivate final class Counter {
        var value = 0
    }

    @Test func cancellingSwiftTaskOffActorFinishesBeforeEndArrives() async throws {
        let registry = StateWaitRegistry()
        let counter = Counter()
        let next = Task { await registry.next(after: 0, waitID: 1) { counter.value } }
        try await waitForCount(1, in: registry)

        await Task.detached { next.cancel() }.value

        #expect(await next.value == nil)
        // 遅れて届く Kotlin の終了通知で、完了記録も解放できる。
        registry.end(1)
        #expect(registry.count == 0)
    }

    @Test func cancellationBeforeStartDoesNotWaitForChange() async {
        let registry = StateWaitRegistry()
        let counter = Counter()
        let next = Task { await registry.next(after: 0, waitID: 1) { counter.value } }
        // MainActor を譲る前に取り消し、開始時点ですでにキャンセル済みにする。
        next.cancel()

        #expect(await next.value == nil)
        registry.end(1)
        #expect(registry.count == 0)
    }

    @Test func cancellationAndEndKeepOtherWaitsActive() async throws {
        let registry = StateWaitRegistry()
        let counter = Counter()
        let cancelled = Task { await registry.next(after: 0, waitID: 1) { counter.value } }
        let active = Task { await registry.next(after: 0, waitID: 2) { counter.value } }
        try await waitForCount(2, in: registry)

        cancelled.cancel()
        registry.end(1)

        #expect(await cancelled.value == nil)
        #expect(registry.count == 1)
        counter.value = 1
        #expect(await active.value == 1)
        registry.end(2)
        #expect(registry.count == 0)
    }

    @Test func stateChangeCancellationAndEndCanRace() async throws {
        let registry = StateWaitRegistry()
        let counter = Counter()
        for id: Int64 in 1...20 {
            let before = counter.value
            let next = Task { await registry.next(after: before, waitID: id) { counter.value } }
            try await waitForCount(1, in: registry)

            counter.value += 1
            if id.isMultiple(of: 2) { await Task.yield() }
            next.cancel()
            registry.end(id)

            let result = await next.value
            #expect(result == nil || result == counter.value)
            #expect(registry.count == 0)
        }
    }

    private func waitForCount(_ expected: Int, in registry: StateWaitRegistry) async throws {
        for _ in 0..<200 {
            if registry.count == expected { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(registry.count == expected)
    }

}
