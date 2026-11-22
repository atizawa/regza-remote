package import RegzaDomain
internal import RegzaStrings

/// エラーを画面に出す文言にする。画面と OS の入口に出す文言は、どれもここを通す (`localizedDescription` を直接出さない)。
///
/// 文言はエラーの code (`ErrorCode`) で引く。引く順は「場面ごとの言い換え」→「どの場面でも同じ言い換え」→ エラーの元の文言。
/// code が詳しい順に並ぶとき (API の問題) は、それぞれの言い換えの中で、詳しい code から順に引く
/// API が返す code (RFC 9457 の type や、拡張メンバーの code) で分岐するときも、下の表に code と文言を足すだけで済む
package enum ErrorMessage {
    /// エラーが起きた場面
    package enum Scene: Sendable {
        /// 場面によって言い換えない
        case general
        /// チャンネル一覧を読むとき
        case channelList
        /// 録画予約を読む・操作するとき
        case recording
        /// テレビに PIN を出して登録するとき
        case pairing
        /// 選局するとき (選んだチャンネルの名前)
        case tune(channelName: String)
        /// 録画を予約するとき
        case reserve
    }

    /// 1 つの言い換え。code (とその仲間) に当てはまるエラーを、文言にする
    struct Rule: Sendable {
        var code: ErrorCode
        var text: @Sendable (RegzaError) -> String
    }

    package static func text(_ error: RegzaError, in scene: Scene = .general) -> String {
        let codes = error.codes
        func find(in table: [Rule]) -> Rule? { codes.lazy.compactMap { code in table.first { code.belongs(to: $0.code) } }.first }
        return (find(in: rules(in: scene)) ?? find(in: commonRules))?.text(error) ?? error.localizedDescription
    }

    /// RegzaError 以外のエラーも、通信のエラーとして文言にする
    package static func text(_ error: any Error, in scene: Scene = .general) -> String {
        text(RegzaError(error), in: scene)
    }

    // MARK: - 表

    /// 場面ごとの言い換え。機種が対応していないことは場面ごとに何ができないかを、受け付けなかったことは何を受け付けなかったかを伝える
    static func rules(in scene: Scene) -> [Rule] {
        let unsupported: [ErrorCode] = [.unsupported, ErrorCode.http.appending("404")]
        switch scene {
        case .general:
            return []
        case .channelList:
            return unsupported.map { Rule(code: $0) { _ in CoreStrings.channelListUnsupported } }
        case .recording:
            return unsupported.map { Rule(code: $0) { _ in CoreStrings.reservationListUnsupported } }
        case .pairing:
            return unsupported.map { Rule(code: $0) { _ in CoreStrings.tvPairingUnsupported } }
        case .tune(let channelName):
            return [Rule(code: .commandRejected) { _ in CoreStrings.channelTuneFailed(channelName) }]
        case .reserve:
            // 重なる予約が多い、ハードディスクがないなど。テレビの返した値を添える
            return [
                Rule(code: .commandRejected) { error in
                    guard case .commandRejected(let code) = error else { return error.localizedDescription }
                    return CoreStrings.programReserveRejected(code)
                }
            ]
        }
    }

    /// どの場面でも同じ言い換え。アプリが決めた code と、API の問題の種類 (type)・API が決めた code ごとの文言は、ここに足す
    /// (`ErrorCode.problemType`・`ErrorCode.apiCode` で code を作る)
    static let commonRules: [Rule] = [
        Rule(code: .streamUnavailable) { _ in CoreStrings.errorStreamUnavailable },
        Rule(code: .lockScreenStartFailed) { _ in CoreStrings.errorLockScreenStartFailed },
    ]
}
