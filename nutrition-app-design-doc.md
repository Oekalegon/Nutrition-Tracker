# Nutrition Tracking App — Design Doc (Working Draft)

*Last updated: 2026-07-11*

## Problem

Existing calorie-counting apps are cumbersome: manual search through poor food
databases, tedious logging of every item, no real handling of recipes, and no
memory of what you actually eat regularly.

## Core Idea

Use an LLM as the input layer. The user types (or pastes) natural input —
`"one banana"`, a recipe, a link to a recipe — and the app resolves it to
structured nutrition data automatically. Over time it learns recurring
meals and offers one-tap logging.

The LLM's job is **parsing and orchestration, not being the nutrition
database**. It should never recall calorie figures from its own training —
it calls out to real data sources and grounds its answer in what comes back.

## Data Sources

| Source | Use for | Notes |
|---|---|---|
| [Kassalapp API](https://kassal.app/api) | Norwegian branded groceries, incl. Oda | Free "Hobby" tier: 60 req/min, non-commercial only. Commercial tier 750 kr/mo, no rate limit. Lookup by EAN/barcode or product URL. Returns name, brand, ingredients, allergens, and structured `nutrition` array (kcal, kJ, protein, fat, carbs, per 100g). |
| [Open Food Facts](https://openfoodfacts.github.io/openfoodfacts-server/api/) | Fallback for products Kassalapp doesn't cover | Open license (ODbL), free, no usage restrictions. Barcode-based. Global coverage but thinner for small Norwegian products. |
| [Matvaretabellen API](https://www.matvaretabellen.no/en/api/) | Generic/unbranded items ("a banana", "a slice of bread") | The Norwegian Food Composition Table, run by Mattilsynet (Norwegian Food Safety Authority) with EuroFIR-classified nutrients. Free, no auth, no rate limit, full JSON dump (foods, food groups, nutrients, sources). ~2,100 generic food items with detailed nutrient profiles. Updated annually; safe to cache locally. Just requires citing them as the source. EU/EEA-based and matches Oda's Norwegian market well. |
| Oda.com directly | ❌ Not usable | Terms of service explicitly prohibit downloading/copying/reusing product info, images, or recipes without written permission. robots.txt only governs crawler etiquette, doesn't grant reuse rights. |

**Note:** for recipes specifically, there is no legitimate free source that overlaps
with Oda's own recipe content (also blocked by their ToS). Recipe *links* from
elsewhere on the web are fine to parse if the site allows fetching — see below.

**Watch for:** EFSA/EuroFIR are building an open-access, pan-EU Food Composition
Database (harmonised across ~14 EU countries via FoodEx2), expected to publish
mid-2026. Worth checking status later if broader EU coverage (beyond Norway)
becomes relevant — [EuroFIR](https://www.eurofir.org/), [EFSA food composition](https://www.efsa.europa.eu/en/data-report/food-composition).

## Input Handling

### 1. Free text ("one banana", "200g chicken breast", "a bowl of oatmeal with milk")

- LLM extracts (food, quantity, unit) tuples.
- Quantity resolution:
  - If quantity is already a weight/volume → use directly.
  - If quantity is a count ("one banana", "a slice") → look up a reference
    weight (Matvaretabellen doesn't always give per-unit weights, so this
    likely needs a small internal table for common items) and convert to
    grams. **Show the assumed weight in the UI** so the user can correct it
    inline rather than blocking on a clarifying question every time.
- Resolve each food item via tool calls: local catalog first, then Kassalapp
  (branded/Norwegian) → Open Food Facts (barcode fallback) → Matvaretabellen
  (generic) → if nothing matches anywhere, fall back to `create_user_food`
  (ask the user for the values, or offer an LLM estimate flagged
  `isEstimated: true` for them to confirm/correct). See LLM Tool Interface.

### 2. Recipe (pasted text)

- Parse each ingredient line into (food, quantity, unit).
- Resolve each via the same pipeline as above.
- Sum totals, divide by stated servings.
- Vague quantities ("a pinch", "to taste") → treat as negligible, don't block.

### 3. Recipe link

- Fetch the page and check for `schema.org/Recipe` JSON-LD first — most
  recipe sites (including Oda's own recipe pages) embed this. Far more
  reliable than parsing prose.
- Only fall back to LLM prose-parsing when structured data is missing.
- Same summing/serving-division logic as pasted recipes.

## Recurring Meals

This is **not** primarily an LLM problem — once entries are logged as
structured data (food IDs + quantities + timestamp), detecting patterns
("same combo most weekday mornings") is a deterministic frequency/clustering
problem, cheap to run on the backend.

The LLM's role is just the conversational surface: *"Log your usual
breakfast?"* — natural-language framing of a pattern that was detected by
plain logic, not inference.

## Data Model (SwiftData)

Four layers: reference/catalog data (Food, Nutrient), reusable compositions
(Meal, Recipe), and the diary (what was actually eaten, when). Kept as
separate `@Model` classes rather than a shared base type — SwiftData doesn't
support protocols holding `@Relationship`/`@Attribute`, and Meal vs. Recipe
genuinely diverge (servings, instructions, source link).

### Units & measures

Every quantity in the app (nutrient amounts, ingredient quantities, serving
sizes) is a **value + unit** pair, not a bare `Double`. `Measure` is a plain
`Codable` struct — SwiftData can store `Codable` structs directly as an
attribute, so this doesn't need to be its own `@Model`/relationship.

```swift
enum UnitDimension: String, Codable {
    case mass
    case volume
    case energy
    case count      // "1 piece", "1 banana", "1 slice"
}

enum MeasurementUnit: String, Codable, CaseIterable {
    // Mass
    case microgram, milligram, gram, kilogram
    // Volume — ml/cl/dl/l plus tsp/tbsp, the units Nordic recipes actually use
    case milliliter, centiliter, deciliter, liter, teaspoon, tablespoon
    // Energy
    case kilocalorie, kilojoule
    // Count
    case piece

    var dimension: UnitDimension {
        switch self {
        case .microgram, .milligram, .gram, .kilogram:
            return .mass
        case .milliliter, .centiliter, .deciliter, .liter, .teaspoon, .tablespoon:
            return .volume
        case .kilocalorie, .kilojoule:
            return .energy
        case .piece:
            return .count
        }
    }

    /// Factor to this dimension's base unit: gram (mass), milliliter (volume),
    /// kilocalorie (energy), or 1 (count).
    var baseUnitFactor: Double {
        switch self {
        case .microgram: return 0.000_001
        case .milligram: return 0.001
        case .gram: return 1
        case .kilogram: return 1_000
        case .milliliter: return 1
        case .centiliter: return 10
        case .deciliter: return 100
        case .liter: return 1_000
        case .teaspoon: return 5      // ~5 ml
        case .tablespoon: return 15   // ~15 ml
        case .kilocalorie: return 1
        case .kilojoule: return 0.239_006   // 1 kJ ≈ 0.239 kcal
        case .piece: return 1
        }
    }

    var symbol: String {
        switch self {
        case .microgram: return "µg"
        case .milligram: return "mg"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .milliliter: return "ml"
        case .centiliter: return "cl"
        case .deciliter: return "dl"
        case .liter: return "l"
        case .teaspoon: return "ts"     // Norwegian teskje
        case .tablespoon: return "ss"   // Norwegian spiseskje
        case .kilocalorie: return "kcal"
        case .kilojoule: return "kJ"
        case .piece: return "stk"
        }
    }
}

struct Measure: Codable, Hashable {
    var value: Double
    var unit: MeasurementUnit

    /// Value expressed in the dimension's base unit (g / ml / kcal / count).
    var baseValue: Double { value * unit.baseUnitFactor }
}
```

Volume ↔ mass conversion (e.g. "2 dl flour" → grams) needs food-specific
density, which isn't a unit-system problem — see `Food.densityGPerMl` below
and the caveat in Key design decisions.

### Reference / catalog

```swift
import Foundation
import SwiftData

enum FoodSource: String, Codable {
    case kassalapp
    case openFoodFacts
    case matvaretabellen
    case userEntered
}

@Model
final class FoodGroup {
    @Attribute(.unique) var code: String   // Matvaretabellen food-group code
    var name: String
    var parent: FoodGroup?

    @Relationship(inverse: \FoodGroup.parent)
    var children: [FoodGroup] = []

    init(code: String, name: String, parent: FoodGroup? = nil) {
        self.code = code
        self.name = name
        self.parent = parent
    }
}

@Model
final class Nutrient {
    @Attribute(.unique) var code: String     // matches source API codes, e.g. "energi_kcal", "protein"
    var displayName: String
    var unit: MeasurementUnit                 // .kilocalorie, .gram, .milligram, .microgram, etc.
    var isCore: Bool                          // kcal/protein/fat/carbs shown prominently in UI

    init(code: String, displayName: String, unit: MeasurementUnit, isCore: Bool = false) {
        self.code = code
        self.displayName = displayName
        self.unit = unit
        self.isCore = isCore
    }
}

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

@Model
final class FoodNutrientValue {
    var amount: Double        // in `nutrient.unit`, per `food.nutrientReferenceAmount`
    var food: Food?
    var nutrient: Nutrient?

    init(amount: Double, food: Food? = nil, nutrient: Nutrient? = nil) {
        self.amount = amount
        self.food = food
        self.nutrient = nutrient
    }
}
```

### Reusable compositions — Meal & Recipe

```swift
@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var name: String                  // "Cruesli with yoghurt"
    var notes: String?
    var isFavorite: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \MealIngredient.meal)
    var ingredients: [MealIngredient] = []

    init(id: UUID = UUID(), name: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

@Model
final class MealIngredient {
    var quantity: Measure             // already portion-sized, as eaten — e.g. Measure(150, .gram)
    var food: Food?
    var meal: Meal?

    init(quantity: Measure, food: Food? = nil, meal: Meal? = nil) {
        self.quantity = quantity
        self.food = food
        self.meal = meal
    }
}

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var servings: Double              // Double, not Int — "makes 6 bowls" or "2.5 L soup" style yields
    var sourceURL: URL?                // kept — useful for re-parsing/refreshing, and for attribution
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(id: UUID = UUID(), name: String, servings: Double, sourceURL: URL? = nil) {
        self.id = id
        self.name = name
        self.servings = servings
        self.sourceURL = sourceURL
    }
}

@Model
final class RecipeIngredient {
    var quantity: Measure             // total for the whole recipe, not per serving — divide by Recipe.servings.
                                       // As entered, e.g. Measure(2, .deciliter) for "2 dl flour" — not pre-converted.
    var rawQuantityText: String?      // original text before parsing, e.g. "2 dl flour" — kept for audit/re-parse
    var food: Food?
    var recipe: Recipe?

    init(quantity: Measure, rawQuantityText: String? = nil, food: Food? = nil, recipe: Recipe? = nil) {
        self.quantity = quantity
        self.rawQuantityText = rawQuantityText
        self.food = food
        self.recipe = recipe
    }
}
```

### Diary — what was actually eaten, and when

A `DiaryEntry` is one logging "occasion" (e.g. one input of "cruesli with
yoghurt" at 8am), made up of one or more `DiaryItem`s. This lets the user log
ad-hoc combos *before* they're ever formalized as a saved `Meal` — recurring-pattern
detection runs over `DiaryEntry`/`DiaryItem` regardless of whether a `Meal` exists
yet, and once a pattern is confirmed you can materialize it into a `Meal` and
link future entries to it via `.meal`.

```swift
enum MealSlot: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack
}

enum DiarySourceType: String, Codable {
    case freeEntry   // ad-hoc item(s), not tied to a saved Meal/Recipe
    case meal
    case recipe
}

@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var mealSlot: MealSlot?
    var sourceType: DiarySourceType
    var label: String?                // display label — inferred from items, or the Meal/Recipe name

    var meal: Meal?                   // set if sourceType == .meal
    var recipe: Recipe?               // set if sourceType == .recipe
    var recipeServingsEaten: Double?  // e.g. 1.5 — only used with .recipe

    var rawInputText: String?         // original free text / link the user entered, for debugging & re-parsing
    var createdAt: Date = Date.now

    /// Nutrient.code -> HKSample.uuid for samples written to HealthKit for
    /// this entry (only if Health export is enabled). Lets edits/deletes
    /// update or remove the matching sample instead of orphaning it — see
    /// Apple Health Integration.
    var healthKitSampleIDs: [String: UUID] = [:]

    @Relationship(deleteRule: .cascade, inverse: \DiaryItem.entry)
    var items: [DiaryItem] = []

    init(id: UUID = UUID(), timestamp: Date, mealSlot: MealSlot? = nil,
         sourceType: DiarySourceType, label: String? = nil, rawInputText: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.mealSlot = mealSlot
        self.sourceType = sourceType
        self.label = label
        self.rawInputText = rawInputText
    }
}

@Model
final class DiaryItem {
    var quantity: Measure       // as logged, e.g. Measure(1, .piece) or Measure(150, .gram)
    var food: Food?
    var entry: DiaryEntry?

    @Relationship(deleteRule: .cascade, inverse: \DiaryItemNutrientValue.item)
    var nutrientSnapshot: [DiaryItemNutrientValue] = []

    init(quantity: Measure, food: Food? = nil, entry: DiaryEntry? = nil) {
        self.quantity = quantity
        self.food = food
        self.entry = entry
    }
}

@Model
final class DiaryItemNutrientValue {
    var nutrientCode: String        // denormalized (not a relationship) — survives Nutrient catalog edits
    var quantity: Measure
    var item: DiaryItem?

    init(nutrientCode: String, quantity: Measure, item: DiaryItem? = nil) {
        self.nutrientCode = nutrientCode
        self.quantity = quantity
        self.item = item
    }
}
```

### Key design decisions

- **Snapshot nutrients at logging time** (`DiaryItemNutrientValue`), don't
  just compute live from `Food.nutrientValues`. Source data gets refreshed
  periodically (product reformulations, database corrections) — a log entry
  from three months ago shouldn't silently change its calorie count because
  the upstream data changed today. Live computation is fine for "what would
  this be if I logged it now," snapshot is the source of truth for history.
- **DiaryEntry/DiaryItem split** exists specifically to support "what food
  types are eaten and when": query `DiaryItem.food.foodGroup` joined through
  `DiaryEntry.timestamp` to answer things like "you eat dairy almost every
  morning" without needing a saved `Meal` to exist first.
- **Meal vs. Recipe stay separate models.** `MealIngredient.quantity` is
  already portion-sized (as eaten); `RecipeIngredient.quantity` is for
  the whole batch and gets divided by `Recipe.servings`. Conflating them would
  mean constantly branching on which meaning a quantity has.
- **`Measure` (value + `MeasurementUnit`) everywhere, not bare `Double`s in
  implicit grams.** Covers mass (µg/mg/g/kg), the volume units Nordic recipes
  actually write ("2 dl", "1 ss"), and the nutrient-label units (kcal, kJ),
  plus `.piece` for count-based logging ("1 banana"). Converting *within* a
  dimension (mg→g, dl→ml) is exact via `baseUnitFactor`. Converting *across*
  dimensions — volume to mass, e.g. "2 dl flour" → grams — needs food-specific
  density, which is inherently approximate; `Food.densityGPerMl` is optional
  and best-effort, with a small internal lookup table for common ingredients
  (flour, sugar, milk, oil) as fallback when a food's own density is unknown.
  When neither is available, fall back to asking the user or showing the
  quantity unconverted rather than guessing silently.
- **`commonName`/`searchAliases` exist because brand names lie about content.**
  "Freia Melkesjokolade" should match a search for "melkesjokolade"; a product
  branded "Vegansk Gehakt" should also match "kjøttdeig" and "farse" even
  though none of those words appear in its name. When a new product is
  resolved via Kassalapp/Open Food Facts/Matvaretabellen, have the LLM
  propose `commonName` + `searchAliases` at that point (it's already looking
  at the product to ground nutrition data — inferring "this is a chocolate
  bar" or "this is a meat substitute" is a cheap add-on to that same call),
  and let the user edit them.
- **`Food.ean` is not marked unique** — not every source guarantees a barcode,
  and the same EAN could theoretically appear from two sources during a
  transition period. Dedup logic (source + sourceID, or ean when present)
  belongs in the sync layer, not as a hard DB constraint.
- **Recurring-meal detection** runs as a periodic pass over `DiaryEntry`:
  group by (linked `Meal.id`, or a signature of food IDs + rounded quantities
  for `.freeEntry` occasions) bucketed by day-of-week and time-of-day window;
  surface a suggestion once a combo crosses a frequency threshold (e.g. ≥3
  times in 2 weeks at a similar time). Plain aggregation query, no LLM call.
- **Not modeled yet, intentionally:** multi-user/profile support (add an
  `owner` relationship on `DiaryEntry` if/when needed), and CloudKit sync
  (SwiftData supports it, but requires all relationships optional and every
  property to have a default — already true above, so it's a low-cost
  addition later, not a redesign).
- Wrap this in a versioned `Schema`/`SchemaMigrationPlan` from the start —
  the model will evolve and lightweight migration is much cheaper to set up
  early than to retrofit.

## LLM Tool Interface

The LLM never touches SwiftData or the network directly — it's given a fixed
set of tools (function-calling / tool-use), and the app executes each call
against `ModelContext` or the relevant HTTP API, feeding the result back.
This is the mechanism behind "the LLM's job is parsing and orchestration, not
being the nutrition database" from earlier in this doc.

### Local tools — read (SwiftData)

| Tool | Params | Returns | Purpose |
|---|---|---|---|
| `search_local_foods` | `query`, `limit` | `[FoodSummary]` (id, name, brand, commonName, kcal per default serving) | Checked **before** any external API — avoids duplicate `Food` rows, re-uses user-edited `commonName`/`searchAliases`, costs nothing. |
| `get_food_details` | `foodID` | Full nutrient breakdown | Only called once a specific food is selected — keeps search results cheap. |
| `search_meals` / `search_recipes` | `query` | `[MealSummary]` / `[RecipeSummary]` | "Log the usual sandwich" / recipe reuse. |
| `get_recent_diary_entries` | `since`, `limit` | `[DiaryEntrySummary]` | Powers "what did I eat yesterday" and gives the model context on recent logging. |
| `get_recurring_meal_suggestions` | `around`, `mealSlot?` | `[MealSummary]` | Reads output of the deterministic frequency job (see Recurring Meals) — the LLM phrases the suggestion, it doesn't compute the pattern. |

### Local tools — write (SwiftData)

| Tool | Params | Returns | Purpose |
|---|---|---|---|
| `create_or_update_food` | source, sourceID/ean, name, nutrients, etc. | `FoodSummary` | **Single chokepoint** for new `Food` rows sourced from an external API. Owns dedup (by ean/sourceID first, `searchIndex` overlap as fallback) and sets `searchIndex`/timestamps — the LLM supplies data, this function is the only thing that persists it. |
| `create_user_food` | name, commonName?, core nutrients (`[Nutrient.code: Measure]`), servingLabel?, servingWeight?, isEstimated | `FoodSummary` | For foods absent from every source — homemade dishes, small/local brands. Separate from `create_or_update_food` because provenance differs: `source = .userEntered`, no `sourceID` to dedup or re-sync against, and it only requires the **core** nutrients (`Nutrient.isCore`), not a full micronutrient panel, since no one is typing 40 values by hand. See Key design decisions. |
| `create_diary_entry` | timestamp, mealSlot?, items: `[(foodID, quantity: Measure)]`, rawInputText | `DiaryEntrySummary` | Logs what was eaten. **Nutrient snapshot is computed here, app-side, from current `Food` data — not supplied by the LLM.** |
| `save_meal` | name, items: `[(foodID, quantity: Measure)]` | `MealSummary` | Materializes a combo into a reusable `Meal`, e.g. after a recurring pattern is confirmed. |
| `save_recipe` | name, servings, sourceURL?, items | `RecipeSummary` | Same, for `Recipe`. |

### External tools (network)

| Tool | Params | Wraps |
|---|---|---|
| `search_kassalapp` | `query` or `ean` | [Kassalapp API](https://kassal.app/api) — Norwegian branded groceries incl. Oda |
| `lookup_kassalapp_by_url` | `url` | Kassalapp's `find-by-url` endpoint — for pasted product/recipe links |
| `search_open_food_facts` | `ean` | Open Food Facts fallback |
| `search_matvaretabellen` | `query` | Matvaretabellen generic foods |
| `fetch_recipe_page` | `url` | Fetches a recipe link, extracts `schema.org/Recipe` JSON-LD first, falls back to prose parsing |

### Design principles

- **Local-first resolution order.** Every food lookup tries
  `search_local_foods` before any external tool. Cheaper, works offline for
  previously-seen items, respects Kassalapp's free-tier rate limit, and keeps
  the user's own edits (corrected `commonName`, fixed portion sizes)
  authoritative over re-fetching fresh data from the source.
- **One write path per entity type.** The LLM can't freely mutate the store —
  `create_or_update_food` (sourced data) and `create_user_food` (no source
  found) are the only two functions that ever create a `Food` row, so dedup
  and validation logic live in exactly two well-defined places instead of
  being re-implemented (or forgotten) at every call site.
- **User-entered foods carry their own trust signal.** `source = .userEntered`
  already tells the UI "this wasn't verified against Kassalapp/Open Food
  Facts/Matvaretabellen." `isEstimated` goes one step further: false means the
  user (or the LLM on their behalf) typed in real numbers from a package
  label or known recipe math; true means the LLM guessed at typical values
  for something like a homemade dish with no label, and it should be shown
  as a rough estimate the user can correct rather than presented as fact.
  Since `.userEntered` foods have no `sourceID`, there's nothing to refresh
  them against later — they're the user's own permanent record until they
  edit it themselves.
- **Snapshotting happens in app code, not by the LLM.** `create_diary_entry`
  takes `(foodID, quantity)` pairs; the app reads `Food.nutrientValues` at
  that moment and writes `DiaryItemNutrientValue` itself. The LLM never
  computes or states a calorie number — it only ever passes through IDs and
  quantities it got from a tool result.
- **Read tools return summaries, not full graphs.** Search results carry just
  enough to disambiguate (name, brand, kcal); a separate "get details" call
  fetches the full nutrient breakdown only for the item actually chosen. Keeps
  per-turn context small, which matters since this loop runs on every log
  entry (ties into the small-model-by-default strategy below).
- **This is standard tool-use, not a custom protocol.** Each row above is a
  tool/function definition (name + JSON-schema params + description) passed
  to the model; the app runs the normal agentic loop — call the model, execute
  whichever tool it requests, feed the result back, repeat until it has enough
  to respond or log the entry.

## Model / Cost Strategy

- Use a small, fast model for the structured extraction step (text → food +
  quantity list) on every log entry.
- Escalate to a larger model only when there's real ambiguity to resolve
  conversationally (e.g. multiple plausible matches, unclear recipe
  structure).

### Model routing: on-device vs. cloud

**Default decision: Health/weight data never reaches an LLM at all, on-device
or cloud** — see Targets & Goals and Privacy below. The daily-target-from-
weight-goal calculation is plain deterministic arithmetic, not something that
benefits from a model in the loop, so there's no Health-adjacent LLM task to
route in the first place. This sidesteps the on-device/cloud question for
that feature entirely rather than solving it with routing.

Worth keeping in mind anyway, in case a future feature genuinely needs
conversational reasoning over Health-adjacent data: Apple's [Foundation
Models framework](https://developer.apple.com/documentation/foundationmodels)
(iOS 26+) runs a local ~3B-parameter model fully on-device — no network
call, no API key, nothing leaves the phone — and as of WWDC 2026 the same
framework supports pluggable providers, including Claude, behind one Swift
API. If that need arises, the pattern would be: on-device model for the
Health-touching task, cloud model for everything else, through a single
integration. Not needed today.

## Targets & Goals

Two different kinds of goal, modeled separately because they behave
differently over time: a **daily nutrition target** (a number to hit today)
and a **weight goal** (a single target reached over weeks/months).

```swift
enum TargetSource: String, Codable {
    case userSet
    case derivedFromWeightGoal   // suggested by the weight-goal calculator, then accepted by the user
}

@Model
final class NutritionTarget {
    @Attribute(.unique) var id: UUID
    var nutrientCode: String        // "energi_kcal", "protein", etc.
    var dailyAmount: Measure
    var effectiveFrom: Date
    var effectiveTo: Date?          // nil = currently active
    var source: TargetSource
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), nutrientCode: String, dailyAmount: Measure,
         effectiveFrom: Date, effectiveTo: Date? = nil, source: TargetSource) {
        self.id = id
        self.nutrientCode = nutrientCode
        self.dailyAmount = dailyAmount
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.source = source
    }
}

@Model
final class WeightGoal {
    @Attribute(.unique) var id: UUID
    var targetWeight: Measure       // e.g. Measure(72, .kilogram)
    var targetDate: Date            // e.g. Dec 31
    var startWeight: Measure?
    var startDate: Date
    var isActive: Bool = true
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), targetWeight: Measure, targetDate: Date,
         startWeight: Measure? = nil, startDate: Date = .now) {
        self.id = id
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.startWeight = startWeight
        self.startDate = startDate
    }
}

enum WeightSource: String, Codable {
    case healthKit
    case userEntered
}

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Measure
    var source: WeightSource
    var healthKitSampleID: UUID?    // for de-duping re-imports

    init(id: UUID = UUID(), date: Date, weight: Measure, source: WeightSource,
         healthKitSampleID: UUID? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.source = source
        self.healthKitSampleID = healthKitSampleID
    }
}
```

- **`NutritionTarget` keeps history instead of being edited in place**
  (`effectiveFrom`/`effectiveTo`). Same reasoning as the diary nutrient
  snapshot: if the user tightens their calorie target next month, last
  month's heatmap shouldn't silently repaint against the new number.
- **A `WeightGoal` ("72kg before New Year") suggests a daily calorie target
  through a plain deterministic calculator** — weight delta and days
  remaining in, a kcal/day number out (roughly ~7,700 kcal per kg), pure
  arithmetic, no LLM involved at any point. This is a *suggestion* shown to
  the user, not auto-applied — accepting it creates a normal
  `NutritionTarget` row with `source = .derivedFromWeightGoal`, so day-to-day
  evaluation never has to re-run the derivation. Because this calculator is
  the only thing that needs the weight goal + weight history, the LLM never
  needs to see either — see Privacy below.
- **`WeightEntry.source` mirrors `FoodSource`'s pattern** (`.healthKit` vs.
  `.userEntered`) for the same reason: the UI can distinguish an imported
  measurement from a manually typed one, and `healthKitSampleID` prevents
  double-importing the same sample.

## Statistics & Visualization

Charting reads from a **daily rollup**, not a live scan of every
`DiaryItemNutrientValue` — a year-view heatmap over raw diary data would mean
summing thousands of rows on every render. The rollup is recomputed
incrementally (just that day) whenever a `DiaryEntry` is added, edited, or
removed for that date.

```swift
enum TargetStatus: String, Codable {
    case noTarget
    case belowTarget
    case onTarget    // within a tolerance band around the active target, e.g. ±5%
    case aboveTarget
}

@Model
final class DailySummary {
    @Attribute(.unique) var date: Date   // normalized to start of day

    @Relationship(deleteRule: .cascade, inverse: \DailyNutrientTotal.summary)
    var nutrientTotals: [DailyNutrientTotal] = []

    var updatedAt: Date = Date.now

    init(date: Date) {
        self.date = date
    }
}

@Model
final class DailyNutrientTotal {
    var nutrientCode: String
    var total: Measure
    var targetStatus: TargetStatus   // computed against the target active *that day* — frozen, doesn't
                                      // repaint if the target changes later (same principle as NutritionTarget)
    var summary: DailySummary?

    init(nutrientCode: String, total: Measure, targetStatus: TargetStatus, summary: DailySummary? = nil) {
        self.nutrientCode = nutrientCode
        self.total = total
        self.targetStatus = targetStatus
        self.summary = summary
    }
}
```

- **Line/bar charts** (intake over day/week/month/year, per nutrient) render
  straight from `DailySummary`/`DailyNutrientTotal` using
  [Swift Charts](https://developer.apple.com/documentation/charts) — the
  native fit given this is already a SwiftUI/SwiftData app.
- **GitHub-style heatmap** is a calendar grid colored by
  `DailyNutrientTotal.targetStatus` for whichever nutrient the user is
  viewing (typically calories) — directly reads the rollup, no separate
  computation needed.

## Apple Health Integration

### Import (weight)

`WeightEntry` rows sourced from HealthKit's `.bodyMass` type, via
`HKObserverQuery` + anchored fetch (only new samples, not a full history
re-scan each time).

### Export — writing nutrition data back to Health

Logged intake gets written to HealthKit's dietary quantity types so the
Health app, Fitness app, and Watch rings reflect it. Note this is a
different category from the weight/Health *read* path discussed under
Privacy above: writing app data out to HealthKit never involves the LLM or
any network call — it's a purely local, on-device sync from SwiftData to the
OS Health store. The concern there (data reaching a third-party model
provider) doesn't apply here.

**Mapping** — one `HKQuantitySample` per nutrient per `DiaryEntry` (not per
`DiaryItem`; the entry's items are summed first), so Health sees one
"meal-sized" sample per occasion, same as how most food-logging apps write
to it:

| Our `Nutrient.code` | HealthKit type |
|---|---|
| energy (kcal) | `.dietaryEnergyConsumed` |
| protein | `.dietaryProtein` |
| fat | `.dietaryFatTotal` |
| carbohydrate | `.dietaryCarbohydrates` |
| fiber | `.dietaryFiber` |
| sugar | `.dietarySugar` |
| sodium/salt | `.dietarySodium` |

*(Exact `Nutrient.code` values to confirm against Matvaretabellen's nutrient
list when implemented — this is the intended mapping, not verified codes.)*
Nutrients without a HealthKit equivalent are simply not written — no error,
just skipped.

**Tracking what was written**, so edits/deletes stay in sync instead of
leaving orphaned Health samples: `DiaryEntry.healthKitSampleIDs` (see Diary
in the Data Model section) maps `Nutrient.code` to the `HKSample.uuid`
written for it.

**Sync mechanism:** a lightweight observer on `DiaryEntry` saves/deletes
(same shape as the `DailySummary` rollup job — both react to diary changes,
just doing different work), not logic baked into the `create_diary_entry`
tool itself. That keeps it decoupled from *how* an entry was created or
edited (LLM tool call vs. direct UI edit) and means it can't be skipped by
forgetting to call it from one code path:

- New entry → write one sample per mapped nutrient, store the returned
  sample IDs.
- Edited entry (quantity/items changed) → update the existing samples via
  their stored IDs rather than creating duplicates.
- Deleted entry → delete the corresponding samples.
- Write failures (permission not granted, HealthKit unavailable) are
  best-effort and silent to the user's core flow — diary logging must never
  fail or block because a Health write failed.

**Off by default, opt-in.** Not everyone wants dual-write to Health; this
should be a Settings toggle, with its own write-authorization request
per dietary type — separate from (and not required by) weight import.

**Known limitation, not solved here:** if the user edits or deletes the
written sample directly from the Health app itself, this design doesn't
reconcile that back — it's a one-way sync (app → Health) for v1. Worth a
follow-up pass if two-way sync ever matters.

### Authorization & LLM boundary

- **Least-privilege authorization:** request only the specific HealthKit
  types actually used (`.bodyMass` for import; the dietary types above,
  individually, only if export is enabled) — never broad "all health data"
  access.
- **HealthKit access lives entirely in app code**, both directions. There is
  no `read_healthkit` or `write_healthkit` tool. The LLM only ever sees
  already-imported, already-summarized *food* data through the same minimal,
  purpose-built tools as everything else in this doc — see below — and, per
  the Privacy section, never sees weight/Health data at all.

New entries for the [LLM Tool Interface](#llm-tool-interface) — note that
nothing weight- or Health-related is exposed here; see Privacy below for why:

| Tool | Params | Returns | Notes |
|---|---|---|---|
| `get_daily_summaries` | `from`, `to`, `nutrientCode?` | `[DailySummaryPoint]` | Backs charts; also usable by the LLM to answer "how was my week" — food/nutrient data only, never weight. |
| `get_active_targets` | — | `[NutritionTarget]` | Just the resolved daily numbers (kcal, protein, ...) — not how they were derived, so no weight/goal data leaks through. |
| `set_nutrition_target` | nutrientCode, dailyAmount | `NutritionTarget` | Closes out the previous target (`effectiveTo = now`) and opens a new one. |

`set_weight_goal` and `log_weight` are **not** LLM tools — they're plain
app UI actions (a form, a HealthKit import), same as weight-progress viewing
being a chart/heatmap in the UI rather than something you ask the LLM about.

## Privacy: Health data and the LLM

This is a real risk if implemented carelessly, worth designing around
explicitly rather than deciding case by case later.

**The rule:** Apple's HealthKit guidelines are explicit — apps "may not use
or disclose to third parties data gathered in the health, fitness, and
medical research context... for advertising or other use-based data mining
purposes other than improving health management," and HealthKit data can't
be shared with analytics or third-party platforms without consent scoped to
that specific purpose. Sending raw HealthKit-derived data into a cloud LLM's
context — i.e. to Anthropic's (or any) API — counts as sharing with a third
party. It's not automatically disallowed if it's genuinely in service of
health management and disclosed to the user, but it needs to be handled
deliberately, and it's a real exposure independent of the App Store rules:
whatever's in that request is processed and logged by the model provider.

**Design decision: don't route around the risk, remove it.** Rather than
giving the LLM a carefully minimized view of Health/weight data, the LLM
gets **no tool that touches weight or HealthKit data at all** —
`get_weight_progress` from the earlier draft is cut entirely. The
weight-goal → daily-target derivation is a deterministic calculator (see
Targets & Goals), and weight-progress viewing is a chart/heatmap in the UI
(see Statistics & Visualization), so there was never a real need for the LLM
to see weight data in the first place — it only looked that way because
"comment on progress conversationally" was an assumed feature, not a
requirement.

- HealthKit access stays entirely inside app code (`WeightEntry` import,
  the target calculator) and never crosses into anything the LLM can call.
- Request only the specific HealthKit types actually used (`.bodyMass`, not
  broad access) — least privilege at the OS permission level too, though
  it's now a secondary safeguard rather than the primary one.
- Net effect: the blast radius of a bug or a bad tool call is zero Health
  data, not "a handful of derived numbers." If a future feature genuinely
  needs the LLM to reason about weight conversationally, revisit then —
  and if so, prefer on-device (see Model Routing above) rather than sending
  it to the cloud model.

## Open Questions

- **Ask vs. guess-and-edit**: when input is ambiguous (portion size, which
  product), should the app always ask a clarifying question, or make its
  best guess and let the user correct it after the fact? Leaning toward
  guess-and-edit as the default, since it matches the "low friction" goal —
  but some cases (e.g. wildly different calorie counts between options)
  may warrant a quick confirm.
- Multi-item photo input (e.g. a plate) — worth a v2 exploration using
  vision models for portion estimation, not part of MVP.

## Next Steps (not started)

- [ ] Decide on ask-vs-guess-and-edit default
- [ ] Prototype the tool-calling pipeline (LLM + Kassalapp + Matvaretabellen)
- [ ] Design the structured log schema (food ID, source, quantity, grams, timestamp)
- [ ] Define recurring-meal detection logic (clustering approach, threshold for "usual")
- [ ] Spec the review/correction UI for LLM-parsed entries
- [ ] Build the deterministic weight-goal → daily-target calculator (no LLM)
- [ ] Prototype HealthKit weight import (`.bodyMass` only) and the rollup job that feeds `DailySummary`
- [ ] Define the tolerance band for `TargetStatus.onTarget` (e.g. ±5%) and whether it's user-configurable
- [ ] Confirm the `Nutrient.code` ↔ `HKQuantityTypeIdentifier` mapping against Matvaretabellen's actual nutrient codes
- [ ] Build the DiaryEntry-observer sync job for HealthKit export (write/update/delete)
