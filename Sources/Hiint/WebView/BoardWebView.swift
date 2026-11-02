import AuthenticationServices
import WebKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/**
 * The web view behind the iOS sheet and the macOS window: it loads the board, keeps navigation on the board,
 * answers the page's bridge messages and runs Google sign-in in the system sheet.
 */
@MainActor
final class BoardWebView: NSObject {
    let webView: WKWebView
    var onReveal: (() -> Void)?
    var onLoadFailure: (() -> Void)?

    private var destination: BoardDestination?
    private var signIn: SignInCoordinator?
    private var hasRevealed = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = userAgentApplicationName(
            base: configuration.applicationNameForUserAgent, sdk: .current())
        #if canImport(UIKit)
            configuration.allowsInlineMediaPlayback = true
        #endif
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.configuration.userContentController.add(
            WeakScriptMessageHandler(target: self), name: bridgeHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func load(_ destination: BoardDestination) {
        self.destination = destination
        webView.load(URLRequest(url: destination.pageURL))
        // Fades in even if the page never says it's ready (an older board, or a slow script).
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.reveal()
        }
    }

    fileprivate func handle(_ message: BridgeMessage) {
        switch message {
        case .ready:
            reveal()
        case .openExternal(let url):
            openExternally(url)
        case .signIn(let provider, let returnPath):
            startSignIn(provider: provider, returnPath: returnPath)
        case .unreadUpdates:
            HiintClient.shared.markUpdatesOpened()
        case .unknown:
            break
        }
    }

    private func reveal() {
        guard !hasRevealed else { return }
        hasRevealed = true
        onReveal?()
    }

    private func decision(for url: URL, isMainFrame: Bool) -> NavigationDecision {
        guard let destination else { return .allow }
        return navigationDecision(
            for: url, boardAddress: destination.boardAddress, server: destination.server, isMainFrame: isMainFrame)
    }

    private func openExternally(_ url: URL) {
        #if canImport(UIKit)
            UIApplication.shared.open(url)
        #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
        #endif
    }

    private func startSignIn(provider: String, returnPath: String) {
        guard let destination, signIn == nil, let anchor = webView.window else { return }
        let challenge = SignInChallenge()
        guard
            let signInURL = ServerAddresses.signInURL(
                serverURL: destination.server, provider: provider, workspace: destination.workspace,
                returnPath: returnPath, challenge: challenge.challenge, email: destination.email)
        else { return }
        let coordinator = SignInCoordinator()
        signIn = coordinator
        coordinator.start(url: signInURL, anchor: anchor) { [weak self] outcome in
            guard let self else { return }
            signIn = nil
            switch outcome {
            case .signedIn(let code):
                if let sessionURL = ServerAddresses.sessionURL(
                    serverURL: destination.server, code: code, verifier: challenge.verifier)
                {
                    webView.load(URLRequest(url: sessionURL))
                }
            case .cancelled:
                break
            case .failed(let reason):
                warn("Sign-in didn't finish: \(reason).")
            }
        }
    }
}

extension BoardWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async
        -> WKNavigationActionPolicy
    {
        guard let url = navigationAction.request.url else { return .allow }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        switch decision(for: url, isMainFrame: isMainFrame) {
        case .allow:
            return .allow
        case .openExternally:
            openExternally(url)
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reveal()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        if !isCancellation(error) { onLoadFailure?() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        if !isCancellation(error) { onLoadFailure?() }
    }

    /** A navigation the SDK cancelled itself (sent to the system browser) or replaced with another isn't a failure. */
    private func isCancellation(_ error: any Error) -> Bool {
        let error = error as NSError
        let frameLoadInterruptedByPolicyChange = 102
        return (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && error.code == frameLoadInterruptedByPolicyChange)
    }
}

extension BoardWebView: WKUIDelegate {
    /** Links that open a new tab on the web (`target="_blank"`) open on the board or in the system browser instead. */
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        switch decision(for: url, isMainFrame: true) {
        case .allow: webView.load(URLRequest(url: url))
        case .openExternally: openExternally(url)
        }
        return nil
    }
}

/** The content controller keeps its handlers alive, so this holds the web view weakly to avoid a retain cycle. */
@MainActor
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: BoardWebView?

    init(target: BoardWebView) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let bridgeMessage = BridgeMessage(body: message.body) else { return }
        target?.handle(bridgeMessage)
    }
}
