import Foundation
import RegzaDomain

/// 既存のデコード規則を保つ。生成 DTO からの直接変換は別途整理する。
enum RegzaDataMapper {
    static func model<Value: Decodable>(from payload: some Encodable) throws -> Value {
        do { return try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(payload)) } catch { throw RegzaError.unsupported }
    }

}
