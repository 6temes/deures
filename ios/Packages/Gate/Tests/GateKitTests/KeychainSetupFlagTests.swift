import Foundation
import Security
import Testing
@testable import GateKit

final class RecordingKeychain {
  var status: OSStatus
  var queries: [[String: Any]] = []

  init(status: OSStatus) {
    self.status = status
  }

  func call(_ query: CFDictionary) -> OSStatus {
    queries.append(query as! [String: Any])
    return status
  }
}

struct KeychainSetupFlagTests {
  let group = "group.org.example.deures"

  func flag(reading keychain: RecordingKeychain) -> KeychainSetupFlag {
    KeychainSetupFlag(accessGroup: group, add: { _ in errSecSuccess }, copyMatching: keychain.call)
  }

  func flag(adding keychain: RecordingKeychain) -> KeychainSetupFlag {
    KeychainSetupFlag(accessGroup: group, add: keychain.call, copyMatching: { _ in errSecSuccess })
  }

  @Test func aFoundItemMeansSetupCompleted() {
    #expect(flag(reading: RecordingKeychain(status: errSecSuccess)).read() == .completed)
  }

  @Test func aMissingItemMeansSetupIsAbsent() {
    #expect(flag(reading: RecordingKeychain(status: errSecItemNotFound)).read() == .absent)
  }

  @Test(arguments: [errSecInteractionNotAllowed, errSecMissingEntitlement, errSecNotAvailable, errSecAuthFailed])
  func anyOtherStatusIsUnreadable(status: OSStatus) {
    #expect(flag(reading: RecordingKeychain(status: status)).read() == .unreadable)
  }

  @Test func readsTheItemInTheAppGroupsAccessGroup() throws {
    let keychain = RecordingKeychain(status: errSecSuccess)

    _ = flag(reading: keychain).read()

    let query = try #require(keychain.queries.first)
    #expect(query[kSecAttrAccessGroup as String] as? String == group)
    #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
  }

  @Test func recordsTheFlagReadableAfterFirstUnlockOnThisDeviceOnly() throws {
    let keychain = RecordingKeychain(status: errSecSuccess)

    try flag(adding: keychain).recordCompleted()

    let item = try #require(keychain.queries.first)
    #expect(item[kSecAttrAccessGroup as String] as? String == group)
    #expect(item[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
  }

  @Test func theWrittenItemIsTheOneThatIsRead() throws {
    let adding = RecordingKeychain(status: errSecSuccess)
    let reading = RecordingKeychain(status: errSecSuccess)

    try flag(adding: adding).recordCompleted()
    _ = flag(reading: reading).read()

    let written = try #require(adding.queries.first)
    let read = try #require(reading.queries.first)
    for key in [kSecAttrAccessGroup, kSecAttrAccount, kSecAttrService, kSecClass] as [CFString] {
      #expect(written[key as String] as? String == read[key as String] as? String)
    }
  }

  @Test func recordingTwiceIsNotAnError() throws {
    try flag(adding: RecordingKeychain(status: errSecDuplicateItem)).recordCompleted()
  }

  @Test func aFailedWriteThrowsItsStatus() {
    #expect(throws: KeychainSetupFlag.Failure(status: errSecInteractionNotAllowed)) {
      try flag(adding: RecordingKeychain(status: errSecInteractionNotAllowed)).recordCompleted()
    }
  }
}
