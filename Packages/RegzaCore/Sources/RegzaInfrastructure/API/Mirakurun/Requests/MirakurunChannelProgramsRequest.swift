import MirakurunAPI

struct MirakurunChannelProgramsRequest: MirakurunAPIRequest {
    typealias Response = MirakurunChannelProgramsResponse

    let networkID: Int
    let serviceID: Int

    func send(using client: MirakurunAPI.Client) async throws -> [MirakurunAPI.Components.Schemas.Program] {
        try await client.getPrograms(query: .init(networkId: networkID, serviceId: serviceID)).ok.body.json
    }
}
