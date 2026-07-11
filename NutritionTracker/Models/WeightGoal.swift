import Foundation
import SwiftData

@Model
final class WeightGoal {
    @Attribute(.unique) var id: UUID
    var targetWeight: Measure       // e.g. Measure(72, .kilogram)
    var targetDate: Date            // e.g. Dec 31
    var startWeight: Measure?
    var startDate: Date
    var isActive: Bool = true
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), targetWeight: Measure, targetDate: Date,
         startWeight: Measure? = nil, startDate: Date = .now) {
        self.id = id
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.startWeight = startWeight
        self.startDate = startDate
    }
}
