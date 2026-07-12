import Foundation
import SwiftData

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Measure
    var source: WeightSource
    var healthKitSampleID: UUID?    // for de-duping re-imports

    init(id: UUID = UUID(), date: Date, weight: Measure, source: WeightSource,
         healthKitSampleID: UUID? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.source = source
        self.healthKitSampleID = healthKitSampleID
    }
}
