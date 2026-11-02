import AuthenticationServices
import Foundation

/** The custom scheme hiint redirects to when sign-in in the system sheet ends. Only the sheet that started it receives it. */
let signInCallbackScheme = "hiint-sdk"

/** The addresses the SDK calls on hiint's own host (`hiint.app`), never on the board's. */
enum ServerAddresses {
    static func helloURL(serverURL: URL, workspace: String) -> URL? {
        guard !workspace.isEmpty else { return nil }
        return hiintAddress(on: serverURL, path: "/api/sdk/v1/\(percentEncoded(workspace))/hello")
    }

    static func signInURL(
        serverURL: URL, provider: String, workspace: String, returnPath: String, challenge: String, email: String?
    ) -> URL? {
        hiintAddress(
            on: serverURL, path: "/sdk/sign-in",
            query: percentEncodedQuery([
                "provider": provider, "workspace": workspace, "return": returnPath, "challenge": challenge,
                "email": email,
            ]))
    }

    static func sessionURL(serverURL: URL, code: String, verifier: String) -> URL? {
        hiintAddress(on: serverURL, path: "/sdk/session", query: percentEncodedQuery(["code": code, "verifier": verifier]))
    }
}

/** How a sign-in in the system sheet ended. */
enum SignInOutcome: Equatable, Sendable {
    case signedIn(code: String)
    case cancelled
    case failed(String)
}

/** Reads `hiint-sdk://signed-in?code=…` or `?error=cancelled`, or the sheet's own error. */
func signInOutcome(callbackURL: URL?, error: (any Error)?) -> SignInOutcome {
    if let error {
        if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return .cancelled }
        return .failed(error.localizedDescription)
    }
    guard let callbackURL, callbackURL.scheme == signInCallbackScheme,
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
    else { return .failed("hiint didn't send the app back a sign-in code") }
    if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty { return .signedIn(code: code) }
    if items.first(where: { $0.name == "error" })?.value == "cancelled" { return .cancelled }
    return .failed("hiint didn't send the app back a sign-in code")
}
