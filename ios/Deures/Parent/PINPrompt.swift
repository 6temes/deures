import Foundation
import Observation

@MainActor
@Observable
final class PINPrompt {
  enum Status: Equatable {
    case locked(remaining: TimeInterval)
    case ready
    case wrong
  }

  private(set) var status = Status.ready

  @ObservationIgnored private let pins: PINStore

  init(pins: PINStore) {
    self.pins = pins
    refresh()
  }

  // A Keychain that cannot be read counts as a wrong PIN: the prompt fails shut.
  @discardableResult
  func submit(_ digits: String) -> Bool {
    guard let pin = PIN(digits) else {
      status = .wrong
      return false
    }

    switch (try? pins.verify(pin)) ?? .rejected {
    case .accepted:
      status = .ready
      return true
    case let .locked(remaining):
      status = .locked(remaining: remaining)
    case .rejected:
      status = lockout.map { .locked(remaining: $0) } ?? .wrong
    }
    return false
  }

  private var lockout: TimeInterval? {
    (try? pins.lockoutRemaining).flatMap { $0 }
  }

  func refresh() {
    if let remaining = lockout {
      status = .locked(remaining: remaining)
    } else if case .locked = status {
      status = .ready
    }
  }
}

// A new PIN is typed twice; a second entry that differs starts it over.
@MainActor
@Observable
final class NewPINEntry {
  private(set) var isConfirming = false
  private(set) var mismatched = false

  @ObservationIgnored private var first: String?

  func enter(_ digits: String) -> PIN? {
    guard let first else {
      guard PIN(digits) != nil else { return nil }
      self.first = digits
      isConfirming = true
      mismatched = false
      return nil
    }

    self.first = nil
    isConfirming = false
    guard digits == first else {
      mismatched = true
      return nil
    }
    return PIN(digits)
  }
}
