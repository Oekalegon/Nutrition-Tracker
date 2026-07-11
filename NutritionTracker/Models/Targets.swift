import Foundation
import SwiftData

enum TargetSource: String, Codable {
    case userSet
    case derivedFromWeightGoal   // suggested by the weight-goal calculator, then accepted by the user
}

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

enum WeightSource: String, Codable {
    case healthKit
    case userEntered
}

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Measure
    var source: WeightSource
    var healthKitSampleID: UUID?    // for de-duping re-imports

    init(id: UUID = UUID(), date: Date, weight: Measure, source: WeightSource,
         healthKitSampleID: UUID? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.source = source
        self.healthKitSampleID = healthKitSampleID
    }
}
