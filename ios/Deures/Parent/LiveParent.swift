import FamilyControls
import GateKit
import os

extension Shell {
  static let parentScreens = ParentScreens(
    authorization: ScreenTimeAuthorization(current: { AuthorizationCenter.shared.authorizationStatus }, request: requestChildAuthorization),
    pins: PINStore(keychain: SystemKeychain(service: "parent-pin")),
    evaluator: evaluator,
    flag: KeychainSetupFlag(accessGroup: appGroup)
  )

  private static let parentLog = Logger(subsystem: "Deures", category: "parent")

  // Screen Time can be withdrawn in Settings while the app runs, so the status is followed as well
  // as read after each request.
  static func followAuthorization() {
    Task {
      for await status in AuthorizationCenter.shared.$authorizationStatus.values {
        parentScreens.authorization.observe(status)
      }
    }
  }

  private static func requestChildAuthorization() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .child)
    } catch {
      parentLog.error("Screen Time authorization refused: \(error)")
    }
  }
}
