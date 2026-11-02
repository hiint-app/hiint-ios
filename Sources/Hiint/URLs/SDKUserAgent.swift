import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/** What the SDK adds to the web view's user agent, so hiint can tell the app's device, OS and version. */
struct SDKUserAgent: Equatable, Sendable {
    let sdkVersion: String
    let device: String
    let osName: String
    let osVersion: String
    let appVersion: String

    var text: String {
        "HiintSDK/\(field(sdkVersion)) (\(field(device)); \(field(osName)) \(field(osVersion)); AppVersion/\(field(appVersion)))"
    }

    @MainActor
    static func current() -> SDKUserAgent {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion =
            version.patchVersion > 0
            ? "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            : "\(version.majorVersion).\(version.minorVersion)"
        let appVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return SDKUserAgent(
            sdkVersion: Hiint.version, device: currentDevice, osName: currentOSName, osVersion: osVersion,
            appVersion: appVersion)
    }

    @MainActor
    private static var currentDevice: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
            return "Mac"
        #elseif canImport(UIKit)
            return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
            return "unknown"
        #endif
    }

    private static var currentOSName: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
            return "macOS"
        #else
            return "iOS"
        #endif
    }
}

private let userAgentFieldCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .-_")

/** Keeps a field from breaking the format hiint parses: no brackets, semicolons or slashes, at most 32 characters. */
private func field(_ value: String) -> String {
    let kept = String(String.UnicodeScalarView(value.unicodeScalars.filter(userAgentFieldCharacters.contains)))
    let capped = String(kept.trimmingCharacters(in: .whitespaces).prefix(32)).trimmingCharacters(in: .whitespaces)
    return capped.isEmpty ? "unknown" : capped
}

/** The web view's own application name with the SDK's added after it, never in place of it. */
func userAgentApplicationName(base: String?, sdk: SDKUserAgent) -> String {
    [base, sdk.text].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " ")
}
