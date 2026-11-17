import Foundation
import Observation
import Testing

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import ReservationsPresentation
@testable import SettingsPresentation

/// 見回らずに、値が変わったときだけ確かめ直して待つこと
@MainActor
@Suite struct ObservedConditionTests {
    @MainActor
    @Observable
    final class Busy: Introspectable {
        var running = 0
        var introspectionName: String { "busy" }
        var introspectionValue: Any { running }
        var introspectionActions: [ActionDescription] { [] }
        var isBusy: Bool { running > 0 }
        func perform(_ action: String, _ arguments: [String: JSONValue]) throws {}
    }

    @Test func returnsAfterTheValueChangesWithoutPolling() async {
        let busy = Busy()
        busy.running = 2
        var checks = 0
        let waiting = Task {
            await waitUntil {
                checks += 1
                return !busy.isBusy
            }
        }
        try? await Task.sleep(for: .milliseconds(300))
        // 値が変わるまでは確かめ直さない (最初の 1 回と、見張りを付けるときの 1 回だけ)
        #expect(checks == 2)
        busy.running = 1
        try? await Task.sleep(for: .milliseconds(50))
        // まだ途中なので、待ち続ける
        #expect(checks == 4)
        busy.running = 0
        await waiting.value
        #expect(!busy.isBusy)
    }

    @Test func returnsImmediatelyWhenAlreadyIdle() async {
        let busy = Busy()
        await busy.waitUntilIdle()
        #expect(!busy.isBusy)
    }

    @Test func returnsWhenCancelled() async {
        let busy = Busy()
        busy.running = 1
        let waiting = Task { await busy.waitUntilIdle() }
        try? await Task.sleep(for: .milliseconds(50))
        waiting.cancel()
        await waiting.value
        #expect(busy.isBusy)
    }

    @Test func introspectorGivesUpAfterTimeout() async {
        let busy = Busy()
        busy.running = 1
        let start = Date()
        let idle = await Introspector(root: busy).waitUntilIdle(timeout: 0.3)
        #expect(!idle)
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func introspectorReturnsWhenWorkFinishes() async {
        let busy = Busy()
        busy.running = 1
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            busy.running = 0
        }
        #expect(await Introspector(root: busy).waitUntilIdle(timeout: 5))
    }
}
