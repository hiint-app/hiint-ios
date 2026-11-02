import Foundation
import Security

/// Claim tokens live in the Keychain under this service, synced through iCloud and kept after logout.
let claimTokenService = "app.hiint.claim"

/// Where claim tokens are kept: the Keychain in the app, a dictionary in tests.
struct ClaimTokenStore: Sendable {
    var read: @Sendable (_ account: String) -> String?
    var save: @Sendable (_ account: String, _ token: String) -> Void

    static let keychain = ClaimTokenStore(read: readClaimToken(account:), save: saveClaimToken(account:token:))
}

func readClaimToken(account: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: claimTokenService,
        kSecAttrAccount as String: account,
        kSecAttrSynchronizable as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

func saveClaimToken(account: String, token: String) {
    guard let data = token.data(using: .utf8) else { return }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: claimTokenService,
        kSecAttrAccount as String: account,
        kSecAttrSynchronizable as String: true,
    ]
    let updated: [String: Any] = [kSecValueData as String: data]
    if SecItemUpdate(query as CFDictionary, updated as CFDictionary) == errSecSuccess { return }
    var insert = query
    insert[kSecValueData as String] = data
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(insert as CFDictionary, nil)
}
