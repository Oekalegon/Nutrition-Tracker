import Foundation

enum DiarySourceType: String, Codable {
    case freeEntry   // ad-hoc item(s), not tied to a saved Meal/Recipe
    case meal
    case recipe
}
