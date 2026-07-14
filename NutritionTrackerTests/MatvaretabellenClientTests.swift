import Testing
import Foundation
@testable import NutritionTracker

struct MatvaretabellenClientTests {
    /// A minimal but real-shaped foods.json excerpt covering the edge cases
    /// confirmed against the live API: an empty `energy`/`ediblePart` object,
    /// a constituent missing `sourceId`, and an empty `portions` array.
    private static let foodsFixture = """
    {
      "locale": "en",
      "foods": [
        {
          "foodId": "06.178",
          "foodName": "Adzuki beans, uncooked",
          "latinName": "Vigna angularis",
          "uri": "https://www.matvaretabellen.no/en/adzuki-beans-uncooked/",
          "foodGroupId": "12",
          "searchKeywords": ["legumes"],
          "langualCodes": ["N0001"],
          "energy": { "sourceId": "MI0114", "quantity": 1312.4, "unit": "kJ" },
          "calories": { "sourceId": "MI0115", "quantity": 310, "unit": "kcal" },
          "ediblePart": { "percent": 100, "sourceId": "0" },
          "portions": [
            { "portionName": "decilitre", "portionUnit": "dl", "quantity": 85.0, "unit": "g" }
          ],
          "constituents": [
            { "sourceId": "460g", "quantity": 19.9, "unit": "g", "nutrientId": "Protein" },
            { "sourceId": "10", "nutrientId": "Vit E" }
          ]
        },
        {
          "foodId": "99.999",
          "foodName": "Liquid vitamins, Multi Vitaminmikstur, Nycoplus",
          "latinName": null,
          "uri": "https://www.matvaretabellen.no/en/liquid-vitamins/",
          "foodGroupId": "20",
          "searchKeywords": [],
          "langualCodes": [],
          "energy": {},
          "calories": { "sourceId": "10", "quantity": null, "unit": "kcal" },
          "ediblePart": {},
          "portions": [],
          "constituents": []
        }
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

    private static let nutrientsFixture = """
    {
      "locale": "en",
      "nutrients": [
        { "uri": "https://www.matvaretabellen.no/en/fat/", "nutrientId": "Fett", "name": "Fat", "euroFirId": "FAT", "euroFirName": "fat, total", "unit": "g", "decimalPrecision": 1 },
        { "uri": "https://www.matvaretabellen.no/en/saturated-fatty-acids/", "nutrientId": "Mettet", "name": "Saturated fatty acids", "euroFirId": "FASAT", "euroFirName": "fatty acids, total saturated", "unit": "g", "decimalPrecision": 1, "parentId": "Fett" }
      ]
    }
    """

    private static let sourcesFixture = """
    {
      "locale": "en",
      "sources": [
        { "sourceId": "0", "description": "Estimated as 100 % edible (net weight)." },
        { "sourceId": "10", "description": "Missing value, content not known." }
      ]
    }
    """

    private func makeClient(
        transport: FakeMatvaretabellenTransport,
        cacheDirectory: URL
    ) -> MatvaretabellenClient {
        MatvaretabellenClient(transport: transport, cacheDirectory: cacheDirectory)
    }

    private func withTempCacheDirectory(_ body: (URL) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try await body(tempDir)
    }

    @Test func decodesFoodsIncludingEmptyEnergyAndMissingSourceId() async throws {
        try await withTempCacheDirectory { tempDir in
            let url = URL(string: "https://www.matvaretabellen.no/api/en/foods.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [url: Data(Self.foodsFixture.utf8)])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            let response = try await client.fetchFoods(locale: .english)

            #expect(response.foods.count == 2)

            let beans = try #require(response.foods.first { $0.foodId == "06.178" })
            #expect(beans.energy.quantity == 1312.4)
            #expect(beans.constituents.first { $0.nutrientId == "Vit E" }?.sourceId == "10")
            #expect(beans.constituents.first { $0.nutrientId == "Vit E" }?.quantity == nil)

            let vitamins = try #require(response.foods.first { $0.foodId == "99.999" })
            #expect(vitamins.energy.quantity == nil)
            #expect(vitamins.ediblePart.percent == nil)
            #expect(vitamins.latinName == nil)
            #expect(vitamins.portions.isEmpty)
        }
    }

    @Test func decodesFoodGroupsWithParentHierarchy() async throws {
        try await withTempCacheDirectory { tempDir in
            let url = URL(string: "https://www.matvaretabellen.no/api/en/food-groups.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [url: Data(Self.foodGroupsFixture.utf8)])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            let response = try await client.fetchFoodGroups(locale: .english)

            #expect(response.foodGroups.count == 2)
            #expect(response.foodGroups.first { $0.foodGroupId == "1.1" }?.parentId == "1")
            #expect(response.foodGroups.first { $0.foodGroupId == "1" }?.parentId == nil)
        }
    }

    @Test func decodesNutrientsWithEuroFirClassification() async throws {
        try await withTempCacheDirectory { tempDir in
            let url = URL(string: "https://www.matvaretabellen.no/api/en/nutrients.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [url: Data(Self.nutrientsFixture.utf8)])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            let response = try await client.fetchNutrients(locale: .english)

            #expect(response.nutrients.count == 2)
            #expect(response.nutrients.first { $0.nutrientId == "Mettet" }?.parentId == "Fett")
        }
    }

    @Test func decodesSources() async throws {
        try await withTempCacheDirectory { tempDir in
            let url = URL(string: "https://www.matvaretabellen.no/api/en/sources.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [url: Data(Self.sourcesFixture.utf8)])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            let response = try await client.fetchSources(locale: .english)

            #expect(response.sources.count == 2)
            #expect(response.sources.first { $0.sourceId == "10" }?.description == "Missing value, content not known.")
        }
    }

    @Test func secondFetchUsesCacheInsteadOfRefetching() async throws {
        try await withTempCacheDirectory { tempDir in
            let url = URL(string: "https://www.matvaretabellen.no/api/en/nutrients.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [url: Data(Self.nutrientsFixture.utf8)])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            _ = try await client.fetchNutrients(locale: .english)
            _ = try await client.fetchNutrients(locale: .english)

            #expect(await transport.fetchCount == 1)
        }
    }

    @Test func differentLocalesAndEndpointsCacheSeparately() async throws {
        try await withTempCacheDirectory { tempDir in
            let enURL = URL(string: "https://www.matvaretabellen.no/api/en/nutrients.json")!
            let nbURL = URL(string: "https://www.matvaretabellen.no/api/nb/nutrients.json")!
            let transport = FakeMatvaretabellenTransport(dataByURL: [
                enURL: Data(Self.nutrientsFixture.utf8),
                nbURL: Data(Self.nutrientsFixture.utf8),
            ])
            let client = makeClient(transport: transport, cacheDirectory: tempDir)

            _ = try await client.fetchNutrients(locale: .english)
            _ = try await client.fetchNutrients(locale: .norwegianBokmal)

            #expect(await transport.fetchCount == 2)
        }
    }
}
