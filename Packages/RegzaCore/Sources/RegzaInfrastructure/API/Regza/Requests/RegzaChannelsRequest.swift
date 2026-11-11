import RegzaTVAPI

struct RegzaChannelsRequest: RegzaAPIRequest {
    typealias Response = RegzaChannelsResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.ChannelList {
        try await apiClient.getChannels().ok.body.json
    }
}
