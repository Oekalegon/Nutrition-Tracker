import Foundation

/// One nutrient reading for a food. `sourceId` is missing for a small number of
/// entries; `quantity`/`unit` are both absent together when the value is
/// unmeasured (see `MatvaretabellenSource` — e.g. sourceId "10" means "missing
/// value, content not known").
struct MatvaretabellenConstituent: Codable, Hashable {
    var nutrientId: String
    var sourceId: String?
    var quantity: Double?
    var unit: String?
}
