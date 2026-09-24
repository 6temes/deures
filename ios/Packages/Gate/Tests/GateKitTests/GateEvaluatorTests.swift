import Foundation
import GateKit
import Testing

struct GateEvaluatorTests {
  let tokyo = TimeZone(identifier: "Asia/Tokyo")!
  let allowlist = Data("allowlist-tokens".utf8)
  let monday = CalendarDay("2026-09-14")!
  let mondayAfternoon = ISO8601DateFormatter().date(from: "2026-09-14T07:10:00Z")!

  func paired() -> Snapshot {
    Snapshot(allowlist: allowlist, childID: 1, latestServerToday: monday, zoneIdentifier: "Asia/Tokyo")
  }

  func answer(_ state: DayState) -> DayPayload {
    DayPayload(childID: 1, freeDates: [], state: state, today: monday, zone: tokyo)
  }

  @Test func persistsThenDecidesThenApplies() {
    let journal = Journal()
    let store = JournalStore(journal: journal, snapshot: paired())
    let evaluator = GateEvaluator(store: store, setup: JournalSetup(journal: journal), shield: JournalShield(journal: journal), deviceZone: { tokyo })

    let decision = evaluator.evaluate(now: mondayAfternoon, answer: answer(.done)) { $0.record(answer(.done), fetchedAt: mondayAfternoon) }

    #expect(decision == .clear)
    #expect(journal.events == ["load", "save", "setup", "load", "apply clear"])
  }

  @Test func decidesFromTheSnapshotAsPersisted() {
    let journal = Journal()
    let store = JournalStore(journal: journal, snapshot: paired())
    let evaluator = GateEvaluator(store: store, setup: JournalSetup(journal: journal), shield: JournalShield(journal: journal), deviceZone: { tokyo })

    evaluator.evaluate(now: mondayAfternoon) { $0.pinUnlock = monday }

    #expect(store.snapshot?.pinUnlock == monday)
    #expect(journal.events.last == "apply clear")
  }

  @Test func leavesAnUnchangedSnapshotUnwritten() {
    let journal = Journal()
    let store = JournalStore(journal: journal, snapshot: paired())
    let evaluator = GateEvaluator(store: store, setup: JournalSetup(journal: journal), shield: JournalShield(journal: journal), deviceZone: { tokyo })

    let decision = evaluator.evaluate(now: mondayAfternoon)

    #expect(decision == .apply(exceptions: allowlist))
    #expect(!journal.events.contains("save"))
    #expect(journal.events.last == "apply apply")
  }

  @Test func appliesWithNoExceptionsBeforeAnySnapshotExists() {
    let journal = Journal()
    let store = JournalStore(journal: journal, snapshot: nil)
    let evaluator = GateEvaluator(store: store, setup: JournalSetup(journal: journal), shield: JournalShield(journal: journal), deviceZone: { tokyo })

    #expect(evaluator.evaluate(now: mondayAfternoon) == .apply(exceptions: nil))
  }
}

struct SnapshotRecordTests {
  let tokyo = TimeZone(identifier: "Asia/Tokyo")!
  let fetchedAt = ISO8601DateFormatter().date(from: "2026-09-15T07:10:00Z")!

  func answer(_ today: String, child: Int = 1, state: DayState = .pending) -> DayPayload {
    DayPayload(childID: child, freeDates: [CalendarDay("2026-09-19")!], state: state, today: CalendarDay(today)!, zone: tokyo)
  }

  @Test func recordsTheAnswerAndItsChildZoneAndFreeDates() {
    var snapshot = Snapshot()

    snapshot.record(answer("2026-09-15", child: 2, state: .done), fetchedAt: fetchedAt)

    #expect(snapshot.childID == 2)
    #expect(snapshot.zoneIdentifier == "Asia/Tokyo")
    #expect(snapshot.freeDates == [CalendarDay("2026-09-19")!])
    #expect(snapshot.lastAnswer == Snapshot.ServerDay(childID: 2, fetchedAt: fetchedAt, state: .done, today: CalendarDay("2026-09-15")!))
  }

  @Test func advancesTheLatestServerToday() {
    var snapshot = Snapshot(latestServerToday: CalendarDay("2026-09-14")!)

    snapshot.record(answer("2026-09-15"), fetchedAt: fetchedAt)

    #expect(snapshot.latestServerToday == CalendarDay("2026-09-15")!)
  }

  @Test func neverMovesTheLatestServerTodayBack() {
    var snapshot = Snapshot(latestServerToday: CalendarDay("2026-09-15")!)

    snapshot.record(answer("2026-09-14"), fetchedAt: fetchedAt)

    #expect(snapshot.latestServerToday == CalendarDay("2026-09-15")!)
    #expect(snapshot.lastAnswer?.today == CalendarDay("2026-09-14")!)
  }
}

struct DefaultsSnapshotStoreTests {
  @Test func roundTripsTheSnapshotThroughItsSuite() throws {
    let suite = "gatekit-tests-\(UUID().uuidString)"
    defer { UserDefaults().removePersistentDomain(forName: suite) }
    let snapshot = Snapshot(allowlist: Data("tokens".utf8), childID: 1, freeDates: [CalendarDay("2026-09-19")!], zoneIdentifier: "Asia/Tokyo")

    DefaultsSnapshotStore(suiteName: suite).save(snapshot)

    #expect(DefaultsSnapshotStore(suiteName: suite).load() == snapshot)
    #expect(DefaultsSnapshotStore(suiteName: "gatekit-tests-\(UUID().uuidString)").load() == nil)
  }
}

final class Journal {
  var events: [String] = []
}

final class JournalStore: SnapshotStore {
  let journal: Journal
  var snapshot: Snapshot?

  init(journal: Journal, snapshot: Snapshot?) {
    self.journal = journal
    self.snapshot = snapshot
  }

  func load() -> Snapshot? {
    journal.events.append("load")
    return snapshot
  }

  func save(_ snapshot: Snapshot) {
    journal.events.append("save")
    self.snapshot = snapshot
  }
}

struct JournalSetup: SetupFlagReader {
  let journal: Journal

  func read() -> SetupFlag {
    journal.events.append("setup")
    return .completed
  }
}

struct JournalShield: ShieldWriter {
  let journal: Journal

  func apply(_ decision: GateDecision) {
    switch decision {
    case .apply: journal.events.append("apply apply")
    case .clear: journal.events.append("apply clear")
    case .leave: journal.events.append("apply leave")
    }
  }
}
