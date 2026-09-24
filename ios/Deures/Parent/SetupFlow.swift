import Foundation
import GateKit
import Observation

protocol SetupFlagRecording: SetupFlagReader {
  func recordCompleted() throws
}

extension KeychainSetupFlag: SetupFlagRecording {}

// First run: a PIN, then the allowlist, then "setup completed", then the child's pairing code. The
// flag is what turns the gate on, so it is written only once the allowlist it shields around is saved.
@MainActor
@Observable
final class SetupFlow {
  enum Step: Equatable {
    case allowlist
    case choosePIN
    case currentPIN
    case scanPairingCode
  }

  private(set) var refusedAllowlist = false
  private(set) var step: Step

  let currentPIN: PINPrompt
  let newPIN = NewPINEntry()

  @ObservationIgnored private let authorization: FreshAuthorization?
  @ObservationIgnored private let clock: () -> Date
  @ObservationIgnored private let evaluator: GateEvaluator
  @ObservationIgnored private let finished: @MainActor () -> Void
  @ObservationIgnored private let flag: any SetupFlagRecording
  @ObservationIgnored private let pins: PINStore

  init(
    pins: PINStore,
    evaluator: GateEvaluator,
    flag: any SetupFlagRecording,
    authorization: FreshAuthorization?,
    clock: @escaping () -> Date = Date.init,
    finished: @escaping @MainActor () -> Void = {}
  ) {
    self.authorization = authorization
    self.clock = clock
    self.evaluator = evaluator
    self.finished = finished
    self.flag = flag
    self.pins = pins
    currentPIN = PINPrompt(pins: pins)
    step = (try? pins.isSet) == true && authorization == nil ? .currentPIN : .choosePIN
  }

  func enterNewPIN(_ digits: String) {
    guard step == .choosePIN, let pin = newPIN.enter(digits) else { return }

    do {
      try pins.set(pin, authorization: authorization)
      step = .allowlist
    } catch PINStore.Refusal.freshAuthorizationRequired {
      step = .currentPIN
    } catch {
      step = .choosePIN
    }
  }

  // Only a PIN set before this run gets here, and only the parent who set it may carry on.
  func enterCurrentPIN(_ digits: String) {
    guard step == .currentPIN, currentPIN.submit(digits) else { return }
    step = .allowlist
  }

  func save(_ choice: AllowlistChoice) {
    guard step == .allowlist else { return }
    refusedAllowlist = choice.isOverLimit
    guard !refusedAllowlist else { return }

    var snapshot = evaluator.store.load() ?? Snapshot()
    snapshot.allowlist = choice.data
    evaluator.store.save(snapshot)
    do {
      try flag.recordCompleted()
      step = .scanPairingCode
    } catch {
      refusedAllowlist = true
    }
  }

  // The shield goes up only now, so the parent can still reach the Camera to scan the pairing code.
  func finish() {
    guard step == .scanPairingCode else { return }
    evaluator.evaluate(now: clock())
    finished()
  }
}
