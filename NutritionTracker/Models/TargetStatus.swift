import Foundation

enum TargetStatus: String, Codable {
    case noTarget
    case belowTarget
    case onTarget    // within a tolerance band around the active target, e.g. ±5%
    case aboveTarget
}
