import Foundation

enum RegzaResponseDecoding {
    /// 旧 API は機種により文字コードが違う。
    static func text(_ data: Data) -> String {
        for encoding: String.Encoding in [.utf8, .shiftJIS, .japaneseEUC] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return String(decoding: data, as: UTF8.self)
    }
}
