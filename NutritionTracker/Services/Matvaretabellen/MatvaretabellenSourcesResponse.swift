import Foundation

struct MatvaretabellenSourcesResponse: Codable, Hashable {
    var sources: [MatvaretabellenSource]
    var locale: String
}
