import Foundation

struct MatvaretabellenFoodGroup: Codable, Hashable {
    var foodGroupId: String
    var name: String
    var parentId: String?
}
