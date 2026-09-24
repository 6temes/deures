import Foundation
import Security

final class PINStore {
  enum Account {
    static let lockout = "lockout"
    static let pin = "pin"
  }

  enum Refusal: Error {
    case freshAuthorizationRequired
  }

  enum Verification: Equatable {
    case accepted
    case locked(remaining: TimeInterval)
    case rejected
  }

  private struct Secret: Codable {
    let hash: Data
    let salt: Data
  }

  private struct Lockout: Codable {
    var failures = 0
    var lastAttempt: Date?
    var lockedUntil: Date?
  }

  private static let attemptsPerLockout = 5
  private static let firstLockout: TimeInterval = 60

  private let keychain: Keychain
  private let now: () -> Date

  init(keychain: Keychain, now: @escaping () -> Date = Date.init) {
    self.keychain = keychain
    self.now = now
  }

  var isSet: Bool {
    get throws { try secret != nil }
  }

  var lockoutRemaining: TimeInterval? {
    get throws { remaining(in: try lockout) }
  }

  func set(_ pin: PIN, authorization: FreshAuthorization? = nil) throws {
    if try isSet, authorization == nil { throw Refusal.freshAuthorizationRequired }
    try store(pin)
    try save(Lockout())
  }

  func verify(_ pin: PIN) throws -> Verification {
    var lockout = try lockout
    if let remaining = remaining(in: lockout) { return .locked(remaining: remaining) }

    if let secret = try secret, Self.matches(pin.hash(salt: secret.salt), secret.hash) {
      try save(Lockout())
      return .accepted
    }

    let attempt = now()
    lockout.failures += 1
    lockout.lastAttempt = attempt
    if lockout.failures.isMultiple(of: Self.attemptsPerLockout) {
      let doublings = lockout.failures / Self.attemptsPerLockout - 1
      lockout.lockedUntil = attempt + Self.firstLockout * pow(2, Double(doublings))
    }
    try save(lockout)
    return .rejected
  }

  func change(from current: PIN, to new: PIN) throws -> Verification {
    let verification = try verify(current)
    if verification == .accepted { try store(new) }
    return verification
  }

  // Once a lockout has been imposed, a clock reading earlier than the last attempt keeps entry
  // shut until it catches up, so winding the iPad back never reopens it.
  private func remaining(in lockout: Lockout) -> TimeInterval? {
    guard let lockedUntil = lockout.lockedUntil else { return nil }
    let until = max(lockedUntil, lockout.lastAttempt ?? lockedUntil)
    let remaining = until.timeIntervalSince(now())
    return remaining > 0 ? remaining : nil
  }

  private var secret: Secret? {
    get throws { try keychain.read(Account.pin).map { try JSONDecoder().decode(Secret.self, from: $0) } }
  }

  private var lockout: Lockout {
    get throws { try keychain.read(Account.lockout).map { try JSONDecoder().decode(Lockout.self, from: $0) } ?? Lockout() }
  }

  private func store(_ pin: PIN) throws {
    var salt = Data(count: 16)
    let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
    precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
    try keychain.write(JSONEncoder().encode(Secret(hash: pin.hash(salt: salt), salt: salt)), to: Account.pin)
  }

  private func save(_ lockout: Lockout) throws {
    try keychain.write(JSONEncoder().encode(lockout), to: Account.lockout)
  }

  private static func matches(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
  }
}
