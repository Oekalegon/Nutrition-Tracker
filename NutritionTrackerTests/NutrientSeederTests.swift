import Testing
import SwiftData
@testable import NutritionTracker

@MainActor
struct NutrientSeederTests {
    @Test func seedsEnergyNutrient() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)

        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.count == 1)
        #expect(nutrients.contains { $0.code == NutrientSeeder.energyNutrientCode && $0.isCore && $0.unit == .kilocalorie })
    }

    @Test func seedingIsIdempotent() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)
        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)

        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.count == 1)
    }

    @Test func doesNotReseedWhenOtherNutrientsAlreadyExist() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.insert(Nutrient(code: "Protein", displayName: "Protein", unit: .gram, isCore: true))
        try context.save()

        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)

        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.count == 2)
        #expect(nutrients.contains { $0.code == NutrientSeeder.energyNutrientCode })
    }
}
