# hiint for iOS and macOS

Show your [hiint](https://hiint.app) feedback board, roadmap and updates inside your app. Your users post ideas and bugs, vote and comment without leaving it, and you triage everything in your hiint dashboard as usual.

The board appears exactly as it does in a phone's browser, in a sheet on iOS and in its own window on macOS. Every improvement to your board reaches your app without an SDK update.

## Requirements

- iOS 15 or later, macOS 12 or later
- Xcode 16 or later (Swift 6)

## Installation

In Xcode, choose **File → Add Package Dependencies…**, enter `https://github.com/hiint-app/hiint-ios` and add the **Hiint** library to your app.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/hiint-app/hiint-ios", from: "0.3.0")
]
```

## Setting up

Call `setup` once at launch with your workspace's slug, the `driftnote` in `driftnote.hiint.app`:

```swift
import Hiint

@main
struct DriftnoteApp: App {
    init() {
        Hiint.setup(workspace: "driftnote")
    }

    var body: some Scene { WindowGroup { ContentView() } }
}
```

`setup` loads your board's details in the background and never blocks your launch.

## Showing the board

```swift
Hiint.showFeedback()                     // every board
Hiint.showFeedback(board: "bugs")        // one board, by its slug
Hiint.showRoadmap()
Hiint.showUpdates()                      // your changelog
Hiint.showRequest(slug: "dark-mode")     // one request, from a push or an email link
```

On iOS the board slides up as a sheet. Pass `style: .mediumSheet` for a half-height sheet that can be dragged up. On macOS it opens in a resizable window.

### SwiftUI

```swift
struct SettingsView: View {
    @State private var showingFeedback = false

    var body: some View {
        Button("Send feedback") { showingFeedback = true }
            .hiintFeedback(isPresented: $showingFeedback)
    }
}
```

Or place `HiintFeedbackView()` anywhere in your own layout.

## Signing in

People sign in with their hiint account, exactly as on your board in a phone's browser: email and password, GitHub or Google. Continue with Google and Continue with GitHub open the system's sign-in sheet: Google doesn't allow signing in inside an app's web view, and GitHub's sign-in works best there too. Nothing is needed in your `Info.plist`.

They stay signed in the next time the board opens. When someone logs out of your app, call:

```swift
Hiint.logout()
```

### Telling hiint who's using your app

```swift
Hiint.identify(userId: user.id, email: user.email, name: user.name)
```

With automatic login on (Pro), this signs them straight in the next time the board opens. Only `userId` is required: pass `email` and hiint emails them about their own requests and comments, and `name` (they get a random one without it). If your app has a server, pass the `signature` it makes with your project secret; that's what proves who they are.

Without one, the SDK keeps a claim token for that user ID in the Keychain, so another device can't later sign in as them. `logout()` signs the board out and leaves the claim token in place.

### Telling hiint who pays

```swift
Hiint.identify(userId: user.id, email: user.email, name: user.name, isPaying: user.hasActiveSubscription)
```

Report `true` to mark your customer as paying for your team: a gold Paying badge beside their name and on their requests, seen only by your team in the dashboard and on your board. Your customers never see it, including the customer themselves. `false` or `nil` removes the badge. If they voted while your app reported that they paid, the team's paying-vote count keeps that context after they cancel. New feedback uses the last status your app has sent to hiint.

hiint gets the status the next time the board opens, so call `identify` again whenever it changes. Leaving `isPaying` out (the call above without it) keeps whatever hiint last heard; passing `nil` clears it. It needs automatic login on (Pro).

## A "What's new" badge

```swift
let count = await Hiint.unreadUpdatesCount()
```

It counts the updates published since this person last opened Updates on this device. Show it on your own button or menu row; it resets when they open Updates.

## Your own web view

```swift
if let url = await Hiint.feedbackURL() {
    // load url in your own web view
}
```

`roadmapURL()` and `updatesURL()` work the same way. They return `nil` until the board's details have loaded.

## macOS sandbox

A sandboxed Mac app needs the **Outgoing Connections (Client)** capability (`com.apple.security.network.client`) to load the board.

## Troubleshooting

Everything the SDK reports is printed to the console starting with `[Hiint]`.

- **"No hiint workspace is called …"**: the slug passed to `setup` doesn't match a workspace. Copy it from your board's address.
- **The roadmap or updates open the feedback board instead**: that section is hidden in your workspace's settings.
- **Nothing appears**: `show…` was called before your app had a window. Call it from a button, or after your first screen appears.

## Licence

MIT. See [LICENSE](LICENSE).
