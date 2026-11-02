import Foundation
import Testing

@testable import Hiint

struct BoardURLTests {
    let subdomain = URL(string: "https://driftnote.hiint.app")!

    @Test(arguments: [
        (BoardSection.feedback(board: nil), "https://driftnote.hiint.app/"),
        (.feedback(board: "ideas"), "https://driftnote.hiint.app/?board=ideas"),
        (.roadmap, "https://driftnote.hiint.app/roadmap"),
        (.updates, "https://driftnote.hiint.app/changelog"),
        (.request(slug: "dark-mode"), "https://driftnote.hiint.app/p/dark-mode"),
    ])
    func buildsEachSection(section: BoardSection, expected: String) {
        #expect(boardURL(boardAddress: subdomain, section: section)?.absoluteString == expected)
    }

    @Test func usesACustomDomainAndDropsAnyPathOrQueryOnTheAddress() {
        let address = URL(string: "https://feedback.driftnote.app/old?x=1#top")!
        #expect(boardURL(boardAddress: address, section: .roadmap)?.absoluteString == "https://feedback.driftnote.app/roadmap")
    }

    @Test func escapesSlugsThatCouldBreakTheAddress() {
        #expect(
            boardURL(boardAddress: subdomain, section: .feedback(board: "a&b"))?.absoluteString
                == "https://driftnote.hiint.app/?board=a%26b")
        #expect(
            boardURL(boardAddress: subdomain, section: .request(slug: "a/b"))?.absoluteString
                == "https://driftnote.hiint.app/p/a%2Fb")
    }

    @Test func keepsAvailableSections() throws {
        let hello = try makeHello()
        #expect(availableSection(.roadmap, hello: hello) == (.roadmap, nil))
        #expect(availableSection(.feedback(board: "bugs"), hello: hello).section == .feedback(board: "bugs"))
        #expect(availableSection(.request(slug: "x"), hello: hello).problem == nil)
    }

    @Test func fallsBackToFeedbackForHiddenSectionsAndUnknownBoards() throws {
        let hello = try makeHello()
        let hiddenUpdates = availableSection(.updates, hello: hello)
        #expect(hiddenUpdates.section == .feedback(board: nil))
        #expect(hiddenUpdates.problem != nil)
        let unknownBoard = availableSection(.feedback(board: "team-only"), hello: hello)
        #expect(unknownBoard.section == .feedback(board: nil))
        #expect(unknownBoard.problem?.contains("team-only") == true)
    }
}
