import Foundation

struct MatvaretabellenNutrient: Codable, Hashable {
    var nutrientId: String
    var name: String
    var euroFirId: String
    var euroFirName: String
    var unit: String
    var decimalPrecision: Int
    var parentId: String?
    var uri: String
}
