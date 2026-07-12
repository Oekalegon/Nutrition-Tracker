import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var servings: Double              // Double, not Int — "makes 6 bowls" or "2.5 L soup" style yields
    var sourceURL: URL?                // kept — useful for re-parsing/refreshing, and for attribution
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(id: UUID = UUID(), name: String, servings: Double, sourceURL: URL? = nil) {
        self.id = id
        self.name = name
        self.servings = servings
        self.sourceURL = sourceURL
    }
}
