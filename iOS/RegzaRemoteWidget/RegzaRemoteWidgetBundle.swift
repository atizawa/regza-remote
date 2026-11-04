import AppIntents
import RegzaLiveActivity
import SwiftUI
import WidgetKit

@main
struct RegzaRemoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        RegzaLiveActivityWidget()
        // ホーム画面のリモコンのウィジェット
        RemoteWidget()
        // コントロールセンター・ロック画面・アクションボタンに置けるボタン
        PowerControl()
        MuteControl()
        VolumeUpControl()
        VolumeDownControl()
        ChannelUpControl()
        ChannelDownControl()
    }
}

struct RegzaRemoteWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [RegzaLiveActivityIntents.self]
    }
}
