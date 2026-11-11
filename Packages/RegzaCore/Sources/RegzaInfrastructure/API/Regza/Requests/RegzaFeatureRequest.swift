import RegzaTVAPI

struct RegzaFeatureRequest: RegzaAPIRequest {
    typealias Response = RegzaFeatureResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Feature {
        try await client.getFeature().ok.body.json
    }
}
