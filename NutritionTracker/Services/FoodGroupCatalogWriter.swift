import Foundation
import SwiftData

/// Upsert chokepoint for `FoodGroup` rows, keyed by `code`. Deliberately
/// doesn't wire up `parent` here — a source's food-group dump can reference a
/// parent before it's been created, so the caller resolves the full hierarchy
/// itself once every group in the batch exists (see `MatvaretabellenImporter`).
enum FoodGroupCatalogWriter {
    @discardableResult
    static func createOrUpdate(
        code: String,
        name: String,
        in context: ModelContext
    ) throws -> FoodGroup {
        var descriptor = FetchDescriptor<FoodGroup>(predicate: #Predicate { $0.code == code })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.name = name
            return existing
        }

        let group = FoodGroup(code: code, name: name)
        context.insert(group)
        return group
    }
}
