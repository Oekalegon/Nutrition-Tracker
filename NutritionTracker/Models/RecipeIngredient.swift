import Foundation
import SwiftData

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
