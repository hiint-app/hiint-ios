import AuthenticationServices
import Foundation

/** Runs one sign-in in the system's sign-in sheet, which shares Safari's cookies, and reports how it ended. */
@MainActor
final class SignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var anchor: ASPresentationAnchor?

    func start(
        url: URL, anchor: ASPresentationAnchor, completion: @escaping @MainActor @Sendable (SignInOutcome) -> Void
    ) {
        self.anchor = anchor
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: signInCallbackScheme) {
            callbackURL, error in
            let outcome = signInOutcome(callbackURL: callbackURL, error: error)
            Task { @MainActor in completion(outcome) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        if !session.start() { completion(.failed("the system sign-in sheet didn't open")) }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { anchor ?? ASPresentationAnchor() }
    }
}
