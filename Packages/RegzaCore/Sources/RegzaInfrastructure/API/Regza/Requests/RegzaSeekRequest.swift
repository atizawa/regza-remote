import RegzaTVAPI

struct RegzaSeekRequest: RegzaAPIRequest {
    typealias Response = NoContentAPIResponse

    let seconds: Int
    var queryOverride: String? { String(max(0, seconds)) }

    func send(using apiClient: RegzaTVAPI.Client) async throws {
        _ = try await apiClient.seek()
    }
}
