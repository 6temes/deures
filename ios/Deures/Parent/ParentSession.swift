import Foundation
import GateKit
import Observation

// What a parent can do on the iPad once the PIN has passed. Nothing past the prompt is reachable
// before that.
@MainActor
@Observable
final class ParentSession {
  enum Screen: Equatable {
    case allowlist
    case changePIN
    case menu
    case pin
  }

  private(set) var refusedAllowlist = false
  private(set) var screen = Screen.pin

  let change: PINChange
  let prompt: PINPrompt

  @ObservationIgnored private let clock: () -> Date
  @ObservationIgnored private let close: @MainActor () -> Void
  @ObservationIgnored private let deviceZone: () -> TimeZone
  @ObservationIgnored private let evaluator: GateEvaluator

  init(
    pins: PINStore,
    evaluator: GateEvaluator,
    clock: @escaping () -> Date = Date.init,
    deviceZone: @escaping () -> TimeZone = { .current },
    close: @escaping @MainActor () -> Void = {}
  ) {
    self.clock = clock
    self.close = close
    self.deviceZone = deviceZone
    self.evaluator = evaluator
    change = PINChange(pins: pins)
    prompt = PINPrompt(pins: pins)
  }

  var allowlist: Data? {
    evaluator.store.load()?.allowlist
  }

  private var verified: Bool {
    screen != .pin
  }

  func enter(_ digits: String) {
    guard !verified, prompt.submit(digits) else { return }
    screen = .menu
  }

  func open(_ next: Screen) {
    guard verified, next != .pin else { return }
    refusedAllowlist = false
    screen = next
  }

  // A PIN unlock belongs to the device, so it names only the date: the household's, or the
  // iPad's own before the server has ever named a zone.
  func unlockForToday() {
    guard verified else { return }
    let now = clock()
    evaluator.evaluate(now: now) { snapshot in
      snapshot.pinUnlock = CalendarDay(now, in: snapshot.zone ?? deviceZone())
    }
    close()
  }

  func save(_ choice: AllowlistChoice) {
    guard screen == .allowlist else { return }
    refusedAllowlist = choice.isOverLimit
    guard !refusedAllowlist else { return }

    evaluator.evaluate(now: clock()) { $0.allowlist = choice.data }
    screen = .menu
  }

  func enterForChange(_ digits: String) {
    guard screen == .changePIN, change.enter(digits) else { return }
    screen = .menu
  }

  func dismiss() {
    close()
  }
}

// The current PIN, then the new one twice.
@MainActor
@Observable
final class PINChange {
  private(set) var current: PIN?

  let newPIN = NewPINEntry()
  let prompt: PINPrompt

  @ObservationIgnored private let pins: PINStore

  init(pins: PINStore) {
    self.pins = pins
    prompt = PINPrompt(pins: pins)
  }

  // The current PIN is checked before the new one is asked for, and again when it is replaced.
  func enter(_ digits: String) -> Bool {
    guard let current else {
      if prompt.submit(digits) { self.current = PIN(digits) }
      return false
    }

    guard let new = newPIN.enter(digits) else { return false }
    self.current = nil
    switch (try? pins.change(from: current, to: new)) ?? .rejected {
    case .accepted:
      return true
    case .locked, .rejected:
      prompt.refresh()
      return false
    }
  }
}
