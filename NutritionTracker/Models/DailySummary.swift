import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var date: Date   // normalized to start of day

    @Relationship(deleteRule: .cascade, inverse: \DailyNutrientTotal.summary)
    var nutrientTotals: [DailyNutrientTotal] = []

    var updatedAt: Date = Date.now

    init(date: Date) {
        self.date = date
    }
}
