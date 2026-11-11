import RegzaDomain
import RegzaTVAPI

struct RegzaChannelsResponse: APIResponse {
    let value: [RegzaChannel]

    init(_ output: RegzaTVAPI.Components.Schemas.ChannelList) async throws {
        let list: RegzaChannelList = try RegzaResponseDecoding.model(from: output)
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        value = list.channels ?? []
    }
}
