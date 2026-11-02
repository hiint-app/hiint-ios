import Foundation

enum NavigationDecision: Equatable, Sendable {
    case allow
    case openExternally
}

/** hiint's sign-in pages on its own host, which stay in the web view so signing in works as it does on a phone. */
private let signInPathPrefixes = ["/login", "/signup", "/forgot-password", "/reset-password", "/auth/", "/api/auth/", "/sdk/session"]

/**
 * Whether a navigation stays in the sheet or goes to the system browser. The board's own pages and hiint's sign-in
 * pages stay; everything else leaves, so the sheet never turns into a general browser.
 */
func navigationDecision(for url: URL, boardAddress: URL, server: URL, isMainFrame: Bool) -> NavigationDecision {
    guard isMainFrame else { return .allow }
    if url.scheme == "about" { return .allow }
    guard let origin = Origin(url) else { return .openExternally }
    if origin == Origin(boardAddress) { return .allow }
    if origin == Origin(server), signInPathPrefixes.contains(where: { isPath(url.path, under: $0) }) {
        return .allow
    }
    return .openExternally
}

/** `/login` covers `/login` and `/login/…` but not `/loginx`; a prefix ending in `/` covers everything below it. */
private func isPath(_ path: String, under prefix: String) -> Bool {
    if prefix.hasSuffix("/") { return path.hasPrefix(prefix) }
    return path == prefix || path.hasPrefix(prefix + "/")
}

/** Scheme, host and port, with the default port filled in, so `https://a.app` and `https://a.app:443` match. */
private struct Origin: Equatable {
    let scheme: String
    let host: String
    let port: Int

    init?(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host?.lowercased()
        else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = url.port ?? (scheme == "https" ? 443 : 80)
    }
}
