// ICU の共通データ (lib_FoundationICU に入っている icudt*_dat。CmnD 形式のパッケージ) を、このアプリが使う分に絞る。
// build-swift.sh が呼ぶ。引数: 元のデータ、絞ったデータの書き出し先
//
// 残すもの: 言語によらないデータ (タイムゾーン・暦・正規化・Unicode の性質・照合の基本など) と、日本語・英語の言語ごとのデータ、
// テレビの古い API の応答を読む文字コード (Shift_JIS・EUC-JP) の変換表。
// 削るもの: ほかの言語のデータ、ほかの古い文字コードの変換表、単語の区切りの辞書、文字の変換規則 (transliterator)、文字の名前。
// 日付は日本語を指定して書き (CoreStringTable.locale)、検索は正規化 (NFKC・NFC) だけを使うので、削っても表示は変わらない。
// 削る前と後で結果が同じことは、日付・タイムゾーン・文字コード・正規化・比較を実機で比べて確かめた
// (違ったのは、削った言語での日付の書式と Locale.availableIdentifiers だけ)
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// 言語ごとのデータを残す言語 (日本語と、端末の言語が分からないときに使われる英語)
let languages: Set<String> = ["ja", "en"]
/// 言語ごとのファイルを置くフォルダ ("" はパッケージの直下)
let localeTrees: Set<String> = ["", "coll", "rbnf", "lang", "region", "unit", "zone", "curr", "brkitr"]
/// 残す文字コードの変換表 (Shift_JIS・EUC-JP とその別名の表)
let converterPrefixes = ["ibm-943_", "ibm-942_", "ibm-33722_", "ibm-954_", "euc-jp-", "jisx-212"]

func fail(_ message: String) -> Never {
    fputs("[slim-icu-data] \(message)\n", stderr)
    exit(1)
}

func readFile(_ path: String) -> [UInt8] {
    guard let file = fopen(path, "rb") else { fail("\(path) を開けません") }
    defer { fclose(file) }
    fseek(file, 0, SEEK_END)
    let size = ftell(file)
    fseek(file, 0, SEEK_SET)
    var bytes = [UInt8](repeating: 0, count: size)
    guard fread(&bytes, 1, size, file) == size else { fail("\(path) を読めません") }
    return bytes
}

func writeFile(_ path: String, _ bytes: [UInt8]) {
    guard let file = fopen(path, "wb") else { fail("\(path) に書けません") }
    defer { fclose(file) }
    guard fwrite(bytes, 1, bytes.count, file) == bytes.count else { fail("\(path) に書けません") }
}

func uint16(_ bytes: [UInt8], _ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
func uint32(_ bytes: [UInt8], _ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) } }
func append32(_ bytes: inout [UInt8], _ value: Int) { bytes += (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) } }

/// 言語ごとのファイルの名前 (`ja`・`en_001`・`de_` など)
func isLocaleName(_ stem: String) -> Bool {
    let parts = stem.split(separator: "_", omittingEmptySubsequences: false)
    guard let language = parts.first, (2...3).contains(language.count), language.allSatisfy({ $0.isASCII && $0.isLowercase }) else {
        return false
    }
    return parts.dropFirst().allSatisfy { $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }
}

/// パッケージの中の名前 (`icudt76l/coll/ja.res`) の項目を残すか
func keeps(_ name: String) -> Bool {
    guard let slash = name.firstIndex(of: "/") else { return true }
    let path = name[name.index(after: slash)...]
    let directory = path.lastIndex(of: "/").map { String(path[..<$0]) } ?? ""
    let file = String(path.split(separator: "/").last ?? "")
    let stem = String(file.split(separator: ".").first ?? "")
    if file.hasSuffix(".cnv") { return converterPrefixes.contains { file.hasPrefix($0) } }
    if file.hasSuffix(".dict") || directory == "translit" || file == "unames.icu" { return false }
    if localeTrees.contains(directory), file.hasSuffix(".res"), isLocaleName(stem) {
        return languages.contains(String(stem.split(separator: "_", omittingEmptySubsequences: false)[0]))
    }
    return true
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fail("使い方: slim-icu-data.swift <元のデータ> <書き出し先>") }
let source = readFile(arguments[1])
// 先頭の見出し (大きさ・印 0xda27・"CmnD")
guard source.count > 32, source[2] == 0xDA, source[3] == 0x27, Array(source[12..<16]) == Array("CmnD".utf8) else {
    fail("ICU の共通データではありません")
}
let headerSize = uint16(source, 0)
let toc = headerSize
let count = uint32(source, toc)
var items: [(name: String, body: ArraySlice<UInt8>)] = []
for index in 0..<count {
    let nameStart = toc + uint32(source, toc + 4 + 8 * index)
    let dataStart = toc + uint32(source, toc + 8 + 8 * index)
    let dataEnd = index + 1 < count ? toc + uint32(source, toc + 8 + 8 * (index + 1)) : source.count
    guard let nameEnd = source[nameStart...].firstIndex(of: 0) else { fail("項目の名前が終わっていません") }
    items.append((String(decoding: source[nameStart..<nameEnd], as: UTF8.self), source[dataStart..<dataEnd]))
}
let kept = items.filter { keeps($0.name) }

// 同じ形で書き直す: 見出し、項目の数と (名前の位置・データの位置) の組、名前、16 バイトにそろえたデータ
var names: [UInt8] = []
for item in kept { names += Array(item.name.utf8) + [0] }
let namesStart = 4 + 8 * kept.count
let dataStart = (namesStart + names.count + 15) & ~15
var table: [UInt8] = []
append32(&table, kept.count)
var body: [UInt8] = []
var namePosition = namesStart
for item in kept {
    append32(&table, namePosition)
    append32(&table, dataStart + body.count)
    namePosition += item.name.utf8.count + 1
    body += item.body
    body += [UInt8](repeating: 0, count: (16 - body.count % 16) % 16)
}
var output = Array(source[..<headerSize]) + table + names
output += [UInt8](repeating: 0, count: dataStart - (output.count - headerSize))
output += body
writeFile(arguments[2], output)

let before = items.reduce(0) { $0 + $1.body.count }
let after = kept.reduce(0) { $0 + $1.body.count }
print("[slim-icu-data] 項目 \(items.count) → \(kept.count)、データ \(before / 1_000_000) MB → \(after / 1_000_000) MB")
