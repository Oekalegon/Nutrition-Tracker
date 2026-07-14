import Foundation

/// Abstracts the actual network fetch so `MatvaretabellenClient` can be tested
/// against fixture JSON without hitting the real API.
protocol MatvaretabellenTransport: Sendable {
    func fetchData(from url: URL) async throws -> Data
}
