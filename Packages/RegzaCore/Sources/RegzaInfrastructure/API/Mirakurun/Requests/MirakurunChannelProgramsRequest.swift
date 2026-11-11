import MirakurunAPI

struct MirakurunChannelProgramsRequest: MirakurunAPIRequest {
    typealias Response = MirakurunChannelProgramsResponse

    let networkID: Int
    let serviceID: Int

    func send(using apiClient: MirakurunAPI.Client) async throws -> [MirakurunAPI.Components.Schemas.Program] {
        try await apiClient.getPrograms(query: .init(networkId: networkID, serviceId: serviceID)).ok.body.json
    }
}
