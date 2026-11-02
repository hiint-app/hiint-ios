import CryptoKit
import Foundation

/**
 * A one-time secret for a sign-in (the PKCE pattern): hiint is given only the challenge, and the code it sends
 * back can only be swapped for a session by whoever also holds the verifier.
 */
struct SignInChallenge: Equatable, Sendable {
    let verifier: String
    let challenge: String

    init() {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        self.init(verifier: base64URLEncoded(Data(bytes)))
    }

    init(verifier: String) {
        self.verifier = verifier
        self.challenge = base64URLEncoded(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
}

/** Base64 with `-` and `_` for `+` and `/`, and no `=` padding, so it needs no escaping in a URL. */
func base64URLEncoded(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
