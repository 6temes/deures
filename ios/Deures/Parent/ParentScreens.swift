import Foundation
import GateKit
import Observation

// Decides which grown-up screen, if any, covers the study screen. Missing Screen Time permission
// outranks everything, since without it there is no gate to set up or override.
@MainActor
@Observable
final class ParentScreens: RepairingPrompt {
  enum Overlay {
    case askGrownUp
    case parent(ParentSession)
    case repairing(RepairingRequest)
    case setup(SetupFlow)
  }

  private enum Access {
    case parent(ParentSession)
    case repairing(RepairingRequest)
  }

  let authorization: ScreenTimeAuthorization

  private var access: Access?
  private var setup: SetupFlow?

  @ObservationIgnored private let clock: () -> Date
  @ObservationIgnored private let deviceZone: () -> TimeZone
  @ObservationIgnored private let evaluator: GateEvaluator
  @ObservationIgnored private let flag: any SetupFlagRecording
  @ObservationIgnored private let pins: PINStore

  init(
    authorization: ScreenTimeAuthorization,
    pins: PINStore,
    evaluator: GateEvaluator,
    flag: any SetupFlagRecording,
    clock: @escaping () -> Date = Date.init,
    deviceZone: @escaping () -> TimeZone = { .current }
  ) {
    self.authorization = authorization
    self.clock = clock
    self.deviceZone = deviceZone
    self.evaluator = evaluator
    self.flag = flag
    self.pins = pins
  }

  var overlay: Overlay? {
    if authorization.isMissing { return .askGrownUp }
    if let setup { return .setup(setup) }
    switch access {
    case let .parent(session): return .parent(session)
    case let .repairing(request): return .repairing(request)
    case nil: return nil
    }
  }

  func refresh() async {
    await authorization.request()
    guard authorization.status == .approved, setup == nil, flag.read() == .absent else { return }

    access = nil
    setup = SetupFlow(pins: pins, evaluator: evaluator, flag: flag, authorization: authorization.fresh, clock: clock) { [weak self] in
      self?.setup = nil
    }
  }

  func openParentAccess() {
    guard setup == nil, access == nil else { return }
    access = .parent(ParentSession(pins: pins, evaluator: evaluator, clock: clock, deviceZone: deviceZone) { [weak self] in
      self?.access = nil
    })
  }

  func askBeforeRepairing(then proceed: @escaping @MainActor () -> Void) {
    let close: @MainActor () -> Void = { [weak self] in self?.access = nil }
    access = .repairing(RepairingRequest(prompt: PINPrompt(pins: pins), passed: { close(); proceed() }, cancelled: close))
  }
}

@MainActor
final class RepairingRequest {
  let prompt: PINPrompt

  private let cancelled: @MainActor () -> Void
  private let passed: @MainActor () -> Void

  init(prompt: PINPrompt, passed: @escaping @MainActor () -> Void, cancelled: @escaping @MainActor () -> Void) {
    self.cancelled = cancelled
    self.prompt = prompt
    self.passed = passed
  }

  func cancel() {
    cancelled()
  }

  func enter(_ digits: String) {
    if prompt.submit(digits) { passed() }
  }
}
