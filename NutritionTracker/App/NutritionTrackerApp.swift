import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.donwillems.NutritionTracker", category: "Seeding")

@main
struct NutritionTrackerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: NutritionTrackerSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: NutritionTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        do {
            try NutrientSeeder.seedCoreNutrientsIfNeeded(in: modelContainer.mainContext)
        } catch {
            logger.error("Failed to seed core nutrient catalog: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
