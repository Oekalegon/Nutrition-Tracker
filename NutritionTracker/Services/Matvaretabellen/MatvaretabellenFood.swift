import Foundation

/// Nutrient values in `constituents` are per 100 g (per 100 ml for liquids),
/// matching `Food.nutrientReferenceAmount`'s default in the SwiftData catalog.
struct MatvaretabellenFood: Codable, Hashable {
    var foodId: String
    var foodName: String
    var latinName: String?
    var uri: String
    var foodGroupId: String
    var searchKeywords: [String]
    var langualCodes: [String]
    var energy: MatvaretabellenValue
    var calories: MatvaretabellenValue
    var ediblePart: MatvaretabellenEdiblePart
    var portions: [MatvaretabellenPortion]
    var constituents: [MatvaretabellenConstituent]
}
