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

/// 画面に出すエラーの文言は ErrorMessage だけが作る。`localizedDescription` を読んでよいのは、
/// エラーの文言を決めるところ (ErrorMessage・RegzaError) と、OS のエラーを RegzaError に変えるところだけ
@Suite struct ErrorMessageUsageGuardTests {
    @Test func onlyErrorMessageReadsLocalizedDescription() throws {
        let repository = FakeServersContractTests.repository
        let allowed: Set<String> = [
            "Packages/RegzaCore/Sources/Presentation/PresentationCore/Errors/ErrorMessage.swift",
            "Packages/RegzaCore/Sources/RegzaDomain/Data/RegzaError.swift",
            "Packages/RegzaCore/Sources/RegzaInfrastructure/Network/URLSessionTransport.swift",
        ]
        let roots = ["Packages/RegzaCore/Sources", "Android/RegzaAndroidBridge/Sources"]
        var paths: [String] = []
        for root in roots {
            paths += try FileManager.default.subpathsOfDirectory(atPath: repository.appending(path: root).path(percentEncoded: false))
                .filter { $0.hasSuffix(".swift") && !$0.hasPrefix("RegzaFakeServers/") }
                .map { root + "/" + $0 }
                .filter { !allowed.contains($0) }
        }
        #expect(!paths.isEmpty)
        for path in paths {
            let lines = try String(contentsOf: repository.appending(path: path), encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated()
            where line.contains(".localizedDescription") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                Issue.record("\(path):\(index + 1) がエラーの文言を直接読んでいます。ErrorMessage.text で文言にしてください")
            }
        }
    }
}
