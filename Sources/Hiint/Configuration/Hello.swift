import Foundation

/** The board's details from `GET /api/sdk/v1/<workspace>/hello`, version 1 of the contract. */
struct Hello: Codable, Equatable, Sendable {
    struct Workspace: Codable, Equatable, Sendable {
        let slug: String
        let name: String
        let logoUrl: URL?
        let brandColour: String?
    }

    struct Sections: Codable, Equatable, Sendable {
        let roadmap: Bool
        let changelog: Bool
    }

    struct Board: Codable, Equatable, Sendable {
        let slug: String
        let name: String
    }

    let v: Int
    let workspace: Workspace
    let boardUrl: URL
    let sections: Sections
    let boards: [Board]
    let recentUpdates: [Date]

    static func decode(_ data: Data) throws -> Hello {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseInternetDate(text) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "\(text) isn't an ISO 8601 date")
            }
            return date
        }
        return try decoder.decode(Hello.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/** Reads `2026-11-01T09:12:00Z` and JavaScript's `2026-11-01T09:12:00.000Z` alike. */
func parseInternetDate(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}
