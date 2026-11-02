# Changelog

Versions follow [semantic versioning](https://semver.org), and each release is a tag of the same name (`0.1.0`, no `v`).

## 0.1.0 (2 November 2026)

The first version, with normal sign-in.

- `Hiint.setup(workspace:)`, `identify`, `logout`.
- `showFeedback(board:)`, `showRoadmap()`, `showUpdates()` and `showRequest(slug:)`, as a sheet (or a medium sheet) on iOS and a window on macOS.
- `HiintFeedbackView` and the `.hiintFeedback(isPresented:board:)` modifier for SwiftUI.
- `feedbackURL(board:)`, `roadmapURL()` and `updatesURL()` for your own web view.
- `unreadUpdatesCount()` for a "What's new" badge.
- Signing in works as on the board in a phone's browser; Continue with Google and Continue with GitHub open the system sign-in sheet, since Google doesn't allow sign-in inside an app's web view and GitHub's sign-in pages are off the board.
