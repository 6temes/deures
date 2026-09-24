import DeviceActivity
import Foundation
import GateKit

// Runs at the first use of the iPad after midnight and again at 23:59, so a day that was unlocked is
// shielded again before the next one begins even if the iPad sits unused overnight.
final class Monitor: DeviceActivityMonitor {
  private let evaluator: GateEvaluator = {
    let group = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
    return GateEvaluator(store: DefaultsSnapshotStore(suiteName: group), setup: KeychainSetupFlag(accessGroup: group), shield: ManagedSettingsShield())
  }()

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    guard activity == GateSchedule.activity else { return }
    evaluator.evaluate(now: Date())
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    guard activity == GateSchedule.activity else { return }
    evaluator.evaluateFollowingDay(after: Date())
  }
}
