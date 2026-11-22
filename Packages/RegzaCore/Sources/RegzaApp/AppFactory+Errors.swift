import PresentationCore
import RegzaDomain

extension AppFactory {
    /// 画面のない入口 (ウィジェットのボタンなど) が出すエラーの文言。画面と同じく ErrorMessage を通す
    nonisolated public static func errorMessage(for error: any Error) -> String {
        ErrorMessage.text(error)
    }
}
