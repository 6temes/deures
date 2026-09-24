import Foundation
import GateCore
import Testing

struct CalendarDayTests {
  @Test func parsesAnISODate() throws {
    let parsed = try day("2026-09-14")

    #expect(parsed.year == 2026)
    #expect(parsed.month == 9)
    #expect(parsed.day == 14)
  }

  @Test(arguments: ["", "2026-9-14", "2026-09-14T00:00:00Z", "2026-02-30", "2026-13-01", "14/09/2026", " 2026-09-14"])
  func rejectsAnythingElse(_ string: String) {
    #expect(CalendarDay(string) == nil)
  }

  @Test func namesTheDateInTheGivenZone() throws {
    let lateOnThe13thInUTC = try instant("2026-09-13T23:30:00Z")

    #expect(CalendarDay(lateOnThe13thInUTC, in: tokyo) == (try day("2026-09-14")))
    #expect(CalendarDay(lateOnThe13thInUTC, in: utc) == (try day("2026-09-13")))
  }

  @Test func ordersByDateAcrossMonthAndYearBoundaries() throws {
    #expect(try day("2026-09-30") < day("2026-10-01"))
    #expect(try day("2026-12-31") < day("2027-01-01"))
    #expect(try !(day("2026-10-01") < day("2026-09-30")))
    #expect(try !(day("2026-09-14") < day("2026-09-14")))
  }

  @Test func codesAsItsISOString() throws {
    let encoded = try JSONEncoder().encode([day("2026-09-14")])

    #expect(String(decoding: encoded, as: UTF8.self) == #"["2026-09-14"]"#)
    #expect(try JSONDecoder().decode([CalendarDay].self, from: encoded) == [day("2026-09-14")])
  }
}
