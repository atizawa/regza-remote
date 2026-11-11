import RegzaTVAPI

struct RegzaFeatureResponse: APIResponse, Decodable {
    var value: Self { self }
    let status: Int
    let deviceType: String?
    let model: String?
    let size: String?
    let ipcFeature: [String]?

    init(_ output: RegzaTVAPI.Components.Schemas.Feature) async throws {
        status = output.status
        deviceType = output.device_type
        model = output.model
        size = output.size
        ipcFeature = output.ipc_feature
    }

    enum CodingKeys: String, CodingKey {
        case status, model, size
        case deviceType = "device_type"
        case ipcFeature = "ipc_feature"
    }

    var isTV: Bool { status == 0 && deviceType == "DTV" }
}
