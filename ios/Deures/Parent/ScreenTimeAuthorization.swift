import FamilyControls
import Observation

// Owns the app's Screen Time permission. The status seen before approval is kept so that a grant
// made during this run can be told apart from one that was already there.
@MainActor
@Observable
final class ScreenTimeAuthorization {
  private(set) var asked = false
  private(set) var status: AuthorizationStatus

  @ObservationIgnored private var unapproved: AuthorizationStatus?
  @ObservationIgnored private let current: @MainActor () -> AuthorizationStatus
  @ObservationIgnored private let requestChild: @MainActor () async -> Void

  init(current: @escaping @MainActor () -> AuthorizationStatus, request: @escaping @MainActor () async -> Void) {
    self.current = current
    self.requestChild = request
    status = current()
    unapproved = status == .approved ? nil : status
  }

  var fresh: FreshAuthorization? {
    unapproved.flatMap { FreshAuthorization(from: $0, to: status) }
  }

  var isMissing: Bool {
    asked && status != .approved
  }

  func observe(_ status: AuthorizationStatus) {
    if status != .approved { unapproved = status }
    self.status = status
  }

  func request() async {
    await requestChild()
    observe(current())
    asked = true
  }
}
