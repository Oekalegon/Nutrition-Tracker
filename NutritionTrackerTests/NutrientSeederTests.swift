import Testing
import SwiftData
@testable import NutritionTracker

@MainActor
struct NutrientSeederTests {
    @Test func seedsCoreNutrients() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)

        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.count == NutrientSeeder.coreNutrients.count)
        #expect(nutrients.contains { $0.code == "energy_kcal" && $0.isCore })
        #expect(nutrients.contains { $0.code == "sodium" && !$0.isCore })
    }

    @Test func seedingIsIdempotent() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)
        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: context)

        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.count == NutrientSeeder.coreNutrients.count)
    }
}
