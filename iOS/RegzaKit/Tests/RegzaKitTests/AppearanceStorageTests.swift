import Foundation
import RegzaInfrastructure
import Testing

@testable import AppServices

@Suite struct AppearanceStorageTests {
    @Test func selectionPersistsAcrossStorageInstances() throws {
        let suite = "AppearanceStorageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UserDefaultsStorage(defaults: defaults).value(forKey: .appearance) == nil)
        UserDefaultsStorage(defaults: defaults).setValue("dark", forKey: .appearance)
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(UserDefaultsStorage(defaults: reopened).value(forKey: .appearance) == "dark")
    }
}
