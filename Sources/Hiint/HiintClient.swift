import Foundation
import WebKit

/** Everything a board sheet needs to load and to sign someone in. */
struct BoardDestination: Equatable, Sendable {
    let pageURL: URL
    let boardAddress: URL
    let server: URL
    let workspace: String
    let email: String?
}

/** The person the app says is using it, from `Hiint.identify`. */
struct Identity: Equatable, Sendable {
    let userId: String
    let email: String?
    let name: String?
    let avatarURL: URL?
    let signature: String?
}

/** The SDK's state for the app's run: the workspace, its `hello`, and who's identified. */
@MainActor
final class HiintClient {
    static let shared = HiintClient()

    private(set) var server: URL = Hiint.defaultServerURL
    private(set) var helloLoader: HelloLoader?
    private(set) var identity: Identity?
    private let updatesOpened = UpdatesOpenedStore()

    var workspace: String? { helloLoader?.workspace }

    func setup(workspace: String, server: URL) {
        let slug = workspace.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !slug.isEmpty else {
            warn("Hiint.setup(workspace:) needs your workspace's slug, like \"driftnote\".")
            return
        }
        self.server = server
        let loader = HelloLoader(workspace: slug, serverURL: server)
        helloLoader = loader
        loader.refresh()
    }

    func identify(_ identity: Identity) {
        self.identity = identity
    }

    func logout() {
        identity = nil
        let boardHost = helloLoader?.hello?.boardUrl.host
        let serverHost = server.host
        Task { await removeBoardCookies(serverHost: serverHost, boardHost: boardHost) }
    }

    func destination(for requested: BoardSection) async -> BoardDestination? {
        guard let helloLoader else {
            warn("Call Hiint.setup(workspace:) before showing the board.")
            return nil
        }
        guard let hello = await helloLoader.load() else { return nil }
        let (section, problem) = availableSection(requested, hello: hello)
        if let problem { warn(problem) }
        guard let pageURL = boardURL(boardAddress: hello.boardUrl, section: section) else { return nil }
        return BoardDestination(
            pageURL: pageURL, boardAddress: hello.boardUrl, server: server, workspace: helloLoader.workspace,
            email: identity?.email)
    }

    func markUpdatesOpened() {
        if let workspace { updatesOpened.markOpened(workspace: workspace) }
    }

    func unreadUpdatesCount() async -> Int {
        guard let helloLoader, let hello = await helloLoader.load() else { return 0 }
        guard let lastOpened = updatesOpened.lastOpened(workspace: helloLoader.workspace) else {
            // First run: what was published before the app was installed isn't news to this person.
            updatesOpened.markOpened(workspace: helloLoader.workspace)
            return 0
        }
        return unreadUpdateCount(recentUpdates: hello.recentUpdates, lastOpened: lastOpened)
    }

    private func removeBoardCookies(serverHost: String?, boardHost: String?) async {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await cookieStore.allCookies()
        where isHiintCookie(domain: cookie.domain, serverHost: serverHost, boardHost: boardHost) {
            await cookieStore.deleteCookie(cookie)
        }
    }
}

/** hiint's cookies: on its own domain and subdomains, or host-only on a custom-domain board. Never the customer's other cookies. */
func isHiintCookie(domain: String, serverHost: String?, boardHost: String?) -> Bool {
    let cookieDomain = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if let serverHost = serverHost?.lowercased(),
        cookieDomain == serverHost || cookieDomain.hasSuffix(".\(serverHost)")
    {
        return true
    }
    return cookieDomain == boardHost?.lowercased()
}
