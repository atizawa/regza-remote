import RegzaDomain
import RegzaTVAPI

struct RegzaPairingChallengeResponse: APIResponse, Equatable {
    var value: Self { self }
    let status: Int
    let password: String?
    let salt: String?

    init(_ output: RegzaTVAPI.Components.Schemas.ConnectionChallenge) async throws {
        guard output.status == 0 else { throw RegzaError.commandRejected(String(output.status)) }
        status = output.status
        password = output.password
        salt = output.salt
    }
}
