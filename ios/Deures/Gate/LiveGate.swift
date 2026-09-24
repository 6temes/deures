import Foundation
import GateKit
import ManagedSettings
import os

extension Shell {
  nonisolated static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String

  static let evaluator = GateEvaluator(
    store: DefaultsSnapshotStore(suiteName: appGroup),
    setup: KeychainSetupFlag(accessGroup: appGroup),
    shield: ManagedSettingsShield()
  )

  static let daySync = DaySync(
    startLocation: startLocation,
    cookies: DeviceCookiePairing(host: startLocation.host()!),
    session: URLSession(configuration: DaySync.sessionConfiguration()),
    evaluator: evaluator
  )

  private static let log = Logger(subsystem: "Deures", category: "gate")
  private static var tokenExpiry: NotificationCenter.ObservationToken?

  static func startGate() {
    HTTPCookieStorage.shared.deleteDeviceCookies(for: startLocation.host()!)

    do {
      try GateSchedule.start()
    } catch {
      log.error("Daily schedule not started: \(error)")
    }

    if #available(iOS 26.5, *) {
      tokenExpiry = NotificationCenter.default.addObserver(of: ManagedSettingsStore.self, for: .tokensDidExpire) { _ in
        await MainActor.run { refreshAllowlist() }
      }
    }
  }

  @available(iOS 26.5, *)
  private static func refreshAllowlist() {
    evaluator.evaluate(now: Date()) { snapshot in
      if let refreshed = snapshot.allowlist.flatMap(Allowlist.refreshed) { snapshot.allowlist = refreshed }
    }
  }
}
