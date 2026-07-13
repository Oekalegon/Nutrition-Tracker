import Foundation

/// Fetches Matvaretabellen's full JSON dumps (foods, food groups, nutrients,
/// sources). No auth, no rate limit — the table updates annually, so responses
/// are cached to disk indefinitely rather than re-fetched on every launch.
///
/// This client only fetches and decodes; turning the result into `Food`/
/// `FoodGroup`/`Nutrient` SwiftData rows is a separate importer (see design doc).
actor MatvaretabellenClient {
    private let transport: MatvaretabellenTransport
    private let cacheDirectory: URL

    init(
        transport: MatvaretabellenTransport = URLSessionMatvaretabellenTransport(),
        cacheDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    ) {
        self.transport = transport
        self.cacheDirectory = cacheDirectory
    }

    func fetchFoods(locale: MatvaretabellenLocale = .english) async throws -> MatvaretabellenFoodsResponse {
        try await fetch(endpoint: "foods", locale: locale)
    }

    func fetchFoodGroups(locale: MatvaretabellenLocale = .english) async throws -> MatvaretabellenFoodGroupsResponse {
        try await fetch(endpoint: "food-groups", locale: locale)
    }

    func fetchNutrients(locale: MatvaretabellenLocale = .english) async throws -> MatvaretabellenNutrientsResponse {
        try await fetch(endpoint: "nutrients", locale: locale)
    }

    func fetchSources(locale: MatvaretabellenLocale = .english) async throws -> MatvaretabellenSourcesResponse {
        try await fetch(endpoint: "sources", locale: locale)
    }

    private func fetch<Response: Decodable>(endpoint: String, locale: MatvaretabellenLocale) async throws -> Response {
        let data = try await cachedData(endpoint: endpoint, locale: locale)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func cachedData(endpoint: String, locale: MatvaretabellenLocale) async throws -> Data {
        let cacheURL = cacheFileURL(endpoint: endpoint, locale: locale)
        if let cached = try? Data(contentsOf: cacheURL) {
            return cached
        }

        guard let url = URL(string: "https://www.matvaretabellen.no/api/\(locale.rawValue)/\(endpoint).json") else {
            throw MatvaretabellenClientError.invalidURL(endpoint: endpoint, locale: locale)
        }

        let data = try await transport.fetchData(from: url)
        try? data.write(to: cacheURL)
        return data
    }

    private func cacheFileURL(endpoint: String, locale: MatvaretabellenLocale) -> URL {
        cacheDirectory.appendingPathComponent("matvaretabellen-\(locale.rawValue)-\(endpoint).json")
    }
}
