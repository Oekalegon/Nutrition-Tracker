import Foundation

enum TargetSource: String, Codable {
    case userSet
    case derivedFromWeightGoal   // suggested by the weight-goal calculator, then accepted by the user
}
