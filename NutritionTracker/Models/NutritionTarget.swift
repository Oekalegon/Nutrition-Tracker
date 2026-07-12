import Foundation
import SwiftData

@Model
final class NutritionTarget {
    @Attribute(.unique) var id: UUID
    var nutrientCode: String        // "energi_kcal", "protein", etc.
    var dailyAmount: Measure
    var effectiveFrom: Date
    var effectiveTo: Date?          // nil = currently active
    var source: TargetSource
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), nutrientCode: String, dailyAmount: Measure,
         effectiveFrom: Date, effectiveTo: Date? = nil, source: TargetSource) {
        self.id = id
        self.nutrientCode = nutrientCode
        self.dailyAmount = dailyAmount
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.source = source
    }
}
