import Foundation

/** How many of the board's recent updates were published after Updates was last opened on this device. */
func unreadUpdateCount(recentUpdates: [Date], lastOpened: Date) -> Int {
    recentUpdates.filter { $0 > lastOpened }.count
}

/** When Updates was last opened, per workspace, on this device only. */
@MainActor
final class UpdatesOpenedStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastOpened(workspace: String) -> Date? {
        defaults.object(forKey: key(workspace)) as? Date
    }

    func markOpened(workspace: String, at date: Date = Date()) {
        defaults.set(date, forKey: key(workspace))
    }

    private func key(_ workspace: String) -> String { "hiint.updatesOpenedAt.\(workspace)" }
}
