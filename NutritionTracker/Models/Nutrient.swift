import Foundation
import SwiftData

@Model
final class Nutrient {
    @Attribute(.unique) var code: String     // matches source API codes, e.g. "energi_kcal", "protein"
    var displayName: String
    var unit: MeasurementUnit                 // .kilocalorie, .gram, .milligram, .microgram, etc.
    var isCore: Bool                          // kcal/protein/fat/carbs shown prominently in UI

    init(code: String, displayName: String, unit: MeasurementUnit, isCore: Bool = false) {
        self.code = code
        self.displayName = displayName
        self.unit = unit
        self.isCore = isCore
    }
}
