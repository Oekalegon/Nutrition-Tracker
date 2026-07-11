import SwiftUI
import SwiftData

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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
