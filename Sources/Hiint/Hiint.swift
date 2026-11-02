import Foundation

/** How the board is presented on iOS. On macOS it always opens in its own window. */
public enum HiintPresentationStyle: Sendable {
    /// A full-height sheet.
    case sheet
    /// A half-height sheet that can be dragged to full height.
    case mediumSheet
}

/** Shows your hiint workspace's feedback board, roadmap and updates inside your app. */
@MainActor
public enum Hiint {
    /// This SDK's version, sent to hiint in the web view's user agent.
    nonisolated public static let version = "0.2.0"

    /// hiint's own address. Only change it to point at a local hiint while developing.
    nonisolated public static let defaultServerURL = URL(string: "https://hiint.app")!

    /// Call once at launch with your workspace's slug, the `driftnote` in `driftnote.hiint.app`.
    public static func setup(workspace: String, serverURL: URL = defaultServerURL) {
        HiintClient.shared.setup(workspace: workspace, server: serverURL)
    }

    /// Tells hiint who is using the app. Pass `signature` from your server, or leave it out and the install keeps a claim token.
    public static func identify(
        userId: String, email: String? = nil, name: String? = nil, avatarURL: URL? = nil, signature: String? = nil
    ) {
        HiintClient.shared.identify(
            userId: userId, email: email, name: name, avatarURL: avatarURL, signature: signature)
    }

    /// Forgets the identified user and signs the board out on this device. Call it when they log out of your app.
    public static func logout() {
        HiintClient.shared.logout()
    }

    /// Shows the feedback board, or one board by its slug.
    public static func showFeedback(board: String? = nil, style: HiintPresentationStyle = .sheet) {
        show(.feedback(board: board), style: style)
    }

    /// Shows the roadmap.
    public static func showRoadmap(style: HiintPresentationStyle = .sheet) {
        show(.roadmap, style: style)
    }

    /// Shows the updates (the changelog) and clears the unread count.
    public static func showUpdates(style: HiintPresentationStyle = .sheet) {
        show(.updates, style: style)
    }

    /// Shows one request by its slug, for links from a push notification or an email.
    public static func showRequest(slug: String, style: HiintPresentationStyle = .sheet) {
        show(.request(slug: slug), style: style)
    }

    /// The feedback board's address, for showing it in your own web view. `nil` until the board's details have loaded.
    /// With automatic login it signs the person in, so load it straight away: it works once, within 60 seconds.
    public static func feedbackURL(board: String? = nil) async -> URL? {
        await HiintClient.shared.destination(for: .feedback(board: board))?.pageURL
    }

    /// The roadmap's address, for showing it in your own web view. With automatic login, load it straight away (see `feedbackURL`).
    public static func roadmapURL() async -> URL? {
        await HiintClient.shared.destination(for: .roadmap)?.pageURL
    }

    /// The updates' address, for showing it in your own web view. With automatic login, load it straight away (see `feedbackURL`).
    public static func updatesURL() async -> URL? {
        await HiintClient.shared.destination(for: .updates)?.pageURL
    }

    /// How many updates were published since this person last opened Updates, for a badge on your own button.
    public static func unreadUpdatesCount() async -> Int {
        await HiintClient.shared.unreadUpdatesCount()
    }

    private static func show(_ section: BoardSection, style: HiintPresentationStyle) {
        guard HiintClient.shared.workspace != nil else {
            warn("Call Hiint.setup(workspace:) before showing the board.")
            return
        }
        if section == .updates { HiintClient.shared.markUpdatesOpened() }
        BoardPresenter.present(section, style: style)
    }
}
