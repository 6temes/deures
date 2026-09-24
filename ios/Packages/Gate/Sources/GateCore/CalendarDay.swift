import Foundation

public struct CalendarDay: Comparable, Hashable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  public init?(_ string: String) {
    let parts = string.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts.map(\.count) == [4, 2, 2], parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return nil }

    let (year, month, day) = (Int(parts[0])!, Int(parts[1])!, Int(parts[2])!)
    let components = DateComponents(calendar: Self.calendar(in: .gmt), year: year, month: month, day: day)
    guard components.isValidDate else { return nil }

    self.year = year
    self.month = month
    self.day = day
  }

  public init(_ date: Date, in zone: TimeZone) {
    let components = Self.calendar(in: zone).dateComponents([.year, .month, .day], from: date)
    year = components.year!
    month = components.month!
    day = components.day!
  }

  public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  public static func calendar(in zone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar
  }
}

extension CalendarDay: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let parsed = CalendarDay(string) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a YYYY-MM-DD date: \(string)")
    }
    self = parsed
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

extension CalendarDay: CustomStringConvertible {
  public var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }
}
