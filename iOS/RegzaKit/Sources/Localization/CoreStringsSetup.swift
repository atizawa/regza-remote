import Foundation
import RegzaStrings

/// 共有の Swift (RegzaCore) が画面に出す文言に、このアプリの String Catalog の文言 (選ばれている言語) を入れる。
/// プロセスごとに、共有の Swift を使う前に 1 回呼ぶ (アプリは AppContainer、ウィジェットの拡張は WidgetBundle)。
/// iOS は言語を変えるとアプリを起動し直すので、言語の変更に合わせて入れ直さなくてよい
public enum CoreStringsSetup {
    public static func install() {
        let templates = CoreStringTable.keys.reduce(into: [String: String]()) { result, key in
            let text = NSLocalizedString(key, bundle: .module, comment: "")
            // 見つからなければキーがそのまま返るので、入れない (元言語の文言を使う)
            if text != key { result[key] = text }
        }
        CoreStringTable.install(templates)
    }
}
