import Foundation
import Testing

@testable import Hiint

struct HelloTests {
    @Test func decodesTheContractAndIgnoresUnknownFields() throws {
        let hello = try makeHello()
        #expect(hello.v == 1)
        #expect(hello.workspace.slug == "driftnote")
        #expect(hello.workspace.brandColour == "#3e63dd")
        #expect(hello.workspace.logoUrl?.absoluteString == "https://files.hiint.app/workspaces/1/logo/a.png")
        #expect(hello.boardUrl.absoluteString == "https://feedback.driftnote.app")
        #expect(hello.sections == Hello.Sections(roadmap: true, changelog: false))
        #expect(hello.boards.map(\.slug) == ["ideas", "bugs"])
    }

    @Test func readsDatesWithAndWithoutFractionalSeconds() throws {
        let hello = try makeHello()
        #expect(hello.recentUpdates == [parseInternetDate("2026-11-01T09:12:00Z"), parseInternetDate("2026-10-28T16:40:00Z")])
        #expect(hello.recentUpdates[0].timeIntervalSince1970 == 1_793_524_320)
    }

    @Test func survivesTheDiskCacheRoundTrip() throws {
        let hello = try makeHello()
        #expect(try Hello.decode(hello.encoded()) == hello)
    }

    @Test func toleratesAMissingLogoAndColour() throws {
        let json = """
            {"v":1,"workspace":{"slug":"a","name":"A","logo_url":null},"board_url":"https://a.hiint.app",
             "sections":{"roadmap":false,"changelog":false},"boards":[],"recent_updates":[]}
            """
        let hello = try Hello.decode(Data(json.utf8))
        #expect(hello.workspace.logoUrl == nil)
        #expect(hello.workspace.brandColour == nil)
    }

    @Test func rejectsAnUnreadableDate() {
        let json = """
            {"v":1,"workspace":{"slug":"a","name":"A"},"board_url":"https://a.hiint.app",
             "sections":{"roadmap":true,"changelog":true},"boards":[],"recent_updates":["yesterday"]}
            """
        #expect(throws: DecodingError.self) { try Hello.decode(Data(json.utf8)) }
    }
}
