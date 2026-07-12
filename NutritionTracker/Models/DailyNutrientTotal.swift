import Foundation
import SwiftData

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
