import Foundation

private let unreservedCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

/** Percent-encodes everything but RFC 3986's unreserved characters, so `&`, `=`, `+`, `?` and `/` survive inside a value. */
func percentEncoded(_ text: String) -> String {
    text.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? ""
}

func percentEncodedQuery(_ items: KeyValuePairs<String, String?>) -> String {
    items.compactMap { name, value in
        value.map { "\(percentEncoded(name))=\(percentEncoded($0))" }
    }
    .joined(separator: "&")
}

/** An address on hiint's own host, with its path and query replaced. */
func hiintAddress(on server: URL, path: String, query: String? = nil) -> URL? {
    guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else {
        return nil
    }
    components.percentEncodedPath = path
    components.percentEncodedQuery = query
    components.fragment = nil
    return components.url
}
