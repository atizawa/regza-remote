public import Foundation

/// 共有の Swift (Domain・Presentation など) が画面に出す文言を引く。
///
/// 文言は両 OS の画面と同じ String Catalog (Localizable.xcstrings) の `core_` で始まるキーに置き、
/// 生成した CoreStrings からキーで引く。共有の Swift は Android でも動き、アプリに入れた翻訳を自分では読めないので、
/// OS が起動時に、選ばれている言語の文言をまとめて入れる (iOS は Bundle、Android は文字列リソースから)。
/// 入っていないとき (CLI・テスト・Android Studio のプレビュー) と、入れた中にないキーは、元言語の文言を使う
public enum CoreStringTable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var installed: [String: String] = [:]

    /// OS の文言 (キー → 書式) を入れる。起動時と、言語が変わったときに呼ぶ。
    /// 書式の引数は iOS の形 (`%@`・`%lld`・`%1$@`) と Android の形 (`%1$s`・`%1$d`) のどちらでもよい
    public static func install(_ templates: [String: String]) {
        lock.withLock { installed = templates }
    }

    /// 日付や曜日を書くときの言語。文言と同じく選ばれている言語に合わせる (文言の言語と日付の書き方が食い違わないように)
    public static var locale: Locale { Locale(identifier: CoreStrings.locale) }

    /// 生成したキーの一覧 (OS がまとめて引くのに使う)
    public static var keys: [String] { CoreStrings.sourceTemplates.keys.sorted() }

    static func text(_ key: String, _ arguments: [Argument] = []) -> String {
        text(key, arguments, installed: lock.withLock { installed })
    }

    /// installed (OS が入れた文言) から引き、なければ元言語の文言にする
    static func text(_ key: String, _ arguments: [Argument], installed: [String: String]) -> String {
        let template = installed[key] ?? CoreStrings.sourceTemplates[key] ?? key
        return arguments.isEmpty && !template.contains("%") ? template : format(template, arguments)
    }

    /// 書式の引数の値
    enum Argument: Equatable {
        case string(String)
        case int(Int)
        case double(Double)
    }

    /// 書式に引数を入れる。番号付き (`%2$@`) は番号の、番号なしは並びの順の引数を入れる。`%%` は `%` にする。
    /// 読めない指定は、そのまま残す
    static func format(_ template: String, _ arguments: [Argument]) -> String {
        let characters = Array(template)
        var result = ""
        var next = 0
        var i = 0
        while i < characters.count {
            guard characters[i] == "%", let spec = Spec(characters, from: i + 1) else {
                result.append(characters[i])
                i += 1
                continue
            }
            i = spec.end
            guard spec.conversion != nil else {
                result += "%"
                continue
            }
            let index = spec.position.map { $0 - 1 } ?? next
            next = index + 1
            if arguments.indices.contains(index) {
                result += text(of: arguments[index], precision: spec.precision)
            }
        }
        return result
    }

    /// `%` のあとの指定 (`1$`・`.2`・`@`/`s`/`d`/`lld`/`f`/`%`)
    private struct Spec {
        var position: Int?
        var precision: Int?
        /// nil は `%%`
        var conversion: Character?
        /// 指定の次の位置
        var end: Int

        init?(_ characters: [Character], from start: Int) {
            var i = start
            func digits() -> Int? {
                var value: Int?
                while i < characters.count, let digit = characters[i].wholeNumberValue, characters[i].isASCII {
                    value = (value ?? 0) * 10 + digit
                    i += 1
                }
                return value
            }
            if let number = digits() {
                guard i < characters.count, characters[i] == "$" else { return nil }
                position = number
                i += 1
            }
            if i < characters.count, characters[i] == "." {
                i += 1
                guard let number = digits() else { return nil }
                precision = number
            }
            guard i < characters.count else { return nil }
            switch characters[i] {
            case "%" where position == nil && precision == nil: conversion = nil
            case "@", "s", "d", "f": conversion = characters[i]
            case "l" where characters[i...].starts(with: "lld"):
                conversion = "d"
                i += 2
            default: return nil
            }
            end = i + 1
        }
    }

    private static func text(of argument: Argument, precision: Int?) -> String {
        switch argument {
        case .string(let value): value
        case .int(let value): String(value)
        case .double(let value): String(format: "%.\(precision ?? 6)f", value)
        }
    }
}
