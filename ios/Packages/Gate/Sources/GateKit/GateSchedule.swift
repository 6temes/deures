#if os(iOS)
import DeviceActivity
import Foundation

public enum GateSchedule {
  public static var activity: DeviceActivityName { DeviceActivityName("gate") }

  // Starting an activity inside its own interval fires intervalDidStart at once, so an activity
  // that is already registered is left running.
  public static func start(center: DeviceActivityCenter = DeviceActivityCenter()) throws {
    guard !center.activities.contains(activity) else { return }

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    try center.startMonitoring(activity, during: schedule)
  }
}
#endif
