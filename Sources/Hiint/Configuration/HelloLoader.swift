import Foundation

/**
 * Fetches `hello` once per launch and keeps the last copy on disk, so a later launch can open the board
 * straight away while a fresh copy loads. A failed fetch is tried again by the next caller.
 */
@MainActor
final class HelloLoader {
    let workspace: String
    private let requestURL: URL?
    private let defaults: UserDefaults
    private var request: Task<Hello?, Never>?
    private var isFresh = false
    private(set) var hello: Hello?

    private var cacheKey: String { "hiint.hello.\(workspace)" }

    init(workspace: String, serverURL: URL, defaults: UserDefaults = .standard) {
        self.workspace = workspace
        self.requestURL = ServerAddresses.helloURL(serverURL: serverURL, workspace: workspace)
        self.defaults = defaults
        self.hello = defaults.data(forKey: "hiint.hello.\(workspace)").flatMap { try? Hello.decode($0) }
    }

    func refresh() {
        if request == nil { request = startRequest() }
    }

    func load() async -> Hello? {
        if let hello {
            if !isFresh { refresh() }
            return hello
        }
        let pending = request ?? startRequest()
        request = pending
        return await pending.value
    }

    private func startRequest() -> Task<Hello?, Never> {
        Task {
            let fetched = await HelloLoader.fetch(from: requestURL, workspace: workspace)
            request = nil
            if let fetched {
                hello = fetched
                isFresh = true
                if let data = try? fetched.encoded() { defaults.set(data, forKey: cacheKey) }
            }
            return hello
        }
    }

    nonisolated private static func fetch(from url: URL?, workspace: String) async -> Hello? {
        guard let url else {
            warn("\"\(workspace)\" can't be part of an address. Pass your workspace's slug to Hiint.setup(workspace:).")
            return nil
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                warn(
                    status == 404
                        ? "No hiint workspace is called \"\(workspace)\". Check the slug passed to Hiint.setup(workspace:)."
                        : "Couldn't load the board's details (HTTP \(status)).")
                return nil
            }
            return try Hello.decode(data)
        } catch {
            warn("Couldn't load the board's details: \(error.localizedDescription)")
            return nil
        }
    }
}
