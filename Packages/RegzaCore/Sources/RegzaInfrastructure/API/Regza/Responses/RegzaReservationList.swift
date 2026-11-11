import RegzaDomain

struct RegzaReservationList: Decodable {
    var status: Int
    var reservations: [RegzaReservation]?

    enum CodingKeys: String, CodingKey {
        case status
        case reservations = "rsv_list"
    }
}
