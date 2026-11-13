import Foundation
import RegzaDomain

/// テレビや録画サーバーへの HTTP の問い合わせ
public struct HTTPRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    /// 返事が途切れてから諦めるまでの秒数
    public var timeout: TimeInterval

    public init(method: String = "GET", url: URL, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    /// 名前は小文字にそろえてある
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        self.body = body
    }

    public func value(forHTTPHeaderField name: String) -> String? {
        headers[name.lowercased()]
    }
}

/// HTTP の送り方。iOS は URLSession、Android は Kotlin から注入した OkHttp。
/// 失敗は `RegzaError.network` で返す
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
