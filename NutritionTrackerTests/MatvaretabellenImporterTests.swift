import Testing
import Foundation
import SwiftData
@testable import NutritionTracker

@MainActor
struct MatvaretabellenImporterTests {
    private static let nutrientsFixture = """
    {
      "locale": "en",
      "nutrients": [
        { "uri": "u", "nutrientId": "Protein", "name": "Protein", "euroFirId": "PROT", "euroFirName": "protein", "unit": "g", "decimalPrecision": 1 },
        { "uri": "u", "nutrientId": "Fett", "name": "Fat", "euroFirId": "FAT", "euroFirName": "fat", "unit": "g", "decimalPrecision": 1 },
        { "uri": "u", "nutrientId": "Vit A", "name": "Vitamin A (RAE)", "euroFirId": "VITA", "euroFirName": "vitamin a", "unit": "RAE", "decimalPrecision": 0 }
      ]
    }
    """

    private static let foodGroupsFixture = """
    {
      "locale": "en",
      "foodGroups": [
        { "foodGroupId": "1", "name": "Dairy products" },
        { "foodGroupId": "1.1", "name": "Milk", "parentId": "1" }
      ]
    }
    """

    private static let foodsFixture = """
    {
      "locale": "en",
      "foods": [
        {
          "foodId": "06.178",
          "foodName": "Adzuki beans, uncooked",
          "latinName": "Vigna angularis",
          "uri": "u",
          "foodGroupId": "1.1",
          "searchKeywords": ["legumes"],
          "langualCodes": [],
          "energy": { "sourceId": "MI0114", "quantity": 1312.4, "unit": "kJ" },
          "calories": { "sourceId": "MI0115", "quantity": 310, "unit": "kcal" },
          "ediblePart": { "percent": 100, "sourceId": "0" },
          "portions": [
            { "portionName": "decilitre", "portionUnit": "dl", "quantity": 85.0, "unit": "g" }
          ],
          "constituents": [
            { "sourceId": "460g", "quantity": 19.9, "unit": "g", "nutrientId": "Protein" },
            { "sourceId": "460g", "quantity": 0.5, "unit": "g", "nutrientId": "Fett" },
            { "sourceId": "10", "nutrientId": "Vit A" }
          ]
        }
      ]
    }
    """

    /// Mirrors real app launch order: NutrientSeeder runs first (see
    /// NutritionTrackerApp.init()), so energy_kcal always exists before any
    /// import runs.
    private func makeSeededContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Food.self, FoodNutrientValue.self, Nutrient.self, FoodGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try NutrientSeeder.seedCoreNutrientsIfNeeded(in: container.mainContext)
        return container
    }

    private func makeImporter(container: ModelContainer) -> MatvaretabellenImporter {
        // The importer only writes FoodGroup/Food/FoodNutrientValue rows (per
        // NUTR-3's scope) — sources.json is descriptive metadata with no
        // corresponding model in the catalog, so it's never fetched here.
        let base = URL(string: "https://www.matvaretabellen.no/api/en/")!
        let transport = FakeMatvaretabellenTransport(dataByURL: [
            base.appendingPathComponent("nutrients.json"): Data(Self.nutrientsFixture.utf8),
            base.appendingPathComponent("food-groups.json"): Data(Self.foodGroupsFixture.utf8),
            base.appendingPathComponent("foods.json"): Data(Self.foodsFixture.utf8),
        ])
        let client = MatvaretabellenClient(
            transport: transport,
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        return MatvaretabellenImporter(modelContainer: container, client: client)
    }

    @Test func importsFoodGroupHierarchy() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()

        let context = container.mainContext
        let groups = try context.fetch(FetchDescriptor<FoodGroup>())
        #expect(groups.count == 2)
        let milk = try #require(groups.first { $0.code == "1.1" })
        #expect(milk.parent?.code == "1")
    }

    @Test func skipsNutrientsWithUnmappableUnits() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()

        let context = container.mainContext
        let nutrients = try context.fetch(FetchDescriptor<Nutrient>())
        #expect(nutrients.contains { $0.code == "Protein" })
        #expect(nutrients.contains { $0.code == "Fett" })
        #expect(!nutrients.contains { $0.code == "Vit A" })
    }

    @Test func marksKnownCoreNutrientsAsCore() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()

        let context = container.mainContext
        let protein = try #require(try context.fetch(FetchDescriptor<Nutrient>()).first { $0.code == "Protein" })
        #expect(protein.isCore)
    }

    @Test func importsFoodWithEnergyFromCaloriesAndConstituentValues() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()

        let context = container.mainContext
        let beans = try #require(try context.fetch(FetchDescriptor<Food>()).first { $0.sourceID == "06.178" })
        #expect(beans.source == .matvaretabellen)
        #expect(beans.foodGroup?.code == "1.1")

        let energy = beans.nutrientValues.first { $0.nutrient?.code == NutrientSeeder.energyNutrientCode }
        #expect(energy?.amount == 310)

        let protein = beans.nutrientValues.first { $0.nutrient?.code == "Protein" }
        #expect(protein?.amount == 19.9)

        // "Vit A" constituent has no quantity (sourceId "10" = missing value) *and*
        // its Nutrient row was skipped entirely (unmappable unit) — either reason
        // alone would exclude it, confirming both skip paths compose correctly.
        #expect(!beans.nutrientValues.contains { $0.nutrient?.code == "Vit A" })
    }

    @Test func mapsDeciliterPortionToDefaultServing() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()

        let context = container.mainContext
        let beans = try #require(try context.fetch(FetchDescriptor<Food>()).first { $0.sourceID == "06.178" })
        #expect(beans.defaultServing == Measure(value: 1, unit: .deciliter))
        #expect(beans.defaultServingLabel == "decilitre")
        #expect(beans.defaultServingWeight == Measure(value: 85.0, unit: .gram))
    }

    @Test func reimportingDoesNotDuplicateAnything() async throws {
        let container = try makeSeededContainer()
        let importer = makeImporter(container: container)

        try await importer.importAll()
        try await importer.importAll()

        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Food>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FoodGroup>()) == 2)
        let beans = try #require(try context.fetch(FetchDescriptor<Food>()).first)
        #expect(beans.nutrientValues.count == 3) // energy_kcal + Protein + Fett (Vit A is skipped)
    }
}
