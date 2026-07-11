import Foundation
import SwiftData

@Model
final class FoodNutrientValue {
    var amount: Double        // in `nutrient.unit`, per `food.nutrientReferenceAmount`
    var food: Food?
    var nutrient: Nutrient?

    init(amount: Double, food: Food? = nil, nutrient: Nutrient? = nil) {
        self.amount = amount
        self.food = food
        self.nutrient = nutrient
    }
}
