import Foundation

public enum DayState: String, Codable, Sendable {
  case done, excused, free, pending

  var unlocks: Bool {
    self != .pending
  }
}

public struct DayPayload: Decodable, Equatable, Sendable {
  public let childID: Int
  public let freeDates: [CalendarDay]
  public let state: DayState
  public let today: CalendarDay
  public let zone: TimeZone

  public init(childID: Int, freeDates: [CalendarDay], state: DayState, today: CalendarDay, zone: TimeZone) {
    self.childID = childID
    self.freeDates = freeDates
    self.state = state
    self.today = today
    self.zone = zone
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let identifier = try container.decode(String.self, forKey: .zone)
    guard let zone = TimeZone(identifier: identifier) else {
      throw DecodingError.dataCorruptedError(forKey: .zone, in: container, debugDescription: "Unknown zone: \(identifier)")
    }

    childID = try container.decode(Int.self, forKey: .childID)
    freeDates = try container.decode([CalendarDay].self, forKey: .freeDates)
    state = try container.decode(DayState.self, forKey: .state)
    today = try container.decode(CalendarDay.self, forKey: .today)
    self.zone = zone
  }

  public static func decode(_ data: Data) -> DayPayload? {
    try? JSONDecoder().decode(DayPayload.self, from: data)
  }

  private enum CodingKeys: String, CodingKey {
    case childID = "child_id"
    case freeDates = "free_dates"
    case state
    case today
    case zone
  }
}
