import Foundation
import RegzaStrings

/// 共有の Swift が画面に出す文言の、Android での引き方。Kotlin が実装し、選ばれている言語の文字列リソースを返す
/// (iOS の Bundle にあたる)。swift-java で Java のインターフェースになる
public protocol RegzaAndroidStrings {
    /// キー (`core_` で始まる、String Catalog と同じ名前) の文言。書式の引数は `%1$s` などのまま返す。なければ nil
    func text(forKey key: String) -> String?
}

/// Android の文言を、共有の Swift の文言として入れる。アプリの起動時と、言語が変わったときに、メインスレッドから呼ぶ。
/// 文言は引くたびに Java を呼ばず、ここでまとめて受け取っておく (共有の Swift は、どのスレッドからも文言を引くので)
public func regzaUseStrings(_ strings: any RegzaAndroidStrings) {
    let templates = CoreStringTable.keys.reduce(into: [String: String]()) { result, key in
        result[key] = strings.text(forKey: key)
    }
    CoreStringTable.install(templates)
}
