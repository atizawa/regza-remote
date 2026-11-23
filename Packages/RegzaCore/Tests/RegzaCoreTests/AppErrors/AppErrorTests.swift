import Foundation
import Testing

@testable import AppErrors

/// 共通のエラー (AppError) は、アプリ固有の失敗を入れ替えても使える (雛形として別のアプリに使うとき)
@Suite struct AppErrorTests {
    /// 別のアプリ固有の失敗
    enum OtherFailure: AppSpecificError {
        case outOfStock

        var code: ErrorCode { "out_of_stock" }
        var message: String { "在庫がありません" }
    }

    typealias OtherError = AppError<OtherFailure>

    @Test func appSpecificFailureDecidesItsCodeAndMessage() {
        #expect(OtherError.app(.outOfStock).code == "out_of_stock")
        #expect(OtherError.app(.outOfStock).localizedDescription == "在庫がありません")
    }

    @Test func commonFailuresDoNotDependOnTheApp() {
        #expect(OtherError.httpStatus(404).code == "http.404")
        #expect(OtherError.connection(.timedOut).code == "connection.timed_out")
        #expect(OtherError.problem(APIProblem(status: 409, code: "busy")).codes == ["api.busy", "http.409"])
        #expect(OtherError.httpStatus(404).isNotFound)
        #expect(OtherError(CancellationError()) == .connection(.cancelled))
        #expect(OtherError(OtherError.app(.outOfStock)) == .app(.outOfStock))
        #expect(OtherError.httpStatus(404).isUnidentifiedNotFound)
        #expect(OtherError.problem(APIProblem(status: 404)).isUnidentifiedNotFound)
        #expect(!OtherError.problem(APIProblem(status: 404, code: "gone")).isUnidentifiedNotFound)
    }
}
