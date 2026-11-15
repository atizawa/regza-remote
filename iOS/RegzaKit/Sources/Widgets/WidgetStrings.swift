import Localization

/// ウィジェットの拡張のプロセスで、共有の Swift の文言をこのアプリの言語にする。WidgetBundle の init から呼ぶ
/// (拡張はアプリと別のプロセスで動くので、アプリで入れた文言は届かない)
public enum WidgetStrings {
    public static func install() {
        CoreStringsSetup.install()
    }
}
