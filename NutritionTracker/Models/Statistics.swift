import Foundation
import SwiftData

enum TargetStatus: String, Codable {
    case noTarget
    case belowTarget
    case onTarget    // within a tolerance band around the active target, e.g. ±5%
    case aboveTarget
}

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

@Model
final class DailyNutrientTotal {
    var nutrientCode: String
    var total: Measure
    var targetStatus: TargetStatus   // computed against the target active *that day* — frozen, doesn't
                                      // repaint if the target changes later (same principle as NutritionTarget)
    var summary: DailySummary?

    init(nutrientCode: String, total: Measure, targetStatus: TargetStatus, summary: DailySummary? = nil) {
        self.nutrientCode = nutrientCode
        self.total = total
        self.targetStatus = targetStatus
        self.summary = summary
    }
}
