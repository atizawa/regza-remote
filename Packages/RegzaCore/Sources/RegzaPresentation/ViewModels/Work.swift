public import Foundation
public import Observation
package import RegzaDomain

/// 操作から始めた処理を数える (終わるまで ViewModel の isBusy を true にする)。
/// Android の窓口が、読み込みの終わり (引っ張って読み直したときの印を消す) を知れるよう、変わったら知らせる
@MainActor
@Observable
final class Work {
    private(set) var running = 0

    var isBusy: Bool { running > 0 }

    func run(_ operation: @escaping @MainActor () async -> Void) {
        running += 1
        Task {
            await operation()
            running -= 1
        }
    }
}
