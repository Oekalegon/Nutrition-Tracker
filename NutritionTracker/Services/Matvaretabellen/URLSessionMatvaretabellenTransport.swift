import Foundation

struct URLSessionMatvaretabellenTransport: MatvaretabellenTransport {
    func fetchData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
