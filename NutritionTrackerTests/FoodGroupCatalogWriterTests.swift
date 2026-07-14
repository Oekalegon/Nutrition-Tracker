import Testing
import SwiftData
@testable import NutritionTracker

@MainActor
struct FoodGroupCatalogWriterTests {
    @Test func createsNewFoodGroup() throws {
        let container = try ModelContainer(for: FoodGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let group = try FoodGroupCatalogWriter.createOrUpdate(code: "1", name: "Dairy products", in: context)

        #expect(group.code == "1")
        #expect(try context.fetchCount(FetchDescriptor<FoodGroup>()) == 1)
    }

    @Test func updatesExistingGroupInsteadOfDuplicating() throws {
        let container = try ModelContainer(for: FoodGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        try FoodGroupCatalogWriter.createOrUpdate(code: "1", name: "Dairy", in: context)
        try FoodGroupCatalogWriter.createOrUpdate(code: "1", name: "Dairy products", in: context)

        let all = try context.fetch(FetchDescriptor<FoodGroup>())
        #expect(all.count == 1)
        #expect(all[0].name == "Dairy products")
    }

    @Test func doesNotSetParentItself() throws {
        // Hierarchy wiring is the caller's responsibility (a group's parent can
        // be referenced before it exists in the source dump) — this writer only
        // ever upserts the group itself.
        let container = try ModelContainer(for: FoodGroup.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let group = try FoodGroupCatalogWriter.createOrUpdate(code: "1.1", name: "Milk", in: context)

        #expect(group.parent == nil)
    }
}
