import Foundation
import SwiftData

@Model
final class Food {
    @Attribute(.unique) var id: UUID
    var name: String                        // as shown to the user, e.g. "Freia Melkesjokolade"
    var brand: String?

    /// Generic/category term people actually search for, e.g. "melkesjokolade"
    /// for "Freia Melkesjokolade", or "kjøttdeig" for a product branded
    /// "Vegansk Gehakt" whose name gives no hint what it's a substitute for.
    var commonName: String?

    /// Additional search synonyms beyond commonName — a product can reasonably
    /// match more than one generic term (e.g. a vegan mince product matching
    /// "kjøttdeig", "farse", and "gehakt" all at once).
    var searchAliases: [String] = []

    /// Denormalized, lowercased/folded blob of name + brand + commonName +
    /// searchAliases, rebuilt on save. Lets search run as a single `CONTAINS`
    /// predicate instead of OR-ing across every field. If the catalog grows
    /// large enough that this stops being fast, swap in SQLite FTS5.
    var searchIndex: String = ""

    var ean: String?                        // barcode, for branded products (not guaranteed unique across sources)
    var source: FoodSource
    var sourceID: String?                   // ID in the source system, to re-sync/refresh later

    /// True when nutrient values are a best-effort guess (e.g. LLM-estimated
    /// for a homemade dish with no label) rather than typed in from a real
    /// source — a real package label, or a source API. Surface this in the UI
    /// (e.g. a badge) so the user knows to sanity-check it. Always false for
    /// `.kassalapp`/`.openFoodFacts`/`.matvaretabellen` sources.
    var isEstimated: Bool = false

    var foodGroup: FoodGroup?

    /// What the `nutrientValues` amounts are "per" — typically 100 g, but
    /// liquids (e.g. milk, juice) are commonly reported per 100 ml instead.
    var nutrientReferenceAmount: Measure = Measure(value: 100, unit: .gram)

    var defaultServing: Measure?            // e.g. Measure(value: 1, unit: .piece)
    var defaultServingLabel: String?        // e.g. "1 medium banana"
    var defaultServingWeight: Measure?      // resolved weight of one defaultServing, e.g. 118 g

    /// Best-effort density for converting recipe volumes to grams (e.g. "2 dl
    /// flour"). Optional and approximate — see Key design decisions.
    var densityGPerMl: Double?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \FoodNutrientValue.food)
    var nutrientValues: [FoodNutrientValue] = []

    init(id: UUID = UUID(), name: String, brand: String? = nil, commonName: String? = nil,
         searchAliases: [String] = [], ean: String? = nil,
         source: FoodSource, sourceID: String? = nil, isEstimated: Bool = false,
         foodGroup: FoodGroup? = nil,
         nutrientReferenceAmount: Measure = Measure(value: 100, unit: .gram),
         defaultServing: Measure? = nil, defaultServingLabel: String? = nil,
         defaultServingWeight: Measure? = nil, densityGPerMl: Double? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.commonName = commonName
        self.searchAliases = searchAliases
        self.ean = ean
        self.source = source
        self.sourceID = sourceID
        self.isEstimated = isEstimated
        self.foodGroup = foodGroup
        self.nutrientReferenceAmount = nutrientReferenceAmount
        self.defaultServing = defaultServing
        self.defaultServingLabel = defaultServingLabel
        self.defaultServingWeight = defaultServingWeight
        self.densityGPerMl = densityGPerMl
        self.updateSearchIndex()
    }

    /// Call after any change to name/brand/commonName/searchAliases.
    func updateSearchIndex() {
        let parts = [name, brand, commonName].compactMap { $0 } + searchAliases
        searchIndex = parts.joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
