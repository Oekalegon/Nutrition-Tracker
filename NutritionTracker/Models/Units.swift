import Foundation

enum UnitDimension: String, Codable {
    case mass
    case volume
    case energy
    case count      // "1 piece", "1 banana", "1 slice"
}

enum MeasurementUnit: String, Codable, CaseIterable {
    // Mass
    case microgram, milligram, gram, kilogram
    // Volume — ml/cl/dl/l plus tsp/tbsp, the units Nordic recipes actually use
    case milliliter, centiliter, deciliter, liter, teaspoon, tablespoon
    // Energy
    case kilocalorie, kilojoule
    // Count
    case piece

    var dimension: UnitDimension {
        switch self {
        case .microgram, .milligram, .gram, .kilogram:
            return .mass
        case .milliliter, .centiliter, .deciliter, .liter, .teaspoon, .tablespoon:
            return .volume
        case .kilocalorie, .kilojoule:
            return .energy
        case .piece:
            return .count
        }
    }

    /// Factor to this dimension's base unit: gram (mass), milliliter (volume),
    /// kilocalorie (energy), or 1 (count).
    var baseUnitFactor: Double {
        switch self {
        case .microgram: return 0.000_001
        case .milligram: return 0.001
        case .gram: return 1
        case .kilogram: return 1_000
        case .milliliter: return 1
        case .centiliter: return 10
        case .deciliter: return 100
        case .liter: return 1_000
        case .teaspoon: return 5      // ~5 ml
        case .tablespoon: return 15   // ~15 ml
        case .kilocalorie: return 1
        case .kilojoule: return 0.239_006   // 1 kJ ≈ 0.239 kcal
        case .piece: return 1
        }
    }

    var symbol: String {
        switch self {
        case .microgram: return "µg"
        case .milligram: return "mg"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .milliliter: return "ml"
        case .centiliter: return "cl"
        case .deciliter: return "dl"
        case .liter: return "l"
        case .teaspoon: return "ts"     // Norwegian teskje
        case .tablespoon: return "ss"   // Norwegian spiseskje
        case .kilocalorie: return "kcal"
        case .kilojoule: return "kJ"
        case .piece: return "stk"
        }
    }
}

struct Measure: Codable, Hashable {
    var value: Double
    var unit: MeasurementUnit

    /// Value expressed in the dimension's base unit (g / ml / kcal / count).
    var baseValue: Double { value * unit.baseUnitFactor }
}
