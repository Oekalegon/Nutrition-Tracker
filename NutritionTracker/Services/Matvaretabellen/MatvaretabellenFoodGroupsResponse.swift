import Foundation

struct MatvaretabellenFoodGroupsResponse: Codable, Hashable {
    var foodGroups: [MatvaretabellenFoodGroup]
    var locale: String
}
