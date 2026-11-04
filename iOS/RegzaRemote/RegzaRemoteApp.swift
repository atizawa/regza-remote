import AppIntents
import RegzaLiveActivity
import RegzaRemoteUI
import SwiftUI

@main
struct RegzaRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            RemoteView()
                // Siri の「○○にして」で言えるチャンネル名を、テレビのチャンネル一覧で更新する
                .task { RegzaRemoteShortcuts.updateAppShortcutParameters() }
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

/// Siri とショートカット App に出す言い方。Siri では「REGZAリモコンで ○○」のようにアプリ名を付けて呼ぶ
struct RegzaRemoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TuneChannelIntent(),
            phrases: [
                "\(.applicationName)で\(\.$channel)にして",
                "\(.applicationName)で\(\.$channel)に切り替えて",
                "\(.applicationName)でテレビを\(\.$channel)にして",
            ],
            shortTitle: "チャンネルを切り替える",
            systemImageName: "tv"
        )
        AppShortcut(
            intent: RemoteCommandIntent(),
            phrases: [
                "\(.applicationName)で\(\.$command)",
                "\(.applicationName)でテレビの\(\.$command)",
            ],
            shortTitle: "テレビを操作する",
            systemImageName: "appletvremote.gen4"
        )
        AppShortcut(
            intent: RemoteCommandIntent(.power),
            phrases: [
                "\(.applicationName)でテレビをつけて",
                "\(.applicationName)でテレビを消して",
            ],
            shortTitle: "電源",
            systemImageName: "power"
        )
    }
}
