import Foundation

public enum SetupFlag: Sendable {
  case absent, completed, unreadable
}

public enum GateDecision: Equatable, Sendable {
  case apply(exceptions: Data?)
  case clear
  case leave
}

public struct Gate: Sendable {
  public var answer: DayPayload?
  public var setup: SetupFlag
  public var snapshot: Snapshot?

  public init(setup: SetupFlag, snapshot: Snapshot?, answer: DayPayload? = nil) {
    self.answer = answer
    self.setup = setup
    self.snapshot = snapshot
  }

  public func decision(now: Date, deviceZone: TimeZone) -> GateDecision {
    switch setup {
    case .absent: return .leave
    case .unreadable: return .apply(exceptions: nil)
    case .completed: break
    }
    guard let snapshot, let allowlist = snapshot.allowlist else { return .apply(exceptions: nil) }

    let shield = GateDecision.apply(exceptions: allowlist)
    let answer = answer.flatMap { $0.childID == snapshot.childID ? $0 : nil }
    let today: CalendarDay
    if let answer {
      today = answer.today
    } else {
      today = CalendarDay(now, in: snapshot.zone ?? deviceZone)
      if let latest = snapshot.latestServerToday, today < latest { return shield }
    }

    if snapshot.pinUnlock == today { return .clear }
    if (answer?.freeDates ?? snapshot.freeDates).contains(today) { return .clear }
    if let answer { return answer.state.unlocks ? .clear : shield }
    if let last = snapshot.lastAnswer, last.childID == snapshot.childID, last.today == today, last.state.unlocks { return .clear }
    if let bridge = snapshot.bridgeDone, bridge.childID == snapshot.childID, bridge.date == today,
      snapshot.lastAnswer.map({ $0.fetchedAt < bridge.receivedAt }) ?? true {
      return .clear
    }
    return shield
  }
}
