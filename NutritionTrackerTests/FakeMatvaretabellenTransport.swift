import Foundation
@testable import NutritionTracker

/// Records requested URLs and returns canned responses, so tests never touch
/// the real network.
actor FakeMatvaretabellenTransport: MatvaretabellenTransport {
    private(set) var fetchCount = 0
    private let dataByURL: [URL: Data]

    init(dataByURL: [URL: Data]) {
        self.dataByURL = dataByURL
    }

    func fetchData(from url: URL) async throws -> Data {
        fetchCount += 1
        guard let data = dataByURL[url] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }
}
