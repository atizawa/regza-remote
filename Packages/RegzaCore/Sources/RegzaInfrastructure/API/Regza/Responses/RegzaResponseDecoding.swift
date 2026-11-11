import Foundation
import RegzaDomain

enum RegzaResponseDecoding {
    static func model<Value: Decodable>(from payload: some Encodable) throws -> Value {
        do { return try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(payload)) } catch { throw RegzaError.unsupported }
    }

    /// 旧 API は機種により文字コードが違う。
    static func text(_ data: Data) -> String {
        for encoding: String.Encoding in [.utf8, .shiftJIS, .japaneseEUC] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return String(decoding: data, as: UTF8.self)
    }
}
