import Foundation

/// Shared shape for `energy`/`calories` fields in the Matvaretabellen foods dump.
/// All fields are optional — a handful of foods (e.g. liquid vitamin supplements)
/// carry an empty `{}` here, and `quantity` can be null even when `sourceId`/`unit`
/// are present, e.g. `sourceId: "10"` ("missing value, content not known").
struct MatvaretabellenValue: Codable, Hashable {
    var sourceId: String?
    var quantity: Double?
    var unit: String?
}
