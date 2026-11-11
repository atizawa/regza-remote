import MirakurunAPI

struct MirakurunVersionResponse: APIResponse {
    let value: Bool

    init(_ output: MirakurunAPI.Components.Schemas.Version) async throws {
        value = output.current != nil
    }
}
