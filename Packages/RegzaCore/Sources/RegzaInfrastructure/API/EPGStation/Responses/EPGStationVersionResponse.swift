import EPGStationAPI

struct EPGStationVersionResponse: APIResponse {
    let value: Bool

    init(_ output: EPGStationAPI.Components.Schemas.Version) async throws {
        _ = output.version
        value = true
    }
}
