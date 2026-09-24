import Foundation

public struct Snapshot: Codable, Equatable, Sendable {
  public struct BridgeDone: Codable, Equatable, Sendable {
    public var childID: Int
    public var date: CalendarDay
    public var receivedAt: Date

    public init(childID: Int, date: CalendarDay, receivedAt: Date) {
      self.childID = childID
      self.date = date
      self.receivedAt = receivedAt
    }
  }

  public struct ServerDay: Codable, Equatable, Sendable {
    public var childID: Int
    public var fetchedAt: Date
    public var state: DayState
    public var today: CalendarDay

    public init(childID: Int, fetchedAt: Date, state: DayState, today: CalendarDay) {
      self.childID = childID
      self.fetchedAt = fetchedAt
      self.state = state
      self.today = today
    }
  }

  public var allowlist: Data?
  public var bridgeDone: BridgeDone?
  public var childID: Int?
  public var freeDates: [CalendarDay]
  public var lastAnswer: ServerDay?
  public var latestServerToday: CalendarDay?
  public var pinUnlock: CalendarDay?
  public var zoneIdentifier: String?

  public init(
    allowlist: Data? = nil,
    bridgeDone: BridgeDone? = nil,
    childID: Int? = nil,
    freeDates: [CalendarDay] = [],
    lastAnswer: ServerDay? = nil,
    latestServerToday: CalendarDay? = nil,
    pinUnlock: CalendarDay? = nil,
    zoneIdentifier: String? = nil
  ) {
    self.allowlist = allowlist
    self.bridgeDone = bridgeDone
    self.childID = childID
    self.freeDates = freeDates
    self.lastAnswer = lastAnswer
    self.latestServerToday = latestServerToday
    self.pinUnlock = pinUnlock
    self.zoneIdentifier = zoneIdentifier
  }

  public var zone: TimeZone? {
    zoneIdentifier.flatMap(TimeZone.init(identifier:))
  }

  public static func decode(_ data: Data) -> Snapshot? {
    try? JSONDecoder().decode(Snapshot.self, from: data)
  }

  public func encoded() -> Data {
    try! JSONEncoder().encode(self)
  }
}
