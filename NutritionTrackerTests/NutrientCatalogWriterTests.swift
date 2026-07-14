import Testing
import SwiftData
@testable import NutritionTracker

@MainActor
struct NutrientCatalogWriterTests {
    @Test func createsNewNutrient() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let nutrient = try NutrientCatalogWriter.createOrUpdate(
            code: "Protein", displayName: "Protein", unit: .gram, isCore: true, in: context
        )

        #expect(nutrient.code == "Protein")
        #expect(try context.fetchCount(FetchDescriptor<Nutrient>()) == 1)
    }

    @Test func updatesExistingNutrientInstesadOfDuplicating() throws {
        let container = try ModelContainer(for: Nutrient.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try NutrientCatalogWriter.createOrUpdate(code: "Na", displayName: "Sodium", unit: .milligram, isCore: false, in: context)
        try NutrientCatalogWriter.createOrUpdate(code: "Na", displayName: "Sodium (Na)", unit: .milligram, isCore: true, in: context)

        let all = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(all.count == 1)
        #expect(all[0].displayName == "Sodium (Na)")
        #expect(all[0].isCore)
    }
}
