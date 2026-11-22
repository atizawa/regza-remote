import Foundation
import Testing

@testable import PresentationCore
@testable import RegzaDomain
@testable import RegzaInfrastructure

/// エラーを文言にするところ (ErrorMessage) と、文言を引く code (ErrorCode)、API の問題の詳細 (RFC 9457) の読み方
@Suite struct ErrorMessageTests {
    @Test func codesFormFamilies() {
        #expect(RegzaError.httpStatus(404).code == "http.404")
        #expect(RegzaError.httpStatus(404).code.belongs(to: .http))
        #expect(RegzaError.commandRejected("2").code == "command_rejected.2")
        #expect(RegzaError.commandRejected("2").code.belongs(to: .commandRejected))
        // 名前の始まりが同じでも、階層が違えば仲間ではない
        #expect(!ErrorCode("http_x").belongs(to: .http))
        // URI は . を含んでも階層ではない
        #expect(!ErrorCode("https://example.com/probs/limit.v2").belongs(to: "https://example.com/probs/limit"))
    }

    @Test func sceneRewritesByCode() {
        #expect(
            ErrorMessage.text(RegzaError.unsupported, in: .channelList) == ErrorMessage.text(RegzaError.httpStatus(404), in: .channelList))
        #expect(ErrorMessage.text(RegzaError.unsupported, in: .channelList) != ErrorMessage.text(RegzaError.unsupported))
        #expect(ErrorMessage.text(RegzaError.commandRejected("2"), in: .tune(channelName: "見本の局")).contains("見本の局"))
        #expect(ErrorMessage.text(RegzaError.commandRejected("2"), in: .reserve).contains("2"))
        // 言い換えのない場面では、エラーの元の文言
        #expect(ErrorMessage.text(RegzaError.httpStatus(500), in: .channelList) == RegzaError.httpStatus(500).localizedDescription)
    }

    @Test func problemIsFoundByItsType() {
        let problem = RegzaError.problem(APIProblem(type: "https://example.com/problems/out-of-stock", status: 409))
        #expect(problem.code == "https://example.com/problems/out-of-stock")
        // type を書かない問題は、HTTP のステータスのとおりの code にする
        let blank = RegzaError.problem(APIProblem(status: 404))
        #expect(blank.code == "http.404")
        #expect(ErrorMessage.text(blank, in: .channelList) == ErrorMessage.text(RegzaError.httpStatus(404), in: .channelList))
    }

    /// 表にない問題は、サーバーの title・detail を出さず、アプリの言い方にする
    @Test func unknownProblemUsesAppWording() {
        let error = RegzaError.problem(
            APIProblem(type: "https://example.com/problems/unknown", title: "Server title", status: 503, detail: "Server detail"))
        let text = ErrorMessage.text(error)
        #expect(!text.contains("Server title"))
        #expect(!text.contains("Server detail"))
        #expect(text == RegzaError.httpStatus(503).localizedDescription)
        #expect(ErrorMessage.text(RegzaError.problem(APIProblem(type: "https://example.com/problems/unknown"))) != "")
    }

    @Test func problemJSONIsReadAtTheHTTPBoundary() async {
        let body = #"{"type":"https://example.com/problems/busy","title":"Busy","detail":"Try later"}"#
        let transport = FakeHTTPTransport { _ in
            HTTPResponse(statusCode: 503, headers: ["Content-Type": "application/problem+json; charset=utf-8"], body: Data(body.utf8))
        }
        do {
            _ = try await EPGStationAPIClient(host: "192.0.2.30", transport: transport).request(EPGStationVersionRequest())
            Issue.record("エラーになるはずの返事が通りました")
        } catch {
            // 本文に status がなければ、返事のステータスを入れる
            #expect(
                RegzaError(error)
                    == .problem(APIProblem(type: "https://example.com/problems/busy", title: "Busy", status: 503, detail: "Try later")))
        }
    }

    /// 種類 (type) のない問題は、HTTP のステータスのエラーのままにする (404 で分かれる処理をそのまま使う)
    @Test func blankProblemStaysHTTPStatus() async {
        let transport = FakeHTTPTransport { _ in
            HTTPResponse(statusCode: 404, headers: ["Content-Type": "application/problem+json"], body: Data(#"{"title":"Not Found"}"#.utf8))
        }
        do {
            _ = try await EPGStationAPIClient(host: "192.0.2.30", transport: transport).request(EPGStationVersionRequest())
            Issue.record("エラーになるはずの返事が通りました")
        } catch {
            #expect(RegzaError(error) == .httpStatus(404))
        }
    }

    @Test func plainErrorResponseStaysHTTPStatus() async {
        let transport = FakeHTTPTransport { _ in
            HTTPResponse(statusCode: 503, headers: ["Content-Type": "application/json"], body: Data("{}".utf8))
        }
        do {
            _ = try await EPGStationAPIClient(host: "192.0.2.30", transport: transport).request(EPGStationVersionRequest())
            Issue.record("エラーになるはずの返事が通りました")
        } catch {
            #expect(RegzaError(error) == .httpStatus(503))
        }
    }
}

/// 画面に出すエラーの文言は ErrorMessage だけが作る。`localizedDescription` を読んでよいのは ErrorMessage だけ
/// (OS のエラーは、通信が種類 (ConnectionFailure) に分けて RegzaError にし、OS の文言は使わない)
@Suite struct ErrorMessageUsageGuardTests {
    @Test func onlyErrorMessageReadsLocalizedDescription() throws {
        let shared = try SourceLine.read(under: "Packages/RegzaCore/Sources") {
            !$0.hasPrefix("RegzaFakeServers/") && $0 != "Presentation/PresentationCore/Errors/ErrorMessage.swift"
        }
        let bridge = try SourceLine.read(under: "Android/RegzaAndroidBridge/Sources")
        #expect(!shared.isEmpty && !bridge.isEmpty)
        for line in shared + bridge where line.code.contains(".localizedDescription") {
            Issue.record("\(line.location) がエラーの文言を直接読んでいます。ErrorMessage.text で文言にしてください")
        }
    }
}

/// 通信が返事を受け取れなかったときは、OS によらず同じ文言にする
@Suite struct ConnectionFailureTests {
    @Test func everyKindHasAppWording() {
        let texts = ConnectionFailure.allCases.map { ErrorMessage.text(RegzaError.connection($0)) }
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == texts.count)
        #expect(RegzaError.connection(.timedOut).code == "connection.timed_out")
    }

    #if !os(Android)
    @Test func urlSessionErrorsAreSortedIntoKinds() {
        #expect(ConnectionFailure(URLError(.timedOut)) == .timedOut)
        #expect(ConnectionFailure(URLError(.cannotConnectToHost)) == .cannotConnect)
        #expect(ConnectionFailure(URLError(.serverCertificateUntrusted)) == .certificate)
        #expect(ConnectionFailure(URLError(.notConnectedToInternet)) == .offline)
        #expect(ConnectionFailure(URLError(.cancelled)) == .cancelled)
        #expect(ConnectionFailure(CocoaError(.fileNoSuchFile)) == .other)
    }
    #endif

    /// RegzaError 以外のエラーも、OS の文言を使わずにアプリの言い方にする
    @Test func otherErrorsUseAppWording() {
        #expect(RegzaError(CocoaError(.fileNoSuchFile)) == .connection(.other))
    }
}
