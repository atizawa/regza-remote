import RegzaDomain

struct RegzaChannelList: Decodable {
    var status: Int
    var channels: [ChannelData]?

    enum CodingKeys: String, CodingKey {
        case status
        case channels = "channel_list"
    }
}
