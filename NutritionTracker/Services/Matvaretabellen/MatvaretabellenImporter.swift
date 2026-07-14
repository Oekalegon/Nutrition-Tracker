import Foundation
import SwiftData

/// Maps the four Matvaretabellen JSON dumps into the local SwiftData catalog,
/// writing exclusively through `NutrientCatalogWriter`/`FoodGroupCatalogWriter`/
/// `FoodCatalogWriter`. A plain actor holding its own `ModelContext` (not the
/// app's `mainContext`), so importing ~2,100 foods runs off the main actor
/// without blocking the UI.
///
/// This builds and tests the importer as a callable unit only — deciding
/// *when* it actually runs in the shipped app (first launch? a Settings
/// "Refresh catalog" action? a background task?) is a deliberate follow-up,
/// not decided here.
actor MatvaretabellenImporter {
    /// Matvaretabellen nutrientIds that correspond to the app's core macros.
    /// Everything else in the dump is still imported, just with isCore = false.
    private static let coreNutrientIds: Set<String> = ["Protein", "Fett", "Karbo", "Fiber", "Mono+Di", "Na"]

    private let client: MatvaretabellenClient
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer, client: MatvaretabellenClient = MatvaretabellenClient()) {
        self.client = client
        self.modelContext = ModelContext(modelContainer)
    }

    /// Assumes `NutrientSeeder.seedCoreNutrientsIfNeeded` has already run against
    /// this container — if the energy_kcal nutrient doesn't exist yet, energy
    /// values are silently skipped for every food (everything else still imports).
    func importAll(locale: MatvaretabellenLocale = .english) async throws {
        let nutrientsByCode = try await importNutrients(locale: locale)
        let foodGroupsByCode = try await importFoodGroups(locale: locale)
        try await importFoods(locale: locale, nutrientsByCode: nutrientsByCode, foodGroupsByCode: foodGroupsByCode)
        try modelContext.save()
    }

    private func importNutrients(locale: MatvaretabellenLocale) async throws -> [String: Nutrient] {
        let response = try await client.fetchNutrients(locale: locale)
        var byCode: [String: Nutrient] = [:]

        // The synthetic energy_kcal nutrient isn't part of Matvaretabellen's own
        // list (see importFoods) — it's created by NutrientSeeder at app launch,
        // not here. Look it up rather than create it, so there's exactly one
        // place that owns its displayName/unit/isCore.
        let energyCode = NutrientSeeder.energyNutrientCode
        var energyDescriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.code == energyCode })
        energyDescriptor.fetchLimit = 1
        if let energyNutrient = try modelContext.fetch(energyDescriptor).first {
            byCode[energyCode] = energyNutrient
        }

        for nutrient in response.nutrients {
            // A handful of nutrients (Vitamin A variants, Vitamin E) use
            // bioactivity-equivalent units (RAE/RE/mg-ATE) with no MeasurementUnit
            // equivalent — skip rather than mislabel them as plain mass.
            guard let unit = measurementUnit(for: nutrient.unit) else { continue }
            let isCore = Self.coreNutrientIds.contains(nutrient.nutrientId)
            byCode[nutrient.nutrientId] = try NutrientCatalogWriter.createOrUpdate(
                code: nutrient.nutrientId,
                displayName: nutrient.name,
                unit: unit,
                isCore: isCore,
                in: modelContext
            )
        }

        return byCode
    }

    private func importFoodGroups(locale: MatvaretabellenLocale) async throws -> [String: FoodGroup] {
        let response = try await client.fetchFoodGroups(locale: locale)
        var byCode: [String: FoodGroup] = [:]

        for group in response.foodGroups {
            byCode[group.foodGroupId] = try FoodGroupCatalogWriter.createOrUpdate(
                code: group.foodGroupId,
                name: group.name,
                in: modelContext
            )
        }

        // Second pass: every group now exists, so parent references can be wired
        // up regardless of which order they appeared in the dump.
        for group in response.foodGroups {
            guard let parentId = group.parentId else { continue }
            byCode[group.foodGroupId]?.parent = byCode[parentId]
        }

        return byCode
    }

    private func importFoods(
        locale: MatvaretabellenLocale,
        nutrientsByCode: [String: Nutrient],
        foodGroupsByCode: [String: FoodGroup]
    ) async throws {
        let response = try await client.fetchFoods(locale: locale)

        for food in response.foods {
            var nutrientValues: [FoodCatalogWriter.NutrientAmount] = []

            // Energy isn't one of `constituents` — it's the food's own top-level
            // `calories` field — so it's mapped separately onto the synthetic
            // energy_kcal nutrient from NutrientSeeder.
            if let kcal = food.calories.quantity,
               let energyNutrient = nutrientsByCode[NutrientSeeder.energyNutrientCode] {
                nutrientValues.append(FoodCatalogWriter.NutrientAmount(nutrient: energyNutrient, amount: kcal))
            }

            for constituent in food.constituents {
                guard let quantity = constituent.quantity,
                      let nutrient = nutrientsByCode[constituent.nutrientId] else { continue }
                nutrientValues.append(FoodCatalogWriter.NutrientAmount(nutrient: nutrient, amount: quantity))
            }

            let serving = defaultServingInfo(from: food.portions)

            try FoodCatalogWriter.createOrUpdateFood(
                name: food.foodName,
                source: .matvaretabellen,
                sourceID: food.foodId,
                foodGroup: foodGroupsByCode[food.foodGroupId],
                defaultServing: serving.measure,
                defaultServingLabel: serving.label,
                defaultServingWeight: serving.weight,
                nutrientValues: nutrientValues,
                in: modelContext
            )
        }
    }

    /// Only "dl" (deciliter) and "stk" (piece) portions map cleanly onto
    /// `MeasurementUnit`. Matvaretabellen also has custom named portions with
    /// no unit at all (e.g. "glass (large)"), which are skipped rather than
    /// guessed at. When multiple eligible portions exist, the first one wins —
    /// `Food` only has room for a single default serving today.
    private func defaultServingInfo(
        from portions: [MatvaretabellenPortion]
    ) -> (measure: Measure?, label: String?, weight: Measure?) {
        guard let portion = portions.first(where: { $0.portionUnit == "dl" || $0.portionUnit == "stk" }) else {
            return (nil, nil, nil)
        }
        let unit: MeasurementUnit = portion.portionUnit == "dl" ? .deciliter : .piece
        return (Measure(value: 1, unit: unit), portion.portionName, Measure(value: portion.quantity, unit: .gram))
    }

    private func measurementUnit(for matvaretabellenUnit: String) -> MeasurementUnit? {
        switch matvaretabellenUnit {
        case "g": return .gram
        case "mg": return .milligram
        case "µg": return .microgram
        default: return nil
        }
    }
}
