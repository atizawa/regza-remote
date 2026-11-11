import Foundation
import RegzaDomain

// テレビの v2 API の応答を包む形 (中身は Domain の型として読む)

struct RegzaChannelList: Decodable {
    var status: Int
    var channels: [RegzaChannel]?

    enum CodingKeys: String, CodingKey {
        case status
        case channels = "channel_list"
    }
}

struct RegzaResult: Decodable {
    var status: Int
}

struct RegzaReservationList: Decodable {
    var status: Int
    var reservations: [RegzaReservation]?

    enum CodingKeys: String, CodingKey {
        case status
        case reservations = "rsv_list"
    }
}
