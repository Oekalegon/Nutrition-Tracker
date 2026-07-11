import Foundation
import SwiftData

enum NutritionTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            FoodGroup.self, Nutrient.self, Food.self, FoodNutrientValue.self,
            Meal.self, MealIngredient.self, Recipe.self, RecipeIngredient.self,
            DiaryEntry.self, DiaryItem.self, DiaryItemNutrientValue.self,
            NutritionTarget.self, WeightGoal.self, WeightEntry.self,
            DailySummary.self, DailyNutrientTotal.self,
        ]
    }
}
