import EPGStationAPI

struct EPGStationStartStreamResponse: APIResponse {
    let value: Int

    init(_ output: EPGStationAPI.Components.Schemas.StartStreamInfo) async throws {
        value = output.streamId
    }
}
