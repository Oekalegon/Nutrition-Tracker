import Foundation
import SwiftData

@Model
final class DiaryItemNutrientValue {
    var nutrientCode: String        // denormalized (not a relationship) — survives Nutrient catalog edits
    var quantity: Measure
    var item: DiaryItem?

    init(nutrientCode: String, quantity: Measure, item: DiaryItem? = nil) {
        self.nutrientCode = nutrientCode
        self.quantity = quantity
        self.item = item
    }
}
