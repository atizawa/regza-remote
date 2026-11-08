import Foundation
import Testing
@testable import RegzaCore
@testable import RegzaDomain
@testable import RegzaInfrastructure
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@Suite struct HTTP1EncodeTests {
    @Test func get() throws {
        let request = HTTPRequest(url: try #require(URL(string: "http://192.168.0.10/remote/status.htm?a=1")), timeout: 3)
        #expect(String(decoding: HTTP1.encode(request), as: UTF8.self) == """
            GET /remote/status.htm?a=1 HTTP/1.1\r
            Host: 192.168.0.10\r
            Connection: close\r
            \r

            """)
    }

    @Test func postWithPortAndBody() throws {
        let request = HTTPRequest(
            method: "POST", url: try #require(URL(string: "https://192.168.0.10:4430/v2/x")),
            headers: ["Content-Type": "application/x-www-form-urlencoded"], body: Data("a=1".utf8), timeout: 3
        )
        #expect(String(decoding: HTTP1.encode(request), as: UTF8.self) == """
            POST /v2/x HTTP/1.1\r
            Host: 192.168.0.10:4430\r
            Connection: close\r
            Content-Type: application/x-www-form-urlencoded\r
            Content-Length: 3\r
            \r
            a=1
            """)
    }

    @Test func emptyPath() throws {
        let request = HTTPRequest(url: try #require(URL(string: "http://example.com")), timeout: 3)
        #expect(String(decoding: HTTP1.encode(request), as: UTF8.self).hasPrefix("GET / HTTP/1.1\r\n"))
    }
}

@Suite struct HTTP1ParserTests {
    @Test func contentLengthArrivingByteByByte() throws {
        let raw = "HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Digest realm=\"r\"\r\nContent-Length: 5\r\n\r\nhello"
        var parser = HTTP1.ResponseParser()
        for byte in raw.utf8 {
            #expect(parser.response == nil)
            try parser.append([byte])
        }
        let response = try #require(parser.response)
        #expect(response.statusCode == 401)
        #expect(response.value(forHTTPHeaderField: "www-authenticate") == "Digest realm=\"r\"")
        #expect(String(decoding: response.body, as: UTF8.self) == "hello")
    }

    @Test func chunked() throws {
        var parser = HTTP1.ResponseParser()
        try parser.append(Array("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWiki\r\n".utf8))
        #expect(parser.response == nil)
        try parser.append(Array("5;ext=1\r\npedia\r\n0\r\n\r\n".utf8))
        #expect(String(decoding: try #require(parser.response).body, as: UTF8.self) == "Wikipedia")
    }

    @Test func bodyUntilClose() throws {
        var parser = HTTP1.ResponseParser()
        try parser.append(Array("HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\nab".utf8))
        try parser.append(Array("c".utf8))
        #expect(parser.response == nil)
        #expect(String(decoding: try parser.finish().body, as: UTF8.self) == "abc")
    }

    @Test func skipsContinue() throws {
        var parser = HTTP1.ResponseParser()
        try parser.append(Array("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 204 No Content\r\n\r\n".utf8))
        #expect(try #require(parser.response).statusCode == 204)
    }

    @Test func truncatedBodyFails() throws {
        var parser = HTTP1.ResponseParser()
        try parser.append(Array("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabc".utf8))
        #expect(throws: RegzaError.self) { try parser.finish() }
    }

    @Test func rejectsGarbage() {
        var parser = HTTP1.ResponseParser()
        #expect(throws: RegzaError.self) { try parser.append(Array("hello\r\n\r\n".utf8)) }
    }
}

/// 自分の Mac に立てた小さなサーバーとやり取りして、ソケットで送る実装を確かめる
@Suite(.serialized) struct SocketTransportTests {
    @Test func exchangesWithServer() async throws {
        let server = try TestServer { connection, request in
            #expect(request.hasPrefix("POST /path?q=1 HTTP/1.1\r\n"))
            #expect(request.hasSuffix("\r\n\r\nbody"))
            // 返事を分けて、間を空けて送る
            connection.send("HTTP/1.1 200 OK\r\nContent-Length: 11\r\nX-Test: yes\r\n\r\nhello ")
            Thread.sleep(forTimeInterval: 0.1)
            connection.send("world")
        }
        let response = try await SocketTransport().send(HTTPRequest(
            method: "POST", url: try #require(URL(string: "http://127.0.0.1:\(server.port)/path?q=1")),
            body: Data("body".utf8), timeout: 3
        ))
        #expect(response.statusCode == 200)
        #expect(response.value(forHTTPHeaderField: "X-Test") == "yes")
        #expect(String(decoding: response.body, as: UTF8.self) == "hello world")
    }

    @Test func timesOutWhenNoReply() async throws {
        let server = try TestServer { _, _ in Thread.sleep(forTimeInterval: 2) }
        let start = Date()
        await #expect(throws: RegzaError.network(SocketStream.timeoutMessage)) {
            try await SocketTransport().send(HTTPRequest(url: URL(string: "http://127.0.0.1:\(server.port)/")!, timeout: 0.5))
        }
        #expect(Date().timeIntervalSince(start) < 1.5)
    }

    @Test func stopsWhenCancelled() async throws {
        let server = try TestServer { _, _ in Thread.sleep(forTimeInterval: 2) }
        let url = try #require(URL(string: "http://127.0.0.1:\(server.port)/"))
        let start = Date()
        let task = Task { try await SocketTransport().send(HTTPRequest(url: url, timeout: 10)) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: RegzaError.network(SocketStream.cancelledMessage)) { try await task.value }
        #expect(Date().timeIntervalSince(start) < 1.5)
    }

    /// 証明書を確かめるかは SocketTransport が決める。テレビの HTTPS のポート以外は確かめる
    @Test func asksToVerifyCertificate() async throws {
        let server = try TestServer { connection, _ in connection.send("HTTP/1.1 204 No Content\r\n\r\n") }
        let tls = RecordingTLS()
        let response = try await SocketTransport(tls: tls).send(
            HTTPRequest(url: try #require(URL(string: "https://127.0.0.1:\(server.port)/")), timeout: 3)
        )
        #expect(response.statusCode == 204)
        #expect(tls.requests == ["127.0.0.1 verifies=true"])
    }

    @Test func refusesHTTPSWithoutTLS() async throws {
        await #expect(throws: RegzaError.self) {
            try await SocketTransport().send(HTTPRequest(url: URL(string: "https://127.0.0.1:4430/")!, timeout: 0.5))
        }
    }
}

/// 暗号化せずにそのまま通し、頼まれた内容を覚えておく
private final class RecordingTLS: TLSProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var requests: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func wrap(_ socket: SocketStream, host: String, verifiesCertificate: Bool) throws -> any ByteStream {
        lock.lock(); recorded.append("\(host) verifies=\(verifiesCertificate)"); lock.unlock()
        return socket
    }
}

/// 1 回だけ接続を受けて、届いた問い合わせを handler に渡すサーバー
private final class TestServer: @unchecked Sendable {
    let port: Int
    private let listener: Int32

    struct Connection {
        let descriptor: Int32
        func send(_ text: String) {
            _ = Array(text.utf8).withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
        }
    }

    init(handler: @escaping @Sendable (Connection, String) -> Void) throws {
        let listener = socket(AF_INET, testSocketStream, 0)
        self.listener = listener
        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                bind(listener, pointer, length) == 0 && listen(listener, 1) == 0
                    && getsockname(listener, pointer, &length) == 0
            }
        }
        guard bound else { throw RegzaError.network("サーバーを立てられません") }
        port = Int(UInt16(bigEndian: address.sin_port))

        Thread {
            let descriptor = accept(listener, nil, nil)
            guard descriptor >= 0 else { return }
            defer { close(descriptor) }
            // ヘッダーと、Content-Length の分の本文が揃うまで読む
            var received: [UInt8] = []
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
                guard count > 0 else { break }
                received += buffer[..<count]
                let text = String(decoding: received, as: UTF8.self)
                guard let headEnd = text.range(of: "\r\n\r\n") else { continue }
                let length = text.components(separatedBy: "\r\n")
                    .first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                if text[headEnd.upperBound...].utf8.count >= length { break }
            }
            handler(Connection(descriptor: descriptor), String(decoding: received, as: UTF8.self))
        }.start()
    }

    deinit { close(listener) }
}

#if canImport(Glibc)
private let testSocketStream = Int32(SOCK_STREAM.rawValue)
#else
private let testSocketStream = SOCK_STREAM
#endif
