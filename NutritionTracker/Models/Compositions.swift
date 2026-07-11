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

@Model
final class MealIngredient {
    var quantity: Measure             // already portion-sized, as eaten — e.g. Measure(150, .gram)
    var food: Food?
    var meal: Meal?

    init(quantity: Measure, food: Food? = nil, meal: Meal? = nil) {
        self.quantity = quantity
        self.food = food
        self.meal = meal
    }
}

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

@Model
final class RecipeIngredient {
    var quantity: Measure             // total for the whole recipe, not per serving — divide by Recipe.servings.
                                       // As entered, e.g. Measure(2, .deciliter) for "2 dl flour" — not pre-converted.
    var rawQuantityText: String?      // original text before parsing, e.g. "2 dl flour" — kept for audit/re-parse
    var food: Food?
    var recipe: Recipe?

    init(quantity: Measure, rawQuantityText: String? = nil, food: Food? = nil, recipe: Recipe? = nil) {
        self.quantity = quantity
        self.rawQuantityText = rawQuantityText
        self.food = food
        self.recipe = recipe
    }
}
