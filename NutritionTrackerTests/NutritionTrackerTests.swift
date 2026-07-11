import Testing
import SwiftData
@testable import NutritionTracker

struct NutritionTrackerTests {
    @Test func measureBaseValueConvertsWithinDimension() {
        let twoDeciliters = Measure(value: 2, unit: .deciliter)
        #expect(twoDeciliters.baseValue == 200)
    }

    @Test func foodSearchIndexIncludesBrandAndAliases() {
        let food = Food(
            name: "Freia Melkesjokolade",
            brand: "Freia",
            commonName: "sjokolade",
            searchAliases: ["melkesjokolade"],
            source: .userEntered
        )
        #expect(food.searchIndex.contains("freia"))
        #expect(food.searchIndex.contains("melkesjokolade"))
    }
}
