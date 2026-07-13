import Foundation
import SwiftData

enum NutrientSeeder {
    /// Codes are provisional — reconcile against Matvaretabellen's actual nutrient
    /// codes once the importer (see design doc) lands; until then these match the
    /// intended HealthKit dietary-type mapping in the design doc.
    static let coreNutrients: [(code: String, displayName: String, unit: MeasurementUnit, isCore: Bool)] = [
        ("energy_kcal", "Energy", .kilocalorie, true),
        ("protein", "Protein", .gram, true),
        ("fat", "Fat", .gram, true),
        ("carbohydrate", "Carbohydrate", .gram, true),
        ("fiber", "Fiber", .gram, false),
        ("sugar", "Sugar", .gram, false),
        ("sodium", "Sodium", .milligram, false),
    ]

    static func seedCoreNutrientsIfNeeded(in context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<Nutrient>())
        guard existingCount == 0 else { return }

        for entry in coreNutrients {
            context.insert(Nutrient(code: entry.code, displayName: entry.displayName, unit: entry.unit, isCore: entry.isCore))
        }

        try context.save()
    }
}
