import RegzaTVAPI

protocol RegzaAPIRequest: APIRequest where Client == RegzaTVAPI.Client {
    var usesSecureConnection: Bool { get }
    var queryOverride: String? { get }
}

extension RegzaAPIRequest {
    var usesSecureConnection: Bool { false }
    var queryOverride: String? { nil }
}
