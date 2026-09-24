import Foundation
import Security

protocol Keychain {
  func read(_ account: String) throws -> Data?
  func write(_ data: Data, to account: String) throws
}

struct SystemKeychain: Keychain {
  struct Failure: Error, Equatable {
    let status: OSStatus
  }

  let service: String

  func read(_ account: String) throws -> Data? {
    var query = item(account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw Failure(status: status) }
    return result as? Data
  }

  func write(_ data: Data, to account: String) throws {
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    var status = SecItemUpdate(item(account) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(item(account).merging(attributes) { $1 } as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw Failure(status: status) }
  }

  private func item(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
