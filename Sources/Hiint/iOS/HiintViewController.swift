#if canImport(UIKit)
    import UIKit

    /** The board in a sheet: a spinner until the board's address is known and the page has drawn, then a fade in. */
    @MainActor
    final class HiintViewController: UIViewController {
        private let loadDestination: @MainActor () async -> BoardDestination?
        private let board = BoardWebView()
        private let spinner = UIActivityIndicatorView(style: .medium)
        private let failureLabel = UILabel()

        init(loadDestination: @escaping @MainActor () async -> BoardDestination?) {
            self.loadDestination = loadDestination
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground

            let webView = board.webView
            webView.frame = view.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.isOpaque = false
            webView.backgroundColor = .systemBackground
            webView.scrollView.backgroundColor = .systemBackground
            webView.underPageBackgroundColor = .systemBackground
            webView.alpha = 0
            view.addSubview(webView)

            failureLabel.text = "Couldn't load feedback. Check your connection and try again."
            failureLabel.textColor = .secondaryLabel
            failureLabel.font = .preferredFont(forTextStyle: .body)
            failureLabel.adjustsFontForContentSizeCategory = true
            failureLabel.numberOfLines = 0
            failureLabel.textAlignment = .center
            failureLabel.isHidden = true

            for subview in [spinner, failureLabel] as [UIView] {
                subview.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(subview)
            }
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                failureLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                failureLabel.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
                failureLabel.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            ])
            spinner.startAnimating()

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
            spinner.stopAnimating()
            UIView.animate(withDuration: 0.2) { self.board.webView.alpha = 1 }
        }

        private func showFailure() {
            spinner.stopAnimating()
            board.webView.alpha = 0
            failureLabel.isHidden = false
        }
    }

    /** Presents the board as a sheet over whatever the app is showing. */
    @MainActor
    enum BoardPresenter {
        static func present(_ section: BoardSection, style: HiintPresentationStyle) {
            guard let presenter = topViewController() else {
                warn("There's no window to show the board in yet. Show it after your app's first screen appears.")
                return
            }
            let controller = HiintViewController { await HiintClient.shared.destination(for: section) }
            controller.modalPresentationStyle = .pageSheet
            if let sheet = controller.sheetPresentationController {
                sheet.detents = style == .mediumSheet ? [.medium(), .large()] : [.large()]
                sheet.prefersGrabberVisible = true
            }
            presenter.present(controller, animated: true)
        }

        private static func topViewController() -> UIViewController? {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows)
            var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }
    }
#endif
