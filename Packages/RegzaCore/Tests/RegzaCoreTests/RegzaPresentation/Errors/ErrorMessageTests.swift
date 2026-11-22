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

    /// API が決めた code (拡張メンバー) があれば、api の仲間の code にし、type・HTTP のステータスの順に続ける
    @Test func problemIsFoundByItsAPICode() {
        let problem = RegzaError.problem(APIProblem(type: "https://example.com/problems/stock", status: 409, code: "out_of_stock"))
        #expect(problem.codes == ["api.out_of_stock", "https://example.com/problems/stock", "http.409"])
        #expect(problem.code.belongs(to: .api))
        // 表にない code は、HTTP のステータスのとおりの文言にする
        #expect(ErrorMessage.text(problem) == RegzaError.httpStatus(409).localizedDescription)
        // API の code の表がなくても、場面ごとの 404 の言い換えは使える
        let notFound = RegzaError.problem(APIProblem(status: 404, code: "not_found"))
        #expect(ErrorMessage.text(notFound, in: .channelList) == ErrorMessage.text(RegzaError.httpStatus(404), in: .channelList))
        // 見分けられた 404 は、もう無いものではあるが、機種が対応していないものではない
        #expect(notFound.isNotFound)
        #expect(!notFound.isUnsupported)
        #expect(RegzaError.httpStatus(404).isUnsupported && RegzaError.httpStatus(404).isNotFound)
        #expect(RegzaError.unsupported.isUnsupported)
        // API の code の . と : は、階層や URI の印にせず、ほかの code とも重ならない
        let similar = ["stock", "stock.low", "stock_low", "stock:low", "stock%2Elow"].map(ErrorCode.apiCode)
        #expect(Set(similar).count == similar.count)
        #expect(!ErrorCode.apiCode("stock.low").belongs(to: ErrorCode.apiCode("stock")))
        #expect(!ErrorCode.apiCode("E:1001").isURI)
    }

    /// URI でない種類 (相対参照) は、type の仲間にし、アプリが決めた仲間に紛れさせない
    @Test func relativeProblemTypeStaysOutOfAppFamilies() {
        let relative = RegzaError.problem(APIProblem(type: "http.404", status: 409))
        #expect(relative.codes == [ErrorCode.problemType("http.404"), "http.409"])
        #expect(!relative.code.belongs(to: .http))
        #expect(ErrorCode.problemType("https://example.com/problems/stock") == "https://example.com/problems/stock")
        // : を含んで URI として扱うものも、アプリが決めた仲間には入らない
        #expect(!ErrorCode.problemType("http.404:legacy").belongs(to: .http))
    }

    /// 拡張メンバーの code は、数も文字にし、空のときは code がないものにする
    @Test func apiCodeIsReadFromExtensionMember() throws {
        func decode(_ json: String) throws -> APIProblem { try JSONDecoder().decode(APIProblem.self, from: Data(json.utf8)) }
        #expect(try decode(#"{"code":"out_of_stock"}"#).code == "out_of_stock")
        #expect(try decode(#"{"code":1001}"#).code == "1001")
        #expect(try decode(#"{"code":" \n"}"#).code == nil)
        #expect(try decode(#"{"code":"out_of_stock\n"}"#).code == "out_of_stock")
        #expect(try decode(#"{"code":true}"#).code == nil)
        // 書き出して読み直しても、code は残る
        let problem = APIProblem(type: "https://example.com/problems/stock", status: 409, code: "out_of_stock")
        #expect(try decode(String(decoding: JSONEncoder().encode(problem), as: UTF8.self)) == problem)
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

    /// アプリが決めた code の失敗は、表で文言を引く (表にない code は、決まった言い方にする)
    @Test func appCodesUseTheTable() {
        let fallback = RegzaError.failed("not_in_table").localizedDescription
        let texts = [ErrorCode.streamUnavailable, .lockScreenStartFailed].map { ErrorMessage.text(RegzaError.failed($0)) }
        #expect(texts.allSatisfy { $0 != fallback })
        #expect(Set(texts).count == texts.count)
        #expect(RegzaError.failed(.streamUnavailable).code == .streamUnavailable)
    }

    /// 形が違って読めない返事は、機種が対応していないとは言わず、返事が正しくないものにする
    @Test func unreadableResponseIsInvalidResponse() async {
        let transport = FakeHTTPTransport { _ in
            HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/json"], body: Data(#"{"version":1}"#.utf8))
        }
        do {
            _ = try await EPGStationAPIClient(host: "192.0.2.30", transport: transport).request(EPGStationVersionRequest())
            Issue.record("読めないはずの返事が通りました")
        } catch {
            #expect(RegzaError(error) == .connection(.invalidResponse))
        }
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
            // 本文に status がなくても、返事のステータスを入れる
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

    /// 種類 (type) がなくても、API が決めた code があれば、問題の詳細として読む。
    /// ステータスは、本文の status (目安) ではなく、返事のステータスにする
    @Test func blankProblemWithAPICodeIsRead() async {
        let transport = FakeHTTPTransport { _ in
            HTTPResponse(
                statusCode: 409, headers: ["Content-Type": "application/problem+json"],
                body: Data(#"{"code":"out_of_stock","status":400}"#.utf8))
        }
        do {
            _ = try await EPGStationAPIClient(host: "192.0.2.30", transport: transport).request(EPGStationVersionRequest())
            Issue.record("エラーになるはずの返事が通りました")
        } catch {
            #expect(RegzaError(error) == .problem(APIProblem(status: 409, code: "out_of_stock")))
            #expect(RegzaError(error).code == "api.out_of_stock")
            // 404 で分かれる処理は、ステータスを見る
            #expect(RegzaError(error).status == 409)
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
        let iOS = try SourceLine.read(under: "iOS/RegzaKit/Sources")
        #expect(!shared.isEmpty && !bridge.isEmpty && !iOS.isEmpty)
        for line in shared + bridge + iOS where line.code.contains(".localizedDescription") {
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
        // 処理を途中で止めたときは、つながらなかったとは言わない
        #expect(RegzaError(CancellationError()) == .connection(.cancelled))
    }
}
