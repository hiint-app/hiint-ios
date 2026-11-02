import Foundation
import Testing

@testable import Hiint

struct NavigationPolicyTests {
    let board = URL(string: "https://feedback.driftnote.app")!
    let server = URL(string: "https://hiint.app")!

    func decision(_ address: String, isMainFrame: Bool = true) -> NavigationDecision {
        navigationDecision(for: URL(string: address)!, boardAddress: board, server: server, isMainFrame: isMainFrame)
    }

    @Test func keepsTheBoardsOwnPages() {
        #expect(decision("https://feedback.driftnote.app/p/dark-mode") == .allow)
        #expect(decision("https://feedback.driftnote.app:443/roadmap") == .allow)
        #expect(decision("https://feedback.driftnote.app/api/board/session?token=x") == .allow)
        #expect(decision("about:blank") == .allow)
    }

    @Test func keepsHiintsSignInPages() {
        #expect(decision("https://hiint.app/login?redirectTo=x") == .allow)
        #expect(decision("https://hiint.app/forgot-password") == .allow)
        #expect(decision("https://hiint.app/auth/handoff?to=x") == .allow)
        #expect(decision("https://hiint.app/sdk/session?code=a&verifier=b") == .allow)
    }

    @Test func sendsEverythingElseToTheSystemBrowser() {
        #expect(decision("https://hiint.app/w/driftnote/requests") == .openExternally)
        #expect(decision("https://hiint.app/pricing") == .openExternally)
        #expect(decision("https://hiint.app/loginx") == .openExternally)
        #expect(decision("https://example.com/") == .openExternally)
        #expect(decision("http://feedback.driftnote.app/") == .openExternally)
        #expect(decision("mailto:sam@example.com") == .openExternally)
    }

    @Test func leavesEmbeddedFramesAlone() {
        #expect(decision("https://www.youtube.com/embed/x", isMainFrame: false) == .allow)
    }
}

struct CookieTests {
    @Test func removesHiintsCookiesOnly() {
        #expect(isHiintCookie(domain: ".hiint.app", serverHost: "hiint.app", boardHost: "feedback.acme.com"))
        #expect(isHiintCookie(domain: "driftnote.hiint.app", serverHost: "hiint.app", boardHost: nil))
        #expect(isHiintCookie(domain: "feedback.acme.com", serverHost: "hiint.app", boardHost: "feedback.acme.com"))
        #expect(!isHiintCookie(domain: ".acme.com", serverHost: "hiint.app", boardHost: "feedback.acme.com"))
        #expect(!isHiintCookie(domain: "nothiint.app", serverHost: "hiint.app", boardHost: nil))
    }
}
