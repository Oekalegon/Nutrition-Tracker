import Foundation
import SwiftData

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var name: String                  // "Cruesli with yoghurt"
    var notes: String?
    var isFavorite: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \MealIngredient.meal)
    var ingredients: [MealIngredient] = []

    init(id: UUID = UUID(), name: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}
