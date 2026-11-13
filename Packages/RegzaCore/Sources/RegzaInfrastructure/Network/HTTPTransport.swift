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

/// HTTP の送り方。iOS は URLSession、Android は自前のソケット (Android の URLSession は返事を待つ間 CPU を使い続けるため)。
/// 失敗は `RegzaError.network` で返す
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

// MARK: - HTTP/1.1 の組み立てと読み取り (ソケットで送る実装が使う)

public enum HTTP1 {
    /// 送る内容 (要求の行・ヘッダー・本文)。1 回ごとに接続を閉じる
    public static func encode(_ request: HTTPRequest) -> [UInt8] {
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        var target = components?.percentEncodedPath ?? "/"
        if target.isEmpty { target = "/" }
        if let query = components?.percentEncodedQuery { target += "?" + query }

        var head = "\(request.method) \(target) HTTP/1.1\r\n"
        head += "Host: \(authority(of: request.url))\r\n"
        head += "Connection: close\r\n"
        for (name, value) in request.headers.sorted(by: { $0.key < $1.key }) where name.lowercased() != "content-length" {
            head += "\(name): \(value)\r\n"
        }
        if let body = request.body {
            head += "Content-Length: \(body.count)\r\n"
        } else if ["POST", "PUT"].contains(request.method) {
            head += "Content-Length: 0\r\n"
        }
        head += "\r\n"
        return Array(head.utf8) + (request.body.map(Array.init) ?? [])
    }

    /// `Host` ヘッダーの値。既定のポートなら付けない
    static func authority(of url: URL) -> String {
        let host = url.host ?? ""
        let isDefault = url.port == nil || (url.scheme == "https" ? url.port == 443 : url.port == 80)
        return isDefault ? host : "\(host):\(url.port!)"
    }

    /// 受け取った分を少しずつ渡して、返事を組み立てる
    public struct ResponseParser {
        private var buffer: [UInt8] = []
        private var head: (statusCode: Int, headers: [String: String])?
        private var framing: Framing?
        private var body: [UInt8] = []
        public private(set) var response: HTTPResponse?

        /// 本文の区切り方
        private enum Framing {
            case length(Int)
            case chunked
            /// 接続が閉じるまで
            case close
        }

        public init() {}

        /// 返事が揃ったら `response` が入る
        public mutating func append(_ bytes: some Collection<UInt8>) throws {
            buffer.append(contentsOf: bytes)
            try advance()
        }

        /// 接続が閉じたときに呼ぶ。閉じるまでが本文の返事はここで揃う
        public mutating func finish() throws -> HTTPResponse {
            if let response { return response }
            guard let head, case .close = framing else { throw RegzaError.network("返事が途中で切れました") }
            body.append(contentsOf: buffer)
            buffer.removeAll()
            return HTTPResponse(statusCode: head.statusCode, headers: head.headers, body: Data(body))
        }

        private mutating func advance() throws {
            while response == nil {
                if head == nil {
                    guard let end = Self.find([13, 10, 13, 10], in: buffer) else { return }
                    let parsed = try Self.parseHead(buffer[..<end])
                    buffer.removeSubrange(..<(end + 4))
                    // 100 Continue などの途中経過は読み飛ばす
                    if (100..<200).contains(parsed.statusCode) { continue }
                    head = parsed
                    if parsed.statusCode == 204 || parsed.statusCode == 304 {
                        framing = .length(0)
                    } else if parsed.headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
                        framing = .chunked
                    } else if let length = parsed.headers["content-length"] {
                        framing = .length(try Self.parseLength(length, radix: 10))
                    } else {
                        framing = .close
                    }
                }
                guard let head, let framing else { return }
                switch framing {
                case .length(let length):
                    guard buffer.count >= length else { return }
                    body.append(contentsOf: buffer[..<length])
                    buffer.removeSubrange(..<length)
                    complete(head)
                case .chunked:
                    guard try readChunks() else { return }
                    complete(head)
                case .close:
                    return
                }
            }
        }

        /// chunked の本文を読めるだけ読む。最後まで読めたら true
        private mutating func readChunks() throws -> Bool {
            while true {
                guard let lineEnd = Self.find([13, 10], in: buffer) else { return false }
                let line = String(decoding: buffer[..<lineEnd], as: UTF8.self)
                let sizeText = line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
                let size = try Self.parseLength(sizeText, radix: 16)
                if size == 0 {
                    // 最後の塊のあとのトレーラーは使わない。空行まで揃うのを待つ
                    let rest = buffer[(lineEnd + 2)...]
                    if rest.starts(with: [13, 10]) {
                        buffer.removeAll()
                        return true
                    }
                    guard Self.find([13, 10, 13, 10], in: Array(rest)) != nil else { return false }
                    buffer.removeAll()
                    return true
                }
                let start = lineEnd + 2
                let (end, endOverflow) = start.addingReportingOverflow(size)
                let (next, nextOverflow) = end.addingReportingOverflow(2)
                guard !endOverflow, !nextOverflow else { throw RegzaError.network("不正なレスポンスです") }
                guard buffer.count >= next else { return false }
                guard buffer[end] == 13, buffer[end + 1] == 10 else { throw RegzaError.network("不正なレスポンスです") }
                body.append(contentsOf: buffer[start..<end])
                buffer.removeSubrange(..<next)
            }
        }

        private mutating func complete(_ head: (statusCode: Int, headers: [String: String])) {
            response = HTTPResponse(statusCode: head.statusCode, headers: head.headers, body: Data(body))
        }

        private static func parseLength(_ text: String, radix: Int) throws -> Int {
            let digits = text.trimmingCharacters(in: .whitespaces)
            guard !digits.isEmpty,
                digits.utf8.allSatisfy({ byte in
                    (48...57).contains(byte)
                        || (radix == 16 && ((65...70).contains(byte) || (97...102).contains(byte)))
                }),
                let length = Int(digits, radix: radix)
            else { throw RegzaError.network("不正なレスポンスです") }
            return length
        }

        private static func parseHead(_ bytes: ArraySlice<UInt8>) throws -> (statusCode: Int, headers: [String: String]) {
            let lines = String(decoding: bytes, as: UTF8.self).components(separatedBy: "\r\n")
            // HTTP/1.1 200 OK
            let status = lines.first?.split(separator: " ", maxSplits: 2) ?? []
            guard status.count >= 2, status[0].hasPrefix("HTTP/"), let code = Int(status[1]) else {
                throw RegzaError.network("不正なレスポンスです")
            }
            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
            return (code, headers)
        }

        private static func find(_ pattern: [UInt8], in bytes: [UInt8]) -> Int? {
            guard bytes.count >= pattern.count else { return nil }
            for index in 0...(bytes.count - pattern.count) where bytes[index] == pattern[0] {
                if bytes[index..<(index + pattern.count)].elementsEqual(pattern) { return index }
            }
            return nil
        }
    }
}
