import Foundation

/** What an identify says about payment: nothing (hiint keeps what it had), or a status, where `nil` clears it. */
enum PaymentStatusUpdate: Equatable, Sendable {
    case unchanged
    case set(Bool?)
}

/** Who the app says is signed in, as `POST /api/sdk/v1/<workspace>/identify` sends it. */
struct IdentifyCall: Equatable, Sendable {
    var userId: String
    var email: String
    var name: String
    var avatarURL: String
    var signature: String
    var claimToken: String
    var challenge: String
    var paymentStatus: PaymentStatusUpdate = .unchanged
}

/** What that call came back with. `automaticLoginOff` is remembered until the next `setup`. */
enum IdentifyResult: Equatable, Sendable {
    case signedIn(code: String, claimToken: String?)
    case automaticLoginOff
    case refused(reason: String)
    case unreadable
}

func identifyRequest(serverURL: URL, workspace: String, call: IdentifyCall) -> URLRequest? {
    guard let url = ServerAddresses.identifyURL(serverURL: serverURL, workspace: workspace) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = identifyBody(call)
    return request
}

func identifyBody(_ call: IdentifyCall) -> Data {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let body = IdentifyBody(
        userId: call.userId, email: call.email, name: call.name, avatarUrl: call.avatarURL, signature: call.signature,
        claimToken: call.claimToken, challenge: call.challenge, paymentStatus: call.paymentStatus)
    return (try? encoder.encode(body)) ?? Data()
}

func identifyResult(status: Int, body: Data) -> IdentifyResult {
    if (200..<300).contains(status) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let signedIn = try? decoder.decode(SignedInBody.self, from: body), !signedIn.code.isEmpty else {
            return .unreadable
        }
        return .signedIn(code: signedIn.code, claimToken: signedIn.claimToken)
    }
    let reason = (try? JSONDecoder().decode(RefusalBody.self, from: body))?.error.details?.reason ?? ""
    if status == 403, reason == "automatic_login_off" { return .automaticLoginOff }
    return .refused(reason: reason.isEmpty ? "HTTP \(status)" : reason)
}

/** The web view loads this on the board's own host; it sets the app session and continues to `returnPath`. */
func appSessionURL(boardAddress: URL, code: String, verifier: String, returnPath: String) -> URL? {
    hiintAddress(
        on: boardAddress, path: "/api/board/app-session",
        query: percentEncodedQuery(["code": code, "verifier": verifier, "return": returnPath]))
}

/** The path and query of a board page, which is all `return` is allowed to be. */
func boardReturnPath(of pageURL: URL) -> String {
    let path = pageURL.path.isEmpty ? "/" : pageURL.path
    guard let query = pageURL.query, !query.isEmpty else { return path }
    return "\(path)?\(query)"
}

/// The Keychain account for one app user on one workspace: `<server host>/<slug>/<user id>`.
func claimTokenAccount(serverHost: String, workspace: String, userId: String) -> String {
    "\(serverHost.lowercased())/\(workspace)/\(userId)"
}

/// Only an unsigned identity has a claim token: a signature already proves who it is.
func unsignedClaimAccount(userId: String, signature: String, serverHost: String, workspace: String) -> String? {
    guard !userId.isEmpty, signature.isEmpty else { return nil }
    return claimTokenAccount(serverHost: serverHost, workspace: workspace, userId: userId)
}

func signOutRequest(boardAddress: URL, cookies: [(name: String, value: String)]) -> URLRequest? {
    guard !cookies.isEmpty, let url = hiintAddress(on: boardAddress, path: "/api/board/sign-out"),
        let origin = URLComponents(url: boardAddress, resolvingAgainstBaseURL: false).map({
            "\($0.scheme ?? "https")://\($0.host ?? "")\($0.port.map { ":\($0)" } ?? "")"
        })
    else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    // The board's cookie is sent as given, not mixed with URLSession's own cookie store.
    request.httpShouldHandleCookies = false
    request.setValue(origin, forHTTPHeaderField: "Origin")
    request.setValue(cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
    return request
}

private struct IdentifyBody: Encodable {
    let userId: String
    let email: String
    let name: String
    let avatarUrl: String
    let signature: String
    let claimToken: String
    let challenge: String
    let paymentStatus: PaymentStatusUpdate

    private enum CodingKeys: String, CodingKey {
        case userId, email, name, avatarUrl, signature, claimToken, challenge, isPaying
    }

    /// `is_paying` is left out when unchanged and written as `null` when cleared, since hiint treats the two differently.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(email, forKey: .email)
        try container.encode(name, forKey: .name)
        try container.encode(avatarUrl, forKey: .avatarUrl)
        try container.encode(signature, forKey: .signature)
        try container.encode(claimToken, forKey: .claimToken)
        try container.encode(challenge, forKey: .challenge)
        switch paymentStatus {
        case .unchanged:
            break
        case .set(let isPaying?):
            try container.encode(isPaying, forKey: .isPaying)
        case .set(nil):
            try container.encodeNil(forKey: .isPaying)
        }
    }
}

private struct SignedInBody: Decodable {
    let code: String
    let claimToken: String?
}

private struct RefusalBody: Decodable {
    struct ErrorBody: Decodable {
        struct Details: Decodable {
            let reason: String?
        }
        let details: Details?
    }
    let error: ErrorBody
}

