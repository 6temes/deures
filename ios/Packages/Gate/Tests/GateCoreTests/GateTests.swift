import Foundation
import GateCore
import Testing

struct GateTests {
  let monday = try! day("2026-09-14")
  let tuesday = try! day("2026-09-15")
  let saturday = try! day("2026-09-19")
  let sunday = try! day("2026-09-20")
  let mondayAfternoon = try! instant("2026-09-14T07:10:00Z")
  let tuesdayMorning = try! instant("2026-09-15T00:00:00Z")
  let saturdayMorning = try! instant("2026-09-19T00:00:00Z")

  func answer(_ state: DayState, today: CalendarDay, child: Int = pau, freeDates: [CalendarDay] = []) -> DayPayload {
    DayPayload(childID: child, freeDates: freeDates, state: state, today: today, zone: tokyo)
  }

  func decide(_ snapshot: Snapshot?, answer: DayPayload? = nil, setup: SetupFlag = .completed, now: Date) -> GateDecision {
    Gate(setup: setup, snapshot: snapshot, answer: answer).decision(now: now, deviceZone: utc)
  }

  // AE1
  @Test func appliesOnAPendingSchoolDay() {
    #expect(decide(pairedSnapshot(latestServerToday: monday), answer: answer(.pending, today: monday), now: mondayAfternoon) == shielded)
  }

  @Test func clearsWhenTheServerSaysTheDayIsDone() {
    #expect(decide(pairedSnapshot(latestServerToday: monday), answer: answer(.done, today: monday), now: mondayAfternoon) == .clear)
  }

  // AE2
  @Test func clearsOnAFreeDateAndAppliesTheDayAfterTheListEnds() {
    let freeDates = [saturday, sunday]
    let mondayAfter = try! instant("2026-09-21T00:00:00Z")

    #expect(decide(pairedSnapshot(freeDates: freeDates), now: saturdayMorning) == .clear)
    #expect(decide(pairedSnapshot(freeDates: freeDates), now: mondayAfter) == shielded)
  }

  @Test func takesFreeDatesFromTheServerAnswer() {
    let saturdayAnswer = answer(.pending, today: saturday, freeDates: [saturday, sunday])

    #expect(decide(pairedSnapshot(), answer: saturdayAnswer, now: saturdayMorning) == .clear)
  }

  @Test func clearsWhenTheServerCallsTodayFree() {
    #expect(decide(pairedSnapshot(), answer: answer(.free, today: saturday), now: saturdayMorning) == .clear)
  }

  // AE4
  @Test func clearsAnExcusedDay() {
    #expect(decide(pairedSnapshot(), answer: answer(.excused, today: monday), now: mondayAfternoon) == .clear)
  }

  // AE5
  @Test func appliesWithNoServerStateAtAll() {
    #expect(decide(pairedSnapshot(), now: mondayAfternoon) == shielded)
  }

  @Test func clearsForAPinUnlockRecordedToday() {
    #expect(decide(pairedSnapshot(pinUnlock: monday), now: mondayAfternoon) == .clear)
  }

  @Test func ignoresAPinUnlockRecordedYesterday() {
    #expect(decide(pairedSnapshot(latestServerToday: monday, pinUnlock: monday), now: tuesdayMorning) == shielded)
  }

  // AE7
  @Test func appliesOnTuesdayAfterADoneMonday() {
    let mondayDone = Snapshot.ServerDay(childID: pau, fetchedAt: mondayAfternoon, state: .done, today: monday)
    let snapshot = pairedSnapshot(lastAnswer: mondayDone, latestServerToday: monday)

    #expect(decide(snapshot, now: mondayAfternoon) == .clear)
    #expect(decide(snapshot, now: tuesdayMorning) == shielded)
  }

  @Test func clearsForABridgeDoneWithNoServerAnswerSince() {
    let bridge = Snapshot.BridgeDone(childID: pau, date: monday, receivedAt: mondayAfternoon)
    let earlierPending = Snapshot.ServerDay(childID: pau, fetchedAt: mondayAfternoon.addingTimeInterval(-60), state: .pending, today: monday)

    #expect(decide(pairedSnapshot(bridgeDone: bridge), now: mondayAfternoon) == .clear)
    #expect(decide(pairedSnapshot(bridgeDone: bridge, lastAnswer: earlierPending), now: mondayAfternoon) == .clear)
  }

  @Test func appliesWhenAServerPendingArrivesAfterTheBridge() {
    let bridge = Snapshot.BridgeDone(childID: pau, date: monday, receivedAt: mondayAfternoon)
    let laterPending = Snapshot.ServerDay(childID: pau, fetchedAt: mondayAfternoon.addingTimeInterval(60), state: .pending, today: monday)

    #expect(decide(pairedSnapshot(bridgeDone: bridge, lastAnswer: laterPending), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(bridgeDone: bridge), answer: answer(.pending, today: monday), now: mondayAfternoon) == shielded)
  }

  @Test func appliesForADoneBelongingToTheOtherChild() {
    let teoBridge = Snapshot.BridgeDone(childID: teo, date: monday, receivedAt: mondayAfternoon)
    let teoDone = Snapshot.ServerDay(childID: teo, fetchedAt: mondayAfternoon, state: .done, today: monday)

    #expect(decide(pairedSnapshot(bridgeDone: teoBridge), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(lastAnswer: teoDone), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(), answer: answer(.done, today: monday, child: teo), now: mondayAfternoon) == shielded)
  }

  @Test func appliesWhenTheDeviceDateIsEarlierThanTheLatestServerToday() {
    let wednesday = try! day("2026-09-16")
    let mondayDone = Snapshot.ServerDay(childID: pau, fetchedAt: mondayAfternoon, state: .done, today: monday)
    let mondayBridge = Snapshot.BridgeDone(childID: pau, date: monday, receivedAt: mondayAfternoon)

    #expect(decide(pairedSnapshot(lastAnswer: mondayDone, latestServerToday: monday), now: mondayAfternoon) == .clear)
    #expect(decide(pairedSnapshot(lastAnswer: mondayDone, latestServerToday: wednesday), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(bridgeDone: mondayBridge, latestServerToday: wednesday), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(latestServerToday: wednesday, pinUnlock: monday), now: mondayAfternoon) == shielded)
    #expect(decide(pairedSnapshot(latestServerToday: wednesday, pinUnlock: wednesday), now: mondayAfternoon) == shielded)
  }

  @Test func usesTheServerTodayWhenAnAnswerIsPresent() {
    let sundayEvening = try! instant("2026-09-13T10:00:00Z")
    let tuesdayEvening = try! instant("2026-09-15T10:00:00Z")

    #expect(decide(pairedSnapshot(), answer: answer(.done, today: monday), now: sundayEvening) == .clear)
    #expect(decide(pairedSnapshot(), answer: answer(.done, today: monday), now: tuesdayEvening) == .clear)
    #expect(decide(pairedSnapshot(pinUnlock: tuesday), answer: answer(.pending, today: monday), now: tuesdayEvening) == shielded)
  }

  @Test func decidesForTheHouseholdDateRatherThanTheDeviceZone() throws {
    let lateOnThe13thInUTC = try instant("2026-09-13T23:30:00Z")
    let sunday13th = try day("2026-09-13")

    #expect(decide(pairedSnapshot(pinUnlock: monday), now: lateOnThe13thInUTC) == .clear)
    #expect(decide(pairedSnapshot(pinUnlock: sunday13th), now: lateOnThe13thInUTC) == shielded)
  }

  @Test func fallsBackToTheDeviceZoneBeforeTheHouseholdZoneIsKnown() throws {
    let lateOnThe13thInUTC = try instant("2026-09-13T23:30:00Z")
    var snapshot = pairedSnapshot(pinUnlock: monday)
    snapshot.zoneIdentifier = nil

    #expect(Gate(setup: .completed, snapshot: snapshot).decision(now: lateOnThe13thInUTC, deviceZone: tokyo) == .clear)
    #expect(Gate(setup: .completed, snapshot: snapshot).decision(now: lateOnThe13thInUTC, deviceZone: utc) == shielded)
  }

  @Test func appliesWhenTheSetupFlagIsUnreadable() {
    #expect(decide(pairedSnapshot(pinUnlock: monday), setup: .unreadable, now: mondayAfternoon) == .apply(exceptions: nil))
  }

  @Test func leavesTheStoreAloneWhenSetupIsAbsent() {
    #expect(decide(pairedSnapshot(), setup: .absent, now: mondayAfternoon) == .leave)
    #expect(decide(nil, setup: .absent, now: mondayAfternoon) == .leave)
  }

  @Test func appliesWithNoExceptionsWhenTheAllowlistIsMissing() {
    var snapshot = pairedSnapshot(pinUnlock: monday)
    snapshot.allowlist = nil

    #expect(decide(snapshot, now: mondayAfternoon) == .apply(exceptions: nil))
    #expect(decide(nil, now: mondayAfternoon) == .apply(exceptions: nil))
  }

  @Test func appliesForAnAnswerOnAnUnpairedIPad() {
    var snapshot = pairedSnapshot()
    snapshot.childID = nil

    #expect(decide(snapshot, answer: answer(.done, today: monday), now: mondayAfternoon) == shielded)
  }

  @Test func appliesWhenAMalformedPayloadDecodesToNoData() {
    let truncated = Data(#"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "do"#.utf8)

    #expect(decide(pairedSnapshot(), answer: DayPayload.decode(truncated), now: mondayAfternoon) == shielded)
  }
}
