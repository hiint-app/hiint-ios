import Foundation

/** A page of the public board the SDK can open. The paths match hiint's board routes. */
enum BoardSection: Equatable, Sendable {
    case feedback(board: String?)
    case roadmap
    case updates
    case request(slug: String)
}

/** The page to open for a section, on the board's own address (its free subdomain or its custom domain). */
func boardURL(boardAddress: URL, section: BoardSection) -> URL? {
    guard var components = URLComponents(url: boardAddress, resolvingAgainstBaseURL: false) else {
        return nil
    }
    components.percentEncodedQuery = nil
    components.fragment = nil
    switch section {
    case .feedback(let board):
        components.percentEncodedPath = "/"
        if let board { components.percentEncodedQuery = percentEncodedQuery(["board": board]) }
    case .roadmap:
        components.percentEncodedPath = "/roadmap"
    case .updates:
        components.percentEncodedPath = "/changelog"
    case .request(let slug):
        components.percentEncodedPath = "/p/\(percentEncoded(slug))"
    }
    return components.url
}

/** The section to actually open, falling back to the feedback board when the requested one is hidden or unknown. */
func availableSection(_ requested: BoardSection, hello: Hello) -> (section: BoardSection, problem: String?) {
    switch requested {
    case .roadmap where !hello.sections.roadmap:
        return (.feedback(board: nil), "\(hello.workspace.name)'s roadmap is hidden, so the feedback board opened instead.")
    case .updates where !hello.sections.changelog:
        return (.feedback(board: nil), "\(hello.workspace.name)'s updates are hidden, so the feedback board opened instead.")
    case .feedback(let board?) where !hello.boards.contains(where: { $0.slug == board }):
        return (.feedback(board: nil), "There's no public board called \"\(board)\", so every board opened instead.")
    default:
        return (requested, nil)
    }
}
