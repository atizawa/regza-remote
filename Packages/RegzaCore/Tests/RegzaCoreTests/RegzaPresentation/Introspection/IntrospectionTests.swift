import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// ViewModel を外から読み、操作する口 (Introspection)
@MainActor
@Suite struct IntrospectionTests {
    @Test func introspectionReachesScreensOnPath() async throws {
        let appViewModel = HTTPTestEnvironment(
            transport: FakeHTTPTransport { request in
                request.url.path.hasSuffix("channel_list")
                    ? FakeHTTPTransport.response(200, TestData.channelListJSON) : FakeHTTPTransport.response(500)
            }
        ).appViewModel
        let introspector = Introspector(root: appViewModel)
        try introspector.perform("app/channelList", "reload")
        _ = await introspector.waitUntilIdle()
        try introspector.perform("app", "selectTab", ["tab": .string("channels")])
        try introspector.perform("app", "openPrograms", ["channel": .string("JP-G00000002")])
        #expect(introspector.paths().contains("app/channels-0"))
        #expect(try introspector.node("app/channels-0").actions.map(\.name) == ["appear", "reload"])
    }
}
