import Foundation
import GateCore

public protocol SetupFlagReader {
  func read() -> SetupFlag
}

public protocol ShieldWriter {
  func apply(_ decision: GateDecision)
}

// Persist, then decide from what was persisted, then apply: the app and the extension each write
// the shield, and they can only agree if neither decides from a view the other cannot see.
public struct GateEvaluator {
  public let store: any SnapshotStore

  private let deviceZone: () -> TimeZone
  private let setup: any SetupFlagReader
  private let shield: any ShieldWriter

  public init(store: any SnapshotStore, setup: any SetupFlagReader, shield: any ShieldWriter, deviceZone: @escaping () -> TimeZone = { .current }) {
    self.deviceZone = deviceZone
    self.setup = setup
    self.shield = shield
    self.store = store
  }

  @discardableResult
  public func evaluate(now: Date, answer: DayPayload? = nil, persisting change: (inout Snapshot) -> Void = { _ in }) -> GateDecision {
    let loaded = store.load()
    var snapshot = loaded ?? Snapshot()
    change(&snapshot)
    if snapshot != loaded { store.save(snapshot) }

    let decision = Gate(setup: setup.read(), snapshot: store.load(), answer: answer).decision(now: now, deviceZone: deviceZone())
    shield.apply(decision)
    return decision
  }
}

extension GateEvaluator {
  // The monitor's interval ends at 23:59, and the shield it writes then has to be right for the day
  // about to start. The next date is counted in the household's zone, as the gate counts today.
  @discardableResult
  public func evaluateFollowingDay(after now: Date) -> GateDecision {
    let calendar = CalendarDay.calendar(in: store.load()?.zone ?? deviceZone())
    return evaluate(now: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
  }
}
