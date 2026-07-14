import Foundation
import SwiftData

/// The single write path for source-backed `Food` rows (design doc: "one write
/// path per entity type"). Owns dedup — by `(source, sourceID)` first, then
/// `ean` — and keeps the user's own edits to `commonName`/`searchAliases`/
/// `defaultServing*`/`densityGPerMl` authoritative over a later re-sync from
/// the source: those fields are only filled in when still empty, never
/// overwritten. `name`/`brand`/`foodGroup`/nutrient values are objective
/// source data and always refreshed.
///
/// Cross-source fuzzy dedup via `searchIndex` overlap (design doc's fallback,
/// for when two sources describe the same food with no shared ID) is deferred
/// until a second source exists to actually need it — see NUTR-10.
enum FoodCatalogWriter {
    struct NutrientAmount {
        var nutrient: Nutrient
        var amount: Double

        init(nutrient: Nutrient, amount: Double) {
            self.nutrient = nutrient
            self.amount = amount
        }
    }

    @discardableResult
    static func createOrUpdateFood(
        name: String,
        brand: String? = nil,
        commonName: String? = nil,
        searchAliases: [String] = [],
        ean: String? = nil,
        source: FoodSource,
        sourceID: String?,
        foodGroup: FoodGroup? = nil,
        nutrientReferenceAmount: Measure = Measure(value: 100, unit: .gram),
        defaultServing: Measure? = nil,
        defaultServingLabel: String? = nil,
        defaultServingWeight: Measure? = nil,
        densityGPerMl: Double? = nil,
        nutrientValues: [NutrientAmount],
        in context: ModelContext
    ) throws -> Food {
        let food = try findExisting(source: source, sourceID: sourceID, ean: ean, in: context) ?? {
            let new = Food(name: name, source: source, sourceID: sourceID)
            context.insert(new)
            return new
        }()

        food.name = name
        food.brand = brand
        food.ean = food.ean ?? ean
        food.foodGroup = foodGroup
        food.nutrientReferenceAmount = nutrientReferenceAmount
        food.densityGPerMl = food.densityGPerMl ?? densityGPerMl
        if food.commonName == nil { food.commonName = commonName }
        if food.searchAliases.isEmpty { food.searchAliases = searchAliases }
        if food.defaultServing == nil { food.defaultServing = defaultServing }
        if food.defaultServingLabel == nil { food.defaultServingLabel = defaultServingLabel }
        if food.defaultServingWeight == nil { food.defaultServingWeight = defaultServingWeight }
        food.updatedAt = .now
        food.updateSearchIndex()

        upsertNutrientValues(nutrientValues, for: food, in: context)

        return food
    }

    private static func findExisting(
        source: FoodSource,
        sourceID: String?,
        ean: String?,
        in context: ModelContext
    ) throws -> Food? {
        if let sourceID {
            // Filter by sourceID (a plain String) at the SwiftData predicate layer
            // only, then check `source` in memory — comparing a captured FoodSource
            // enum directly in a #Predicate fails when the fetch runs off the main
            // actor (as it does from MatvaretabellenImporter's background context).
            let bySourceID = FetchDescriptor<Food>(predicate: #Predicate { $0.sourceID == sourceID })
            if let match = try context.fetch(bySourceID).first(where: { $0.source == source }) {
                return match
            }
        }

        if let ean {
            var byEAN = FetchDescriptor<Food>(predicate: #Predicate { $0.ean == ean })
            byEAN.fetchLimit = 1
            if let match = try context.fetch(byEAN).first {
                return match
            }
        }

        return nil
    }

    private static func upsertNutrientValues(
        _ values: [NutrientAmount],
        for food: Food,
        in context: ModelContext
    ) {
        for value in values {
            if let existing = food.nutrientValues.first(where: { $0.nutrient?.code == value.nutrient.code }) {
                existing.amount = value.amount
            } else {
                let newValue = FoodNutrientValue(amount: value.amount, food: food, nutrient: value.nutrient)
                context.insert(newValue)
                food.nutrientValues.append(newValue)
            }
        }
    }
}
