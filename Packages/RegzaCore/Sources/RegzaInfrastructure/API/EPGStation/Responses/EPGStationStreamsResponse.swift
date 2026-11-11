import EPGStationAPI

struct EPGStationStreamsResponse: APIResponse {
    let value: [Stream]

    init(_ output: EPGStationAPI.Components.Schemas.StreamInfo) async throws {
        value = output.items.compactMap { item in
            item.streamId.map { Stream(id: $0, isEnabled: item.isEnable ?? false) }
        }
    }
    struct Stream: Sendable, Equatable {
        var id: Int
        var isEnabled: Bool
    }
}
