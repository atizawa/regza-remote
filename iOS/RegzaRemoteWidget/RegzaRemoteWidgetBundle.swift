import AppIntents
import SwiftUI
import SystemActions
import WidgetKit
import Widgets

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

/// ボタンの Intent だけを登録する (Siri の Intent はアプリのプロセスの ViewModel を使うので、アプリにだけ登録する)
struct RegzaRemoteWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [SystemActionsPackage.self]
    }
}
