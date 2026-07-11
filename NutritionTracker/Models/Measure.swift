import Foundation

struct Measure: Codable, Hashable {
    var value: Double
    var unit: MeasurementUnit

    /// Value expressed in the dimension's base unit (g / ml / kcal / count).
    var baseValue: Double { value * unit.baseUnitFactor }
}
