import Foundation
import SwiftData

enum NutritionTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NutritionTrackerSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
