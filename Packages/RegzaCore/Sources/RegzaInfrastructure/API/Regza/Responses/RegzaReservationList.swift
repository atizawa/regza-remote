import RegzaDomain

struct RegzaReservationList: Decodable {
    var status: Int
    var reservations: [ReservationData]?

    enum CodingKeys: String, CodingKey {
        case status
        case reservations = "rsv_list"
    }
}
