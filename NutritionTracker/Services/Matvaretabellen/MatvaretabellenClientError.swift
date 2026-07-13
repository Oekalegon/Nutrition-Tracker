import Foundation

enum MatvaretabellenClientError: Error {
    case invalidURL(endpoint: String, locale: MatvaretabellenLocale)
}
