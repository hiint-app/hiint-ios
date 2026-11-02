import Foundation

/** The handler name the board posts to: `window.webkit.messageHandlers.hiint`. */
let bridgeHandlerName = "hiint"

/** A message from the board page to the SDK. Types this version doesn't know arrive as `unknown` and are ignored. */
enum BridgeMessage: Equatable, Sendable {
    case ready
    case openExternal(URL)
    case signIn(provider: String, returnPath: String)
    case unreadUpdates(count: Int)
    case unknown(type: String)

    /** Reads a `WKScriptMessage` body: the object the page posted, or the same as a JSON string. */
    init?(body: Any) {
        let data: Data?
        if let text = body as? String {
            data = text.data(using: .utf8)
        } else if JSONSerialization.isValidJSONObject(body) {
            data = try? JSONSerialization.data(withJSONObject: body)
        } else {
            data = nil
        }
        guard let data, let message = BridgeMessage(json: data) else { return nil }
        self = message
    }

    init?(json: Data) {
        guard let raw = try? JSONDecoder().decode(RawBridgeMessage.self, from: json) else { return nil }
        switch raw.type {
        case "ready":
            self = .ready
        case "openExternal":
            guard let url = raw.url.flatMap(URL.init(string:)) else { return nil }
            self = .openExternal(url)
        case "signIn":
            guard let provider = raw.provider else { return nil }
            self = .signIn(provider: provider, returnPath: raw.returnPath ?? "/")
        case "unreadUpdates":
            self = .unreadUpdates(count: raw.count ?? 0)
        default:
            self = .unknown(type: raw.type)
        }
    }
}

private struct RawBridgeMessage: Decodable {
    let v: Int?
    let type: String
    let url: String?
    let provider: String?
    let returnPath: String?
    let count: Int?
}
