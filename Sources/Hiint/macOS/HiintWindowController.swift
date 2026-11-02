#if os(macOS)
    import AppKit

    /** The board in a window's content: a spinner until the board's address is known and the page has drawn. */
    @MainActor
    final class HiintMacViewController: NSViewController {
        private let loadDestination: @MainActor () async -> BoardDestination?
        private let board = BoardWebView()
        private let spinner = NSProgressIndicator()
        private let failureLabel = NSTextField(
            wrappingLabelWithString: "Couldn't load feedback. Check your connection and try again.")

        init(loadDestination: @escaping @MainActor () async -> BoardDestination?) {
            self.loadDestination = loadDestination
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 896, height: 720))

            let webView = board.webView
            webView.frame = container.bounds
            webView.autoresizingMask = [.width, .height]
            webView.underPageBackgroundColor = .windowBackgroundColor
            webView.alphaValue = 0
            container.addSubview(webView)

            spinner.style = .spinning
            failureLabel.alignment = .center
            failureLabel.textColor = .secondaryLabelColor
            failureLabel.isHidden = true
            for subview in [spinner, failureLabel] as [NSView] {
                subview.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(subview)
            }
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                failureLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                failureLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                failureLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            ])
            view = container
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            spinner.startAnimation(nil)
            board.onReveal = { [weak self] in self?.reveal() }
            board.onLoadFailure = { [weak self] in self?.showFailure() }
            Task { [weak self] in
                guard let destination = await self?.loadDestination() else {
                    self?.showFailure()
                    return
                }
                self?.board.load(destination)
            }
        }

        private func reveal() {
            spinner.stopAnimation(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                board.webView.animator().alphaValue = 1
            }
        }

        private func showFailure() {
            spinner.stopAnimation(nil)
            board.webView.alphaValue = 0
            failureLabel.isHidden = false
        }
    }

    /** A centred, resizable window holding the board, kept alive until it's closed. */
    @MainActor
    final class HiintWindowController: NSWindowController, NSWindowDelegate {
        private static var openWindows: Set<HiintWindowController> = []

        convenience init(section: BoardSection) {
            let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 896, height: (screenHeight * 0.8).rounded()),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Feedback"
            window.minSize = NSSize(width: 420, height: 560)
            window.isReleasedWhenClosed = false
            window.contentViewController = HiintMacViewController {
                await HiintClient.shared.destination(for: section)
            }
            window.setContentSize(NSSize(width: 896, height: (screenHeight * 0.8).rounded()))
            self.init(window: window)
            window.delegate = self
        }

        func windowWillClose(_ notification: Notification) {
            Self.openWindows.remove(self)
        }

        static func open(_ section: BoardSection) {
            let controller = HiintWindowController(section: section)
            openWindows.insert(controller)
            controller.window?.center()
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    /** On macOS the board always opens in its own window; the presentation style is for iOS sheets. */
    @MainActor
    enum BoardPresenter {
        static func present(_ section: BoardSection, style: HiintPresentationStyle) {
            HiintWindowController.open(section)
        }
    }
#endif
