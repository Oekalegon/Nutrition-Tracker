import Foundation

/// Both fields absent (`{}`) for ~3% of foods in the dump — treat as "unknown",
/// not "100% edible".
struct MatvaretabellenEdiblePart: Codable, Hashable {
    var percent: Double?
    var sourceId: String?
}
