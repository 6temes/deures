import Foundation
import GateCore
import Testing

let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let utc = TimeZone(identifier: "UTC")!
let allowlist = Data("allowlist-tokens".utf8)
let pau = 1
let teo = 2

func day(_ string: String) throws -> CalendarDay {
  try #require(CalendarDay(string))
}

func instant(_ iso8601: String) throws -> Date {
  try #require(ISO8601DateFormatter().date(from: iso8601))
}

func pairedSnapshot(
  bridgeDone: Snapshot.BridgeDone? = nil,
  freeDates: [CalendarDay] = [],
  lastAnswer: Snapshot.ServerDay? = nil,
  latestServerToday: CalendarDay? = nil,
  pinUnlock: CalendarDay? = nil
) -> Snapshot {
  Snapshot(
    allowlist: allowlist,
    bridgeDone: bridgeDone,
    childID: pau,
    freeDates: freeDates,
    lastAnswer: lastAnswer,
    latestServerToday: latestServerToday,
    pinUnlock: pinUnlock,
    zoneIdentifier: "Asia/Tokyo"
  )
}

let shielded = GateDecision.apply(exceptions: allowlist)
