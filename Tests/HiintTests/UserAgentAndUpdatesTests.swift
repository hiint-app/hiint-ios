import Foundation
import Testing

@testable import Hiint

struct SDKUserAgentTests {
    @Test func writesTheFormatHiintParses() {
        let userAgent = SDKUserAgent(sdkVersion: "0.1.0", device: "iPhone", osName: "iOS", osVersion: "26.1", appVersion: "3.4")
        #expect(userAgent.text == "HiintSDK/0.1.0 (iPhone; iOS 26.1; AppVersion/3.4)")
    }

    @Test func keepsAnAwkwardAppVersionFromBreakingTheFormat() {
        let userAgent = SDKUserAgent(
            sdkVersion: "0.1.0", device: "Mac", osName: "macOS", osVersion: "26.1",
            appVersion: "3.4 (build 12); beta/2 with a very long suffix indeed")
        #expect(userAgent.text == "HiintSDK/0.1.0 (Mac; macOS 26.1; AppVersion/3.4 build 12 beta2 with a very l)")
        let endsInASpace = SDKUserAgent(
            sdkVersion: "0.1.0", device: "iPhone", osName: "iOS", osVersion: "26", appVersion: "3.4 build 12 beta2 with a very  x")
        #expect(endsInASpace.text.hasSuffix("AppVersion/3.4 build 12 beta2 with a very)"))
        let empty = SDKUserAgent(sdkVersion: "0.1.0", device: "iPhone", osName: "iOS", osVersion: "26", appVersion: "()")
        #expect(empty.text.hasSuffix("AppVersion/unknown)"))
    }

    @Test func addsToTheWebViewsOwnNameRatherThanReplacingIt() {
        let userAgent = SDKUserAgent(sdkVersion: "0.1.0", device: "iPhone", osName: "iOS", osVersion: "26.1", appVersion: "3.4")
        #expect(
            userAgentApplicationName(base: "Mobile/15E148", sdk: userAgent)
                == "Mobile/15E148 HiintSDK/0.1.0 (iPhone; iOS 26.1; AppVersion/3.4)")
        #expect(userAgentApplicationName(base: nil, sdk: userAgent) == userAgent.text)
    }
}

struct UnreadUpdatesTests {
    let lastOpened = Date(timeIntervalSince1970: 1_000)

    @Test func countsOnlyWhatWasPublishedSince() {
        let recent = [Date(timeIntervalSince1970: 3_000), Date(timeIntervalSince1970: 2_000), lastOpened, Date(timeIntervalSince1970: 500)]
        #expect(unreadUpdateCount(recentUpdates: recent, lastOpened: lastOpened) == 2)
        #expect(unreadUpdateCount(recentUpdates: [], lastOpened: lastOpened) == 0)
    }

    @MainActor
    @Test func remembersWhenUpdatesWasOpenedPerWorkspace() throws {
        let suiteName = "hiint-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UpdatesOpenedStore(defaults: defaults)
        #expect(store.lastOpened(workspace: "driftnote") == nil)
        store.markOpened(workspace: "driftnote", at: lastOpened)
        #expect(store.lastOpened(workspace: "driftnote") == lastOpened)
        #expect(store.lastOpened(workspace: "pica") == nil)
    }
}
