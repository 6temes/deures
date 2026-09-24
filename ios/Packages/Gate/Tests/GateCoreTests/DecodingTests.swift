import Foundation
import GateCore
import Testing

struct DayPayloadTests {
  let valid = #"""
    {"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "pending",
     "free_dates": ["2026-09-19", "2026-09-20", "2026-09-21"], "windows": []}
    """#

  @Test func decodesTheDayEndpoint() throws {
    let payload = try #require(DayPayload.decode(Data(valid.utf8)))

    #expect(payload.childID == 1)
    #expect(payload.zone == tokyo)
    #expect(payload.today == (try day("2026-09-14")))
    #expect(payload.state == .pending)
    #expect(payload.freeDates == [try day("2026-09-19"), try day("2026-09-20"), try day("2026-09-21")])
  }

  @Test(arguments: [
    "",
    "{",
    #"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "pen"#,
    #"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "free_dates": [], "windows": []}"#,
    #"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "open", "free_dates": [], "windows": []}"#,
    #"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-02-30", "state": "done", "free_dates": [], "windows": []}"#,
    #"{"child_id": 1, "zone": "Mars/Olympus", "today": "2026-09-14", "state": "done", "free_dates": [], "windows": []}"#,
    #"{"child_id": "1", "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "done", "free_dates": [], "windows": []}"#,
    #"{"child_id": 1, "zone": "Asia/Tokyo", "today": "2026-09-14", "state": "done", "free_dates": ["soon"], "windows": []}"#,
    #"<html>Sign in</html>"#
  ])
  func decodesAMalformedPayloadToNoData(_ body: String) {
    #expect(DayPayload.decode(Data(body.utf8)) == nil)
  }
}

struct SnapshotTests {
  @Test func roundTripsThroughItsEncoding() throws {
    let snapshot = Snapshot(
      allowlist: allowlist,
      bridgeDone: .init(childID: pau, date: try day("2026-09-14"), receivedAt: try instant("2026-09-14T07:10:00Z")),
      childID: pau,
      freeDates: [try day("2026-09-19")],
      lastAnswer: .init(childID: pau, fetchedAt: try instant("2026-09-14T07:11:00Z"), state: .done, today: try day("2026-09-14")),
      latestServerToday: try day("2026-09-14"),
      pinUnlock: try day("2026-09-13"),
      zoneIdentifier: "Asia/Tokyo"
    )

    #expect(Snapshot.decode(snapshot.encoded()) == snapshot)
  }

  @Test func decodesATruncatedSnapshotToNothing() throws {
    let encoded = pairedSnapshot(latestServerToday: try day("2026-09-14")).encoded()

    #expect(encoded.count > 10)
    #expect(Snapshot.decode(encoded.prefix(encoded.count / 2)) == nil)
    #expect(Snapshot.decode(Data()) == nil)
  }

  @Test func resolvesItsZone() {
    #expect(Snapshot(zoneIdentifier: "Asia/Tokyo").zone == tokyo)
    #expect(Snapshot(zoneIdentifier: "Mars/Olympus").zone == nil)
    #expect(Snapshot().zone == nil)
  }
}
