import Foundation
import Testing
@testable import RegzaPresentation
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
