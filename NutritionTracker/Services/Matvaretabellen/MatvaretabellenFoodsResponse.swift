import Foundation

struct MatvaretabellenFoodsResponse: Codable, Hashable {
    var foods: [MatvaretabellenFood]
    var locale: String
}
