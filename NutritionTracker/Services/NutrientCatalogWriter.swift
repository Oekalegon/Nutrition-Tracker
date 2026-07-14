import Foundation
import SwiftData

/// Upsert chokepoint for `Nutrient` rows, keyed by `code`. Source-agnostic —
/// any importer (Matvaretabellen, and later Kassalapp/Open Food Facts if they
/// ever introduce their own nutrient catalogs) writes through here so the
/// unique-`code` constraint is respected without every call site re-deriving
/// find-or-insert logic.
enum NutrientCatalogWriter {
    @discardableResult
    static func createOrUpdate(
        code: String,
        displayName: String,
        unit: MeasurementUnit,
        isCore: Bool,
        in context: ModelContext
    ) throws -> Nutrient {
        var descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.code == code })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.displayName = displayName
            existing.unit = unit
            existing.isCore = isCore
            return existing
        }

        let nutrient = Nutrient(code: code, displayName: displayName, unit: unit, isCore: isCore)
        context.insert(nutrient)
        return nutrient
    }
}
