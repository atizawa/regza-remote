import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaSharedModels
@testable import RegzaStrings

/// 共有の Swift の文言の引き方 (OS が文言を入れたとき・入れていないとき、両 OS の書式)。
/// 入れた文言はプロセス全体に効き、並行して動くほかのテストの表示を変えてしまうので、ここでは入れずに、引き方だけを確かめる
@Suite struct CoreStringTableTests {
    @Test func usesSourceLanguageWithoutInstalledStrings() {
        #expect(CoreStrings.keyPower == "電源")
        #expect(RegzaKey.power.label == "電源")
        #expect(RegzaError.httpStatus(404).localizedDescription == "HTTPエラー (404)")
        #expect(CoreStrings.reservationCancelFailed("番組", "理由") == "「番組」の予約を取り消せませんでした: 理由")
        #expect(CoreStringTable.locale.identifier == "ja_JP")
    }

    @Test func usesInstalledStringsAndFallsBackForMissingKeys() {
        let installed = ["core_key_power": "Power", "core_error_http_status": "HTTP error (%1$d)"]
        #expect(CoreStringTable.text("core_key_power", [], installed: installed) == "Power")
        // Android の文字列リソースの書式でも引数を入れる
        #expect(CoreStringTable.text("core_error_http_status", [.int(404)], installed: installed) == "HTTP error (404)")
        // 入れた中にないキーは元言語
        #expect(CoreStringTable.text("core_key_mute", [], installed: installed) == "消音")
    }

    @Test func formatsBothPlatformStyles() {
        let arguments: [CoreStringTable.Argument] = [.string("A"), .int(42)]
        // iOS の String Catalog の形
        #expect(CoreStringTable.format("%@ / %lld", arguments) == "A / 42")
        #expect(CoreStringTable.format("%2$lld / %1$@", arguments) == "42 / A")
        // Android の文字列リソースの形
        #expect(CoreStringTable.format("%1$s / %2$d", arguments) == "A / 42")
        #expect(CoreStringTable.format("%2$d / %1$s", arguments) == "42 / A")
        #expect(CoreStringTable.format("%.2f", [.double(1.5)]) == "1.50")
        #expect(CoreStringTable.format("100%% %@", [.string("OK")]) == "100% OK")
        // 読めない指定・足りない引数は、文言を壊さない
        #expect(CoreStringTable.format("50% off", []) == "50% off")
        #expect(CoreStringTable.format("%@ と %@", [.string("A")]) == "A と ")
    }

    @Test func everyGeneratedKeyHasSourceText() {
        #expect(!CoreStringTable.keys.isEmpty)
        #expect(CoreStringTable.keys.allSatisfy { $0.hasPrefix("core_") })
        #expect(CoreStringTable.keys.allSatisfy { CoreStrings.sourceTemplates[$0]?.isEmpty == false })
    }
}
