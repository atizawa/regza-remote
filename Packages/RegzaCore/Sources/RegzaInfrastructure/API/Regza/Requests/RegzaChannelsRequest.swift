import RegzaTVAPI

struct RegzaChannelsRequest: RegzaAPIRequest {
    typealias Response = RegzaChannelsResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.ChannelList {
        try await client.getChannels().ok.body.json
    }
}
