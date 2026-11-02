import Foundation
import Testing

@testable import Hiint

struct BridgeMessageTests {
    @Test(arguments: [
        (#"{"v":1,"type":"ready"}"#, BridgeMessage.ready),
        (#"{"v":1,"type":"openExternal","url":"https://example.com/a"}"#, .openExternal(URL(string: "https://example.com/a")!)),
        (#"{"v":1,"type":"signIn","provider":"google","returnPath":"/p/x"}"#, .signIn(provider: "google", returnPath: "/p/x")),
        (#"{"v":1,"type":"unreadUpdates","count":0}"#, .unreadUpdates(count: 0)),
        (#"{"v":2,"type":"attachScreenshot","image":"…"}"#, .unknown(type: "attachScreenshot")),
    ])
    func decodesEachMessage(json: String, expected: BridgeMessage) {
        #expect(BridgeMessage(json: Data(json.utf8)) == expected)
    }

    @Test func readsTheObjectWebKitHandsOver() {
        let body: [String: Any] = ["v": 1, "type": "signIn", "provider": "google"]
        #expect(BridgeMessage(body: body) == .signIn(provider: "google", returnPath: "/"))
        #expect(BridgeMessage(body: #"{"type":"ready"}"#) == .ready)
    }

    @Test func refusesMessagesItCantUse() {
        #expect(BridgeMessage(json: Data(#"{"v":1,"type":"openExternal"}"#.utf8)) == nil)
        #expect(BridgeMessage(json: Data(#"{"v":1,"type":"signIn"}"#.utf8)) == nil)
        #expect(BridgeMessage(json: Data(#"{"v":1}"#.utf8)) == nil)
        #expect(BridgeMessage(body: 42) == nil)
    }
}
