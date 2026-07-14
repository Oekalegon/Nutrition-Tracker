import Foundation
import SwiftData

/// Energy is modeled as its own synthetic nutrient because Matvaretabellen
/// doesn't expose kcal as a regular nutrient constituent — it's a top-level
/// `calories` field on each food, not one of its `constituents`. Every other
/// real nutrient code is owned by `MatvaretabellenImporter` once it runs.
enum NutrientSeeder {
    static let energyNutrientCode = "energy_kcal"

    static func seedCoreNutrientsIfNeeded(in context: ModelContext) throws {
        let code = energyNutrientCode
        var descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.code == code })
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(Nutrient(code: code, displayName: "Energy", unit: .kilocalorie, isCore: true))
        try context.save()
    }
}
