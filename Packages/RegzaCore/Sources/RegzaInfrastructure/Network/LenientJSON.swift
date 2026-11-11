import Foundation

/// 決まりどおりでない JSON を、読める形に直す。
///
/// JSON の文字列の中の制御文字 (0x00〜0x1F) は `\u001f` のように書く決まりだが、録画サーバー (Mirakurun) は
/// 放送の番組の説明に入っていた制御文字を、そのまま返すことがある。JSONDecoder は 1 文字でもあると全体を読めないので、
/// 番組表がまるごと空になる。文字列の中にそのまま入った制御文字だけを、決まりどおりの書き方に置き換える
/// (文字列の外の改行や空白、すでに正しく書かれた `\"` などは変えない。中身は失わない)
enum LenientJSON {
    static func escapingControlCharactersInStrings(_ data: Data) -> Data {
        // 制御文字がなければ (改行も含めて 1 つもなければ)、そのまま返す
        guard data.contains(where: { $0 < 0x20 }) else { return data }
        var result = Data()
        result.reserveCapacity(data.count)
        var isInString = false
        var isEscaped = false
        for byte in data {
            guard isInString else {
                if byte == UInt8(ascii: "\"") { isInString = true }
                result.append(byte)
                continue
            }
            if isEscaped {
                isEscaped = false
                result.append(byte)
            } else if byte == UInt8(ascii: "\\") {
                isEscaped = true
                result.append(byte)
            } else if byte == UInt8(ascii: "\"") {
                isInString = false
                result.append(byte)
            } else if byte < 0x20 {
                result.append(contentsOf: Array(String(format: "\\u%04x", byte).utf8))
            } else {
                result.append(byte)
            }
        }
        return result
    }
}
