import Foundation
import GateCore

public protocol SnapshotStore: AnyObject {
  func load() -> Snapshot?
  func save(_ snapshot: Snapshot)
}

// The App Group's defaults, so the app and the monitor extension read one snapshot.
public final class DefaultsSnapshotStore: SnapshotStore {
  public static let key = "snapshot"

  private let defaults: UserDefaults

  public init(suiteName: String) {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  public func load() -> Snapshot? {
    defaults.data(forKey: Self.key).flatMap(Snapshot.decode)
  }

  public func save(_ snapshot: Snapshot) {
    defaults.set(snapshot.encoded(), forKey: Self.key)
  }
}

extension Snapshot {
  public mutating func record(_ answer: DayPayload, fetchedAt: Date) {
    childID = answer.childID
    freeDates = answer.freeDates
    lastAnswer = ServerDay(childID: answer.childID, fetchedAt: fetchedAt, state: answer.state, today: answer.today)
    latestServerToday = max(latestServerToday ?? answer.today, answer.today)
    zoneIdentifier = answer.zone.identifier
  }
}
