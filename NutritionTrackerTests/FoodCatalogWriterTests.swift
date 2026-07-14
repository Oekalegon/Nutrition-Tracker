import Testing
import SwiftData
@testable import NutritionTracker

@MainActor
struct FoodCatalogWriterTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Food.self, FoodNutrientValue.self, Nutrient.self, FoodGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func createsNewFoodWithNutrientValues() throws {
        let context = try makeContainer().mainContext
        let protein = Nutrient(code: "Protein", displayName: "Protein", unit: .gram)
        context.insert(protein)

        let food = try FoodCatalogWriter.createOrUpdateFood(
            name: "Adzuki beans, uncooked",
            source: .matvaretabellen,
            sourceID: "06.178",
            nutrientValues: [.init(nutrient: protein, amount: 19.9)],
            in: context
        )

        #expect(food.source == .matvaretabellen)
        #expect(food.sourceID == "06.178")
        #expect(food.nutrientValues.count == 1)
        #expect(food.nutrientValues.first?.amount == 19.9)
        #expect(try context.fetchCount(FetchDescriptor<Food>()) == 1)
    }

    @Test func reimportingSameSourceIDUpdatesInsteadOfDuplicating() throws {
        let context = try makeContainer().mainContext
        let protein = Nutrient(code: "Protein", displayName: "Protein", unit: .gram)
        context.insert(protein)

        try FoodCatalogWriter.createOrUpdateFood(
            name: "Adzuki beans, uncooked", source: .matvaretabellen, sourceID: "06.178",
            nutrientValues: [.init(nutrient: protein, amount: 19.9)], in: context
        )
        try FoodCatalogWriter.createOrUpdateFood(
            name: "Adzuki beans, uncooked (updated)", source: .matvaretabellen, sourceID: "06.178",
            nutrientValues: [.init(nutrient: protein, amount: 20.5)], in: context
        )

        let all = try context.fetch(FetchDescriptor<Food>())
        #expect(all.count == 1)
        #expect(all[0].name == "Adzuki beans, uncooked (updated)")
        #expect(all[0].nutrientValues.count == 1)
        #expect(all[0].nutrientValues.first?.amount == 20.5)
    }

    @Test func userEditedCommonNameSurvivesResync() throws {
        let context = try makeContainer().mainContext

        let food = try FoodCatalogWriter.createOrUpdateFood(
            name: "Kjøttdeig", commonName: nil, source: .matvaretabellen, sourceID: "10.001",
            nutrientValues: [], in: context
        )
        food.commonName = "kjøttdeig" // simulates the user correcting it in the UI
        food.updateSearchIndex()

        try FoodCatalogWriter.createOrUpdateFood(
            name: "Kjøttdeig", commonName: "some source-supplied value", source: .matvaretabellen, sourceID: "10.001",
            nutrientValues: [], in: context
        )

        #expect(food.commonName == "kjøttdeig")
    }

    @Test func objectiveFieldsAlwaysRefreshOnResync() throws {
        let context = try makeContainer().mainContext
        let groupA = FoodGroup(code: "1", name: "Group A")
        let groupB = FoodGroup(code: "2", name: "Group B")
        context.insert(groupA)
        context.insert(groupB)

        let food = try FoodCatalogWriter.createOrUpdateFood(
            name: "Old name", source: .matvaretabellen, sourceID: "10.001", foodGroup: groupA,
            nutrientValues: [], in: context
        )
        #expect(food.foodGroup === groupA)

        try FoodCatalogWriter.createOrUpdateFood(
            name: "New name", source: .matvaretabellen, sourceID: "10.001", foodGroup: groupB,
            nutrientValues: [], in: context
        )

        #expect(food.name == "New name")
        #expect(food.foodGroup === groupB)
    }

    @Test func dedupsByEANWhenNoSourceIDMatch() throws {
        let context = try makeContainer().mainContext

        let food = try FoodCatalogWriter.createOrUpdateFood(
            name: "Freia Melkesjokolade", ean: "7040513000208", source: .kassalapp, sourceID: "abc",
            nutrientValues: [], in: context
        )

        try FoodCatalogWriter.createOrUpdateFood(
            name: "Freia Melkesjokolade (relisted)", ean: "7040513000208", source: .kassalapp, sourceID: nil,
            nutrientValues: [], in: context
        )

        let all = try context.fetch(FetchDescriptor<Food>())
        #expect(all.count == 1)
        #expect(all[0].id == food.id)
        #expect(all[0].name == "Freia Melkesjokolade (relisted)")
    }
}
