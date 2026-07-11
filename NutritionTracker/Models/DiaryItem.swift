import Foundation
import SwiftData

@Model
final class DiaryItem {
    var quantity: Measure       // as logged, e.g. Measure(1, .piece) or Measure(150, .gram)
    var food: Food?
    var entry: DiaryEntry?

    @Relationship(deleteRule: .cascade, inverse: \DiaryItemNutrientValue.item)
    var nutrientSnapshot: [DiaryItemNutrientValue] = []

    init(quantity: Measure, food: Food? = nil, entry: DiaryEntry? = nil) {
        self.quantity = quantity
        self.food = food
        self.entry = entry
    }
}
