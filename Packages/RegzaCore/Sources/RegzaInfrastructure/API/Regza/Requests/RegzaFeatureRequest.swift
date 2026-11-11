import RegzaTVAPI

struct RegzaFeatureRequest: RegzaAPIRequest {
    typealias Response = RegzaFeatureResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Feature {
        try await apiClient.getFeature().ok.body.json
    }
}
