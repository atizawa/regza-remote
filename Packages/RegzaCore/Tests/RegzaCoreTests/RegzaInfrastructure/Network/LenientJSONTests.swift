import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct LenientJSONTests {
    /// 文字列の中にそのまま入った制御文字 (Mirakurun の番組の説明に入っていたもの) を、決まりどおりの書き方にする
    @Test func escapesRawControlCharacterInString() throws {
        let raw = Data(#"[{"name":"番組","description":"説明"#.utf8) + Data([0x1F]) + Data(#"の続き"}]"#.utf8)
        #expect(throws: (any Error).self) { try JSONSerialization.jsonObject(with: raw) }

        let fixed = LenientJSON.escapingControlCharactersInStrings(raw)
        let object = try #require(try JSONSerialization.jsonObject(with: fixed) as? [[String: String]])
        #expect(object.first?["description"] == "説明\u{1F}の続き")
    }

    /// 文字列の外の改行や空白、すでに正しく書かれたものは変えない
    @Test func keepsValidJSONAsIs() throws {
        let valid = Data("[\n  {\"text\": \"a\\\"b\\\\c\\u001fd\\n\"}\n]\n".utf8)
        #expect(LenientJSON.escapingControlCharactersInStrings(valid) == valid)
        let compact = Data(#"{"a":"b"}"#.utf8)
        #expect(LenientJSON.escapingControlCharactersInStrings(compact) == compact)
    }

    /// Mirakurun の番組の一覧に制御文字が入っていても、番組表を読める
    @Test func mirakurunProgramsDecodeWithControlCharacter() async throws {
        let body =
            Data(
                #"[{"id":1,"eventId":1,"serviceId":1024,"networkId":32736,"startAt":1793664000000,"duration":1800000,"name":"ニュース","description":"一行目"#
                    .utf8) + Data([0x1F]) + Data(#"二行目"}]"#.utf8)
        let transport = FakeHTTPTransport { _ in HTTPResponse(statusCode: 200, headers: [:], body: body) }
        let programs = try await MirakurunAPIClient(host: "192.0.2.20", transport: transport).request(MirakurunAllProgramsRequest())
        #expect(programs.map(\.name) == ["ニュース"])
    }
}
