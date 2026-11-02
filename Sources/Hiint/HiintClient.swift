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

/** The person the app says is using it. */
struct AppIdentity: Equatable, Sendable {
    let userId: String
    let email: String
    let name: String
    let avatarURL: String
    let signature: String
}

/** The SDK's state for the app's run: the workspace, its `hello`, and who's identified. */
@MainActor
final class HiintClient {
    static let shared = HiintClient()

    private(set) var server: URL = Hiint.defaultServerURL
    private(set) var helloLoader: HelloLoader?
    private(set) var identity: AppIdentity?
    /// Set when identify answers that automatic login is off, until the next `setup`.
    private var automaticLoginIsOff = false
    private var identifyWarning: String?
    private let updatesOpened = UpdatesOpenedStore()
    var claimTokens = ClaimTokenStore.keychain

    var workspace: String? { helloLoader?.workspace }

    func setup(workspace: String, server: URL) {
        let slug = workspace.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !slug.isEmpty else {
            warn("Hiint.setup(workspace:) needs your workspace's slug, like \"driftnote\".")
            return
        }
        self.server = server
        automaticLoginIsOff = false
        identifyWarning = nil
        let loader = HelloLoader(workspace: slug, serverURL: server)
        helloLoader = loader
        loader.refresh()
    }

    func identify(userId: String, email: String?, name: String?, avatarURL: URL?, signature: String?) {
        identifyWarning = nil
        identity = AppIdentity(
            userId: userId, email: email ?? "", name: name ?? "", avatarURL: avatarURL?.absoluteString ?? "",
            signature: signature ?? "")
    }

    func logout() {
        identity = nil
        let boardAddress = helloLoader?.hello?.boardUrl
        let serverHost = server.host
        Task { await signOut(boardAddress: boardAddress, serverHost: serverHost) }
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
        let signedInURL = await signedInURL(for: pageURL, workspace: helloLoader.workspace)
        return BoardDestination(
            pageURL: signedInURL ?? pageURL, boardAddress: hello.boardUrl, server: server,
            workspace: helloLoader.workspace,
            email: identity?.email.isEmpty == false ? identity?.email : nil)
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

    private func signedInURL(for pageURL: URL, workspace: String) async -> URL? {
        guard let identity, !automaticLoginIsOff else { return nil }
        let challenge = SignInChallenge()
        let claimAccount = unsignedClaimAccount(
            userId: identity.userId, signature: identity.signature, serverHost: server.host ?? "", workspace: workspace)
        let claimToken = claimAccount.flatMap(claimTokens.read) ?? ""
        let call = IdentifyCall(
            userId: identity.userId, email: identity.email, name: identity.name, avatarURL: identity.avatarURL,
            signature: identity.signature, claimToken: claimToken, challenge: challenge.challenge)
        guard let request = identifyRequest(serverURL: server, workspace: workspace, call: call) else { return nil }
        let result: IdentifyResult
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            result = identifyResult(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
        } catch {
            warnOnce("Automatic login didn’t finish (\(error.localizedDescription)). The board opened without it.")
            return nil
        }
        switch result {
        case .signedIn(let code, let issuedClaimToken):
            if let issuedClaimToken, let claimAccount {
                claimTokens.save(claimAccount, issuedClaimToken)
            }
            return appSessionURL(
                boardAddress: pageURL, code: code, verifier: challenge.verifier, returnPath: boardReturnPath(of: pageURL))
        case .automaticLoginOff:
            automaticLoginIsOff = true
            return nil
        case .refused(let reason):
            warnOnce("Automatic login was refused (\(reason)). The board opened without it.")
            return nil
        case .unreadable:
            warnOnce("Automatic login’s answer couldn’t be read. The board opened without it.")
            return nil
        }
    }

    private func warnOnce(_ message: String) {
        guard identifyWarning != message else { return }
        identifyWarning = message
        warn(message)
    }

    private func signOut(boardAddress: URL?, serverHost: String?) async {
        if let boardAddress {
            let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies().filter {
                isHiintCookie(domain: $0.domain, serverHost: nil, boardHost: boardAddress.host)
            }
            if let request = signOutRequest(
                boardAddress: boardAddress, cookies: cookies.map { (name: $0.name, value: $0.value) })
            {
                _ = try? await URLSession.shared.data(for: request)
            }
        }
        await removeBoardCookies(serverHost: serverHost, boardHost: boardAddress?.host)
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
