import Foundation
import Testing

@testable import Hiint

struct IdentifyExchangeTests {
    let server = URL(string: "https://hiint.app")!
    let board = URL(string: "https://driftnote.hiint.app")!

    @Test func identifyPostsSnakeCaseJSON() throws {
        let request = try #require(
            identifyRequest(
                serverURL: server, workspace: "driftnote",
                call: IdentifyCall(
                    userId: "user-42", email: "sam@example.com", name: "Sam", avatarURL: "https://cdn.example/a.png",
                    signature: "abc", claimToken: "", challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
                )))
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://hiint.app/api/sdk/v1/driftnote/identify")
        let json = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
        #expect(json["user_id"] == "user-42")
        #expect(json["avatar_url"] == "https://cdn.example/a.png")
        #expect(json["claim_token"] == "")
        #expect(json["challenge"] == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func readsASignedInAnswerAndAClaimToken() {
        let body = Data(#"{"code":"abc","claim_token":"tok"}"#.utf8)
        #expect(identifyResult(status: 200, body: body) == .signedIn(code: "abc", claimToken: "tok"))
        #expect(identifyResult(status: 200, body: Data(#"{"code":"abc"}"#.utf8)) == .signedIn(code: "abc", claimToken: nil))
    }

    @Test func automaticLoginOffIsDistinctFromOtherRefusals() {
        let off = Data(#"{"error":{"code":"forbidden","message":"Off.","details":{"reason":"automatic_login_off"}}}"#.utf8)
        #expect(identifyResult(status: 403, body: off) == .automaticLoginOff)
        let mismatch = Data(
            #"{"error":{"code":"unauthorized","message":"No.","details":{"reason":"claim_token_mismatch"}}}"#.utf8)
        #expect(identifyResult(status: 401, body: mismatch) == .refused(reason: "claim_token_mismatch"))
        #expect(identifyResult(status: 500, body: Data()) == .refused(reason: "HTTP 500"))
        #expect(identifyResult(status: 200, body: Data("[]".utf8)) == .unreadable)
    }

    @Test func theSessionURLStaysOnTheBoardAndKeepsTheReturnPathWhole() throws {
        let page = try #require(URL(string: "https://driftnote.hiint.app/?board=ideas&sort=new"))
        let url = try #require(
            appSessionURL(boardAddress: board, code: "code", verifier: "verifier", returnPath: boardReturnPath(of: page)))
        #expect(
            url.absoluteString
                == "https://driftnote.hiint.app/api/board/app-session?code=code&verifier=verifier&return=%2F%3Fboard%3Dideas%26sort%3Dnew"
        )
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "return" }?.value == "/?board=ideas&sort=new")
    }

    @Test func claimTokenAccountNamesTheServerWorkspaceAndUser() {
        #expect(claimTokenAccount(serverHost: "Hiint.app", workspace: "driftnote", userId: "user-42") == "hiint.app/driftnote/user-42")
        #expect(claimTokenService == "app.hiint.claim")
    }

    @Test func onlyAnUnsignedIdentityHasAClaimToken() {
        let unsigned = unsignedClaimAccount(
            userId: "user-42", signature: "", serverHost: "hiint.app", workspace: "driftnote")
        #expect(unsigned == "hiint.app/driftnote/user-42")
        #expect(
            unsignedClaimAccount(
                userId: "user-42", signature: "abc", serverHost: "hiint.app", workspace: "d") == nil)
        #expect(unsignedClaimAccount(userId: "", signature: "", serverHost: "hiint.app", workspace: "d") == nil)
    }

    @Test func aStoreKeepsTheClaimTokenItWasGiven() {
        let saved = SavedClaimTokens()
        let store = ClaimTokenStore(read: { saved.token(for: $0) }, save: { saved.keep($1, for: $0) })
        #expect(store.read("hiint.app/driftnote/user-42") == nil)
        store.save("hiint.app/driftnote/user-42", "tok")
        #expect(store.read("hiint.app/driftnote/user-42") == "tok")
        #expect(store.read("hiint.app/driftnote/user-43") == nil)
    }

    @Test func signOutPostsTheBoardCookieWithAnOrigin() throws {
        let request = try #require(
            signOutRequest(boardAddress: board, cookies: [(name: "__Host-hiint_app_session", value: "token.sig")]))
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://driftnote.hiint.app/api/board/sign-out")
        #expect(request.value(forHTTPHeaderField: "Origin") == "https://driftnote.hiint.app")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "__Host-hiint_app_session=token.sig")
        #expect(request.httpShouldHandleCookies == false)
        #expect(signOutRequest(boardAddress: board, cookies: []) == nil)
    }
}

/// An in-memory stand-in for the Keychain.
private final class SavedClaimTokens: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [String: String] = [:]

    func token(for account: String) -> String? { lock.withLock { tokens[account] } }
    func keep(_ token: String, for account: String) { lock.withLock { tokens[account] = token } }
}
