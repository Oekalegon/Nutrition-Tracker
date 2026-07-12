import Foundation
import SwiftData

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
