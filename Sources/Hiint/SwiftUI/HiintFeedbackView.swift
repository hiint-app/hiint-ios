import SwiftUI

/** The feedback board as a SwiftUI view, to place inline or in your own sheet. Shows a spinner until it's ready. */
public struct HiintFeedbackView: View {
    private let board: String?

    public init(board: String? = nil) {
        self.board = board
    }

    public var body: some View {
        BoardContainer(section: .feedback(board: board))
    }
}

extension View {
    /// Presents the feedback board as a sheet while `isPresented` is true.
    public func hiintFeedback(isPresented: Binding<Bool>, board: String? = nil) -> some View {
        sheet(isPresented: isPresented) {
            HiintFeedbackView(board: board)
                #if os(macOS)
                    .frame(minWidth: 420, idealWidth: 896, minHeight: 560, idealHeight: 720)
                #endif
        }
    }
}

#if canImport(UIKit)
    private struct BoardContainer: UIViewControllerRepresentable {
        let section: BoardSection

        func makeUIViewController(context: Context) -> HiintViewController {
            HiintViewController { await HiintClient.shared.destination(for: section) }
        }

        func updateUIViewController(_ controller: HiintViewController, context: Context) {}
    }
#elseif os(macOS)
    private struct BoardContainer: NSViewControllerRepresentable {
        let section: BoardSection

        func makeNSViewController(context: Context) -> HiintMacViewController {
            HiintMacViewController { await HiintClient.shared.destination(for: section) }
        }

        func updateNSViewController(_ controller: HiintMacViewController, context: Context) {}
    }
#endif
