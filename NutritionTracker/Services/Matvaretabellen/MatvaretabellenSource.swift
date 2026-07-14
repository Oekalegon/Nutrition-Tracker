import Foundation

/// Describes how a `MatvaretabellenConstituent`/`energy`/`calories` value was
/// derived — e.g. sourceId "10" means "missing value, content not known",
/// "0" means "estimated as 100% edible (net weight)".
struct MatvaretabellenSource: Codable, Hashable {
    var sourceId: String
    var description: String
}
