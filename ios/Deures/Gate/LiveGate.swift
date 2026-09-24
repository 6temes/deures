import Foundation
import GateKit

extension Shell {
  static let daySync = DaySync(
    startLocation: startLocation,
    cookies: DeviceCookiePairing(host: startLocation.host()!),
    session: URLSession(configuration: DaySync.sessionConfiguration()),
    evaluator: GateEvaluator(
      store: DefaultsSnapshotStore(suiteName: Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String),
      setup: SetupNotYetRead(),
      shield: ShieldNotYetWritten()
    )
  )
}

// Stand-ins until the ManagedSettings adapter and the Keychain setup flag exist. With setup absent
// the gate leaves the shield untouched, so nothing here can block or unblock the iPad.
struct SetupNotYetRead: SetupFlagReader {
  func read() -> SetupFlag {
    .absent
  }
}

struct ShieldNotYetWritten: ShieldWriter {
  func apply(_ decision: GateDecision) {}
}
