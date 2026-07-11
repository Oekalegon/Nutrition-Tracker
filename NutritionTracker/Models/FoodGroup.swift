import Foundation
import SwiftData

@Model
final class FoodGroup {
    @Attribute(.unique) var code: String   // Matvaretabellen food-group code
    var name: String
    var parent: FoodGroup?

    @Relationship(inverse: \FoodGroup.parent)
    var children: [FoodGroup] = []

    init(code: String, name: String, parent: FoodGroup? = nil) {
        self.code = code
        self.name = name
        self.parent = parent
    }
}
