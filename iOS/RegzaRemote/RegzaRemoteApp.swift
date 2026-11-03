import AppIntents
import RegzaLiveActivity
import RegzaRemoteUI
import SwiftUI

@main
struct RegzaRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            RemoteView()
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}

/// Live Activity のボタン用 Intent (RegzaLiveActivity モジュール) をアプリに登録する
struct RegzaRemoteAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [RegzaLiveActivityIntents.self]
    }
}
