import Foundation
import SwiftData

enum MealSlot: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack
}

enum DiarySourceType: String, Codable {
    case freeEntry   // ad-hoc item(s), not tied to a saved Meal/Recipe
    case meal
    case recipe
}

@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var mealSlot: MealSlot?
    var sourceType: DiarySourceType
    var label: String?                // display label — inferred from items, or the Meal/Recipe name

    var meal: Meal?                   // set if sourceType == .meal
    var recipe: Recipe?               // set if sourceType == .recipe
    var recipeServingsEaten: Double?  // e.g. 1.5 — only used with .recipe

    var rawInputText: String?         // original free text / link the user entered, for debugging & re-parsing
    var createdAt: Date = Date.now

    /// Nutrient.code -> HKSample.uuid for samples written to HealthKit for
    /// this entry (only if Health export is enabled). Lets edits/deletes
    /// update or remove the matching sample instead of orphaning it.
    var healthKitSampleIDs: [String: UUID] = [:]

    @Relationship(deleteRule: .cascade, inverse: \DiaryItem.entry)
    var items: [DiaryItem] = []

    init(id: UUID = UUID(), timestamp: Date, mealSlot: MealSlot? = nil,
         sourceType: DiarySourceType, label: String? = nil, rawInputText: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.mealSlot = mealSlot
        self.sourceType = sourceType
        self.label = label
        self.rawInputText = rawInputText
    }
}

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
