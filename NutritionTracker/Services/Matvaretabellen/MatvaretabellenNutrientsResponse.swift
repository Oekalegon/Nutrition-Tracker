import Foundation

struct MatvaretabellenNutrientsResponse: Codable, Hashable {
    var nutrients: [MatvaretabellenNutrient]
    var locale: String
}
