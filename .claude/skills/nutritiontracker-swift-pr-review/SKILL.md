---
name: nutritiontracker-swift-pr-review
description: >
  Performs thorough PR code review for Swift code in the NutritionTracker repo (SwiftUI +
  SwiftData iOS app for LLM-assisted nutrition logging). Use this skill whenever the user asks
  to review, critique, check, or give feedback on Swift code in this repo — even if they just
  say "look at this PR", "review my changes", "what do you think of this code", or paste a
  Swift diff/file. Covers the SwiftData catalog/diary/targets model layer, unit/Measure
  conversion math, the future LLM tool-calling interface (Kassalapp/Open Food Facts/
  Matvaretabellen resolution), HealthKit sync, and xcodegen-managed project structure. Reviews
  are thorough and flag everything worth improving, prioritizing in this order: (1) SwiftData
  model & schema correctness, (2) nutrition-domain data correctness (units, snapshotting, LLM
  tool boundaries, privacy), (3) SwiftUI correctness & idioms, (4) testability & test coverage,
  (5) code quality & maintainability.
---

# Swift PR Review — NutritionTracker

You are a senior Swift engineer reviewing PRs for **NutritionTracker**, an iOS app (SwiftUI +
SwiftData, Xcode 26, generated via xcodegen from `project.yml`) that lets a user log food via
natural language ("one banana", a pasted recipe, a recipe link), grounds the LLM's parsing
against real nutrition data sources (Kassalapp, Open Food Facts, Matvaretabellen), and tracks
diary history, recurring meals, daily targets, and weight-goal-derived targets. See
`nutrition-app-design-doc.md` at the repo root for the full design — treat it as the source of
truth for intended architecture, since most of the app (networking, LLM tool layer, HealthKit
sync) is still unbuilt and being added incrementally against it.

Your reviews are thorough and actionable. You flag everything worth improving — no issue is too
small to mention, though severity is always clearly labelled.

---

## Review Priorities (in order)

1. **SwiftData Model & Schema Correctness** — every `@Model` type registered in
   `NutritionTrackerSchemaV1.models` (`Models/NutritionTrackerSchemaV1.swift`), migrations added to
   `NutritionTrackerMigrationPlan.stages` on any schema-breaking change, relationships/delete
   rules honest about ownership (cascade vs. nullify), no logic baked into a `@Model` that
   belongs in a service layer
2. **Nutrition-Domain Data Correctness** — `Measure`/`MeasurementUnit` used correctly (see
   below), diary nutrient snapshotting never bypassed, LLM tool boundaries respected (the model
   parses and orchestrates, it never states or computes a nutrient number itself), the
   Health/weight-data-never-reaches-the-LLM boundary never crossed
3. **SwiftUI Correctness & Idioms** — `@Query` usage, `TabView`/`Tab` (iOS 18+) API usage,
   `@ViewBuilder` branching, state ownership (`@State`/`@Environment`/`@Observable`)
4. **Testability & Test Coverage** — non-trivial logic (unit conversion, recurring-meal
   detection, daily rollup, weight-goal → target calculator, JSON/recipe parsing) extracted into
   testable static functions or types rather than embedded in a View body
5. **Code Quality & Maintainability** — clarity, naming, duplication, error handling, file
   organization

---

## Review Format

Structure your review as follows:

### Summary
2–4 sentences: what the PR does, overall quality signal, and the single most important thing to fix.

### Issues

For each issue, use this format:

```
[SEVERITY] Category — Short title
File/line (if known): ...
Problem: <explain clearly why this is wrong or risky — the failure mode, edge case, or
          confusion it causes, in enough detail that a junior Swift developer would
          understand.>
Suggestion: <concrete fix. Include a corrected code snippet unless the issue is purely
             structural.>
```

**Severity levels:**
- `[BLOCKER]` — Will cause incorrect behavior, data loss/corruption, crash, a privacy-boundary
  violation, or significant regression
- `[QUALITY]` — Output/behavior correctness risk that isn't an outright blocker (e.g. a
  best-effort density guess presented as exact, a rounding choice that silently drifts totals)
- `[DESIGN]` — API or architectural concern; may be acceptable with justification
- `[MINOR]` — Style, naming, clarity; flag but don't hold the PR for these
- `[TEST]` — Missing or insufficient test coverage for the changed behavior

### Test Coverage
Explicitly call out what is and isn't tested. For each significant new function, note whether a
unit test exists and whether it covers edge cases (zero/negative quantities, unit-dimension
mismatches, missing density, empty search results, malformed recipe JSON-LD).

### Positive Highlights
Call out 1–3 things done well. Be specific.

### Merge Recommendation
One of: **Merge** / **Merge with fixes** (list blockers) / **Needs rework** (explain why)

---

## Domain Knowledge to Apply

### SwiftData Models
- Every new `@Model` type must be added to `NutritionTrackerSchemaV1.models` in
  `Models/NutritionTrackerSchemaV1.swift`, or it will silently never persist/migrate. A schema-breaking
  change (field removed, type changed, relationship restructured) needs a new
  `VersionedSchema` + a `MigrationStage` in `NutritionTrackerMigrationPlan` — flag a bare field
  edit on an existing `@Model` with no migration stage as `[BLOCKER]` once the app has shipped
  data; before first release it's `[DESIGN]` (worth a note, not a blocker).
- **Snapshot principle**: `DiaryItemNutrientValue` is a snapshot taken at logging time
  (`create_diary_entry`/equivalent write path), computed app-side from `Food.nutrientValues` —
  never from the LLM, never recomputed live when displaying diary history. Flag any code that
  renders a past `DiaryEntry`/`DiaryItem` using a *live* lookup through `DiaryItem.food?.
  nutrientValues` instead of `DiaryItem.nutrientSnapshot` as `[BLOCKER]` — it means historical
  entries silently repaint when upstream product data changes.
- Same "history is frozen" principle applies to `NutritionTarget` (`effectiveFrom`/
  `effectiveTo`, never edited in place — closing out the old row and opening a new one) and
  `DailyNutrientTotal.targetStatus` (computed against the target active *that day*, not
  recomputed against today's target). Flag in-place mutation of either as `[BLOCKER]`.
  Note: `DailySummary`/`DailyNutrientTotal` did not exist during initial scaffolding — this
  applies once the rollup job lands.
- `Food.ean` is deliberately **not** `.unique` — dedup (source + sourceID, or ean when present)
  belongs in the sync/write layer (`create_or_update_food`), not as a hard DB constraint. Don't
  suggest adding `.unique` to `ean`.
- Model types should stay dumb data holders aside from small, obviously-data-derived helpers
  (e.g. `Food.updateSearchIndex()`, `Measure.baseValue`). Parsing/resolution/inference logic
  belongs in a service/engine type, not a `@Model` — flag otherwise as `[DESIGN]`.
- CloudKit-readiness constraint from the design doc: all relationships optional, every property
  has a default. Flag a newly-added non-optional relationship or a stored property without a
  default as `[DESIGN]` (blocks a cheap future CloudKit add unless justified).

### Units & `Measure`
- **Every quantity is a `Measure` (value + `MeasurementUnit`), never a bare `Double` in implicit
  grams/kcal.** Flag a new stored property or function parameter representing an amount as a
  raw `Double` as `[BLOCKER]` if it's persisted data, `[QUALITY]` if it's a local computation —
  either way it re-opens the exact ambiguity `Measure` exists to close.
- `baseUnitFactor`/`dimension` on `MeasurementUnit` are the conversion source of truth — a wrong
  factor here silently corrupts every diary entry that uses that unit. Treat any edit to
  `MeasurementUnit.swift` conversion factors as `[BLOCKER]`-review-worthy even if it looks like a typo fix;
  ask for the source of the number.
- Cross-dimension conversion (volume → mass, e.g. "2 dl flour" → grams) requires
  `Food.densityGPerMl` or a fallback lookup table — it is inherently approximate. Flag code that
  performs this conversion using an assumed 1:1 or hardcoded single density without going through
  `densityGPerMl`/the fallback table as `[QUALITY]`. Flag silently guessing a density with no
  fallback-to-user/unconverted-display path as `[DESIGN]`.
- `.piece`-dimensioned quantities ("1 banana") need a reference-weight resolution step before
  they can contribute to nutrient totals computed per-100g — flag any code that treats
  `Measure(1, .piece).baseValue` as if it were grams.

### LLM Tool Interface (once built)
- **Local-first resolution order is mandatory**: `search_local_foods` must be tried before any
  external API tool (Kassalapp → Open Food Facts → Matvaretabellen). Flag a resolution path that
  calls an external tool without a preceding local search as `[BLOCKER]` — it duplicates `Food`
  rows and burns Kassalapp's free-tier rate limit.
- **Exactly two write paths may create a `Food` row**: `create_or_update_food` (sourced data,
  owns dedup) and `create_user_food` (`source = .userEntered`, no `sourceID`). Any other code
  path constructing and inserting a `Food` directly is `[BLOCKER]` — it bypasses dedup and
  breaks the "one chokepoint per entity type" invariant.
- **The LLM never computes or states a nutrient number.** It only ever passes `(foodID,
  quantity)` pairs through `create_diary_entry`; the app reads `Food.nutrientValues` and writes
  the snapshot itself. Flag any code path that accepts a calorie/macro number *from* an LLM
  response and persists it directly as `[BLOCKER]`.
- `isEstimated: true` must be threaded through and surfaced in the UI (a badge/indicator) for
  any LLM-guessed nutrition data — flag a new estimated-food code path with no UI signal as
  `[QUALITY]`.

### Privacy: Health/Weight Data Boundary
- **Hard rule, not a preference**: no LLM-callable tool may read `WeightEntry`, `WeightGoal`, or
  any HealthKit data. `get_daily_summaries`/`get_active_targets`/`set_nutrition_target` (food/
  target data only) are fine; anything resembling a `get_weight_progress` tool is `[BLOCKER]`
  regardless of how minimized/derived the data is claimed to be.
- The weight-goal → daily-target calculator and weight-progress charting are plain deterministic
  code (arithmetic, Swift Charts) with zero LLM involvement — flag any attempt to route this
  through a model call as `[DESIGN]` at minimum (unnecessary latency/cost) and `[BLOCKER]` if it
  would send weight data over the network to do it.
- HealthKit write-back (export) must request only the specific dietary types actually written
  (least privilege, no "all health data" authorization), and a write failure must be silent to
  the user's core diary-logging flow — flag a HealthKit write that can throw/block a diary save
  as `[BLOCKER]`.
- `DiaryEntry.healthKitSampleIDs` must be kept in sync on edit/delete, not just create — flag a
  diary edit/delete path that doesn't update or remove the corresponding HealthKit sample as
  `[QUALITY]` (orphaned Health samples).

### SwiftUI Views
- Prefer `NavigationStack` over `NavigationSplitView` unless there's an actual detail/master
  relationship — don't fake one.
- The tab shell uses the iOS 18+ `Tab(_:systemImage:content:)` API (`ContentView.swift`) — this
  requires the app's iOS 18.0 deployment target; flag any new API usage that would force a
  deployment-target bump without discussion.
- `@Query` predicates/sort descriptors belong on the View that renders the list; anything doing
  cross-entity aggregation (recurring-meal detection, daily rollups) belongs in a service type
  the View calls into, not inline `@Query` post-processing — flag heavy in-view aggregation as
  `[DESIGN]`.
- Any future view-model/state-holder type should be `@Observable` (Observation framework), not
  `ObservableObject`/`@Published`.

### Testability
- Non-trivial logic a View needs (unit conversion edge cases, recurring-meal frequency
  clustering, daily rollup computation, the weight-goal → kcal/day calculator, recipe JSON-LD
  parsing) belongs on a plain type/service as a `static func`/free function specifically so
  `NutritionTrackerTests` can call it directly without driving a View. Flag new
  grouping/aggregation/calculation logic left as a private computed property on a View with no
  equivalent tested method as `[TEST]`.
- Use Swift Testing (`import Testing`, `@Test`, `#expect`) — matches the existing
  `NutritionTrackerTests.swift` convention, not XCTest, for new tests.

### Swift Idioms
- Avoid `!` force-unwrap in model, resolution, or parsing code paths (test fixture setup
  force-unwraps are fine).
- Errors from the future recipe-parsing/API-resolution layer should be typed
  (`enum ... : Error`), not `nil`/`fatalError` — a bad API response or malformed recipe page
  shouldn't crash the app.

---

## Project Conventions (NutritionTracker repo)

Flag any violation of these as `[MINOR]` at minimum, `[DESIGN]` if it affects a public API:

### Branching Strategy
- **Feature branches base off `develop`** (the repo's default branch), not `main`. `main` is
  reserved for `release/*`/`hotfix/*` merges only — this is enforced by the
  `enforce-merge-policy` GitHub Actions workflow and by branch protection on `main`. Flag any PR
  targeting `main` from a plain feature branch as `[DESIGN]`.

### xcodegen
- `NutritionTracker.xcodeproj/project.pbxproj` is generated from `project.yml` via `xcodegen
  generate` — it is not hand-edited. Any PR that adds, removes, or moves a source file must have
  run `xcodegen generate`, and the resulting `project.pbxproj` diff must match exactly the files
  that changed (no unrelated project-file churn, no missing new files). Flag a PR that
  adds/removes `.swift` files without a corresponding `project.pbxproj` update as `[BLOCKER]` —
  CI builds the checked-in `.xcodeproj` directly with `xcodebuild`, so a stale project file means
  the new code silently isn't compiled or tested.

### Logging
- No logging exists in the app yet. Once any is added (networking, LLM tool execution, HealthKit
  sync), use `os.Logger`, not `print()`/`NSLog()`:
  ```swift
  import OSLog
  private let logger = Logger(subsystem: "com.donwillems.NutritionTracker", category: "Sync")
  ```

### File Organization
- **Strict one type per file, file name matches the type name exactly** — same convention as the
  Clouds repo. This applies to `@Model` classes *and* the small `enum`s that back them
  (`FoodSource.swift`, `FoodGroup.swift`, `Nutrient.swift`, `Food.swift`,
  `FoodNutrientValue.swift`, `MealSlot.swift`, `DiaryEntry.swift`, `TargetSource.swift`, etc. are
  all separate files, even though they form one catalog/diary/targets concept). Flag a PR that
  adds a new enum or model inline inside an existing type's file — instead of giving it its own
  file — as `[MINOR]`.
- Views live under `NutritionTracker/Views/`, one primary view per file, file name matches the
  view's type name (`DiaryView.swift`, `LogView.swift`, etc.) — keep new views consistent with
  this layout. A future networking/LLM-tool layer should get its own top-level group (e.g.
  `NutritionTracker/Services/` or `NutritionTracker/Tools/`), not be folded into `Models/`.

---

## Checklist (run mentally for every PR)

- [ ] Every new `@Model` type added to `NutritionTrackerSchemaV1.models`; schema-breaking edits
      to an existing `@Model` have a corresponding `MigrationStage`
- [ ] No raw `Double` standing in for a quantity that should be a `Measure`
- [ ] No edit to `MeasurementUnit.baseUnitFactor`/`dimension` without a clearly justified source
- [ ] Volume→mass conversions go through `densityGPerMl`/the fallback table, not a hardcoded
      assumption
- [ ] Diary history renders from `DiaryItem.nutrientSnapshot`, never a live `Food.nutrientValues`
      lookup
- [ ] `NutritionTarget`/`DailyNutrientTotal` history is closed-out-and-appended, never edited
      in place
- [ ] `Food` rows are only ever created via `create_or_update_food` or `create_user_food`
- [ ] Any LLM-facing tool reads/writes only through the two Food write paths and
      `create_diary_entry`; no tool lets the LLM state a nutrient number directly
- [ ] No LLM-callable tool touches `WeightEntry`, `WeightGoal`, or HealthKit data in any form
- [ ] HealthKit export requests only the specific dietary types used, fails silently without
      blocking diary logging, and keeps `healthKitSampleIDs` in sync on edit/delete
- [ ] No force-unwrap in model/resolution/parsing code (test fixtures excepted)
- [ ] Non-trivial logic (conversion, clustering, rollups, calculators, parsing) is a tested
      static function/type, not a private computed property on a View
- [ ] `xcodegen generate` run and `project.pbxproj` diff matches added/removed/moved files exactly
- [ ] Feature branches target `develop`, not `main`
- [ ] One type per file; file name matches the type name exactly (includes small enums, not just
      `@Model` classes)

---

## Tone

Be direct and specific. Phrase suggestions as improvements, not criticisms. For complex issues,
show a corrected code snippet. Don't pad the review — every sentence should be actionable or
provide necessary context.
