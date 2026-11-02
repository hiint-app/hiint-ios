import AuthenticationServices
import Foundation
import Testing

@testable import Hiint

struct SignInChallengeTests {
    @Test func matchesTheRFC7636TestVector() {
        let challenge = SignInChallenge(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(challenge.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func makesAFreshURLSafeVerifierEachTime() {
        let first = SignInChallenge()
        let second = SignInChallenge()
        #expect(first.verifier != second.verifier)
        #expect(first.verifier.count == 43)
        #expect(first.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(SignInChallenge(verifier: first.verifier) == first)
    }
}

struct ServerAddressesTests {
    let server = URL(string: "https://hiint.app")!

    @Test func helloIsOnHiintsOwnHost() {
        #expect(
            ServerAddresses.helloURL(serverURL: server, workspace: "driftnote")?.absoluteString
                == "https://hiint.app/api/sdk/v1/driftnote/hello")
        #expect(ServerAddresses.helloURL(serverURL: server, workspace: "") == nil)
    }

    @Test func signInKeepsTheReturnPathWholeAndLeavesOutAMissingEmail() throws {
        let url = try #require(
            ServerAddresses.signInURL(
                serverURL: server, provider: "google", workspace: "driftnote", returnPath: "/?board=ideas&sort=new",
                challenge: "abc", email: nil))
        #expect(
            url.absoluteString
                == "https://hiint.app/sdk/sign-in?provider=google&workspace=driftnote&return=%2F%3Fboard%3Dideas%26sort%3Dnew&challenge=abc"
        )
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "return" }?.value == "/?board=ideas&sort=new")
    }

    @Test func signInEscapesAPlusInTheEmail() throws {
        let url = try #require(
            ServerAddresses.signInURL(
                serverURL: server, provider: "google", workspace: "driftnote", returnPath: "/", challenge: "abc",
                email: "sam+app@example.com"))
        #expect(url.absoluteString.hasSuffix("&email=sam%2Bapp%40example.com"))
    }

    @Test func sessionCarriesTheCodeAndVerifier() {
        #expect(
            ServerAddresses.sessionURL(serverURL: server, code: "c0de", verifier: "v-1_x")?.absoluteString
                == "https://hiint.app/sdk/session?code=c0de&verifier=v-1_x")
    }

    @Test func worksWithALocalServer() {
        let local = URL(string: "http://lvh.me:5173")!
        #expect(
            ServerAddresses.helloURL(serverURL: local, workspace: "pica-test")?.absoluteString
                == "http://lvh.me:5173/api/sdk/v1/pica-test/hello")
    }
}

struct SignInOutcomeTests {
    @Test func readsTheCode() {
        #expect(
            signInOutcome(callbackURL: URL(string: "hiint-sdk://signed-in?code=abc123"), error: nil)
                == .signedIn(code: "abc123"))
    }

    @Test func treatsACancelledSignInAsCancelled() {
        #expect(signInOutcome(callbackURL: URL(string: "hiint-sdk://signed-in?error=cancelled"), error: nil) == .cancelled)
        let closedSheet = ASWebAuthenticationSessionError(.canceledLogin)
        #expect(signInOutcome(callbackURL: nil, error: closedSheet) == .cancelled)
    }

    @Test func failsOnAnythingElse() {
        #expect(signInOutcome(callbackURL: URL(string: "other://signed-in?code=abc"), error: nil) != .signedIn(code: "abc"))
        #expect(signInOutcome(callbackURL: URL(string: "hiint-sdk://signed-in"), error: nil) != .cancelled)
        #expect(signInOutcome(callbackURL: URL(string: "hiint-sdk://signed-in?code="), error: nil) != .signedIn(code: ""))
    }
}
