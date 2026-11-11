import RegzaDomain

struct RegzaChannelList: Decodable {
    var status: Int
    var channels: [RegzaChannel]?

    enum CodingKeys: String, CodingKey {
        case status
        case channels = "channel_list"
    }
}
