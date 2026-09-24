import Foundation
import Security

// The extension reads this at midnight while the iPad is locked, so the item is readable after the
// first unlock, and it lives in the App Group's access group so the app and the extension share it.
public struct KeychainSetupFlag: SetupFlagReader {
  public struct Failure: Error, Equatable {
    public let status: OSStatus
  }

  private let accessGroup: String
  private let add: (CFDictionary) -> OSStatus
  private let copyMatching: (CFDictionary) -> OSStatus

  public init(accessGroup: String) {
    self.init(accessGroup: accessGroup, add: { SecItemAdd($0, nil) }, copyMatching: { SecItemCopyMatching($0, nil) })
  }

  init(accessGroup: String, add: @escaping (CFDictionary) -> OSStatus, copyMatching: @escaping (CFDictionary) -> OSStatus) {
    self.accessGroup = accessGroup
    self.add = add
    self.copyMatching = copyMatching
  }

  public func read() -> SetupFlag {
    var query = item
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    switch copyMatching(query as CFDictionary) {
    case errSecSuccess: return .completed
    case errSecItemNotFound: return .absent
    default: return .unreadable
    }
  }

  public func recordCompleted() throws {
    var attributes = item
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    attributes[kSecValueData as String] = Data("completed".utf8)

    let status = add(attributes as CFDictionary)
    guard status == errSecSuccess || status == errSecDuplicateItem else { throw Failure(status: status) }
  }

  private var item: [String: Any] {
    [
      kSecAttrAccessGroup as String: accessGroup,
      kSecAttrAccount as String: "setup-completed",
      kSecAttrService as String: "gate",
      kSecClass as String: kSecClassGenericPassword
    ]
  }
}
