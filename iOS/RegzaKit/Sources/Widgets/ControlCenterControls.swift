#if os(iOS)
import AppIntents
import RegzaPresentation
import SystemActions
import SwiftUI
import WidgetKit

// コントロールセンター・ロック画面・アクションボタンに置けるボタン。
// 押したら RegzaKeyIntent でキーを送る (LiveActivityIntent なのでアプリのプロセスで動き、テレビの登録情報を使える)

/// キーを 1 つ送るボタンの共通の見た目
@MainActor
private func keyControl(kind: String, key: RegzaKey, title: LocalizedStringResource, systemImage: String)
    -> some ControlWidgetConfiguration
{
    StaticControlConfiguration(kind: kind) {
        ControlWidgetButton(action: RegzaKeyIntent(key)) {
            Label(title, systemImage: systemImage)
        }
    }
    .displayName(title)
    .description("REGZA のリモコンの\(key.label)ボタンを押します。")
}

public struct PowerControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(kind: "RegzaRemote.control.power", key: .power, title: "テレビの電源", systemImage: "power")
    }
}

public struct MuteControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(kind: "RegzaRemote.control.mute", key: .mute, title: "テレビの消音", systemImage: "speaker.slash.fill")
    }
}

public struct VolumeUpControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(
            kind: "RegzaRemote.control.volumeUp", key: .volumeUp, title: "テレビの音量を上げる",
            systemImage: "speaker.plus.fill")
    }
}

public struct VolumeDownControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(
            kind: "RegzaRemote.control.volumeDown", key: .volumeDown, title: "テレビの音量を下げる",
            systemImage: "speaker.minus.fill")
    }
}

public struct ChannelUpControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(
            kind: "RegzaRemote.control.channelUp", key: .channelUp, title: "次のチャンネル",
            systemImage: "chevron.up.circle")
    }
}

public struct ChannelDownControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        keyControl(
            kind: "RegzaRemote.control.channelDown", key: .channelDown, title: "前のチャンネル",
            systemImage: "chevron.down.circle")
    }
}
#endif
