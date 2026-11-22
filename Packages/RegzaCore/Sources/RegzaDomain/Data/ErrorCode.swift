import Foundation

/// エラーを見分ける code。画面に出す文言は、エラーの場合分けではなく、この code で引いて決める
/// (API が返す code で分岐するアプリでも、同じ作りで使えるように)。
/// `.` で区切った階層にし、仲間 (`http` に対する `http.404` など) をまとめて引けるようにする。
/// URI (API の問題の type) は `.` を含んでも階層ではないので、まったく同じときだけ当てはまる
public struct ErrorCode: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String { rawValue }

    /// family と同じか、その下の code (`http.404` は `http` の仲間)
    public func belongs(to family: ErrorCode) -> Bool {
        if rawValue == family.rawValue { return true }
        // URI は階層を持たないので、仲間を持たず、どの仲間にも入らない
        return !family.isURI && !isURI && rawValue.hasPrefix(family.rawValue + ".")
    }

    /// URI か (`https://…` や `urn:…` のように `:` を含む)
    public var isURI: Bool { rawValue.contains(":") }

    /// 下の階層を足した code
    public func appending(_ component: String) -> ErrorCode {
        ErrorCode(rawValue: rawValue + "." + component)
    }
}
