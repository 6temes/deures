import Foundation
import GateKit
import Testing
import WebKit
@testable import Deures

@MainActor
@Suite(.serialized)
final class DaySyncTests {
  let start = URL(string: "https://deures.example.com/")!
  let allowlist = Data("allowlist-tokens".utf8)
  let tokyo = TimeZone(identifier: "Asia/Tokyo")!
  let suite = "deures-tests-\(UUID().uuidString)"
  let clock = TestClock(ISO8601DateFormatter().date(from: "2026-09-14T07:10:00Z")!)
  let shield = RecordingShield()
  let store: DefaultsSnapshotStore

  init() {
    store = DefaultsSnapshotStore(suiteName: suite)
    shield.store = store
    StubDay.reset()
  }

  deinit {
    UserDefaults().removePersistentDomain(forName: suite)
  }

  var shielded: GateDecision { .apply(exceptions: allowlist) }

  func paired(_ change: (inout Snapshot) -> Void = { _ in }) {
    var snapshot = Snapshot(allowlist: allowlist, childID: 1, zoneIdentifier: "Asia/Tokyo")
    change(&snapshot)
    store.save(snapshot)
  }

  func sync(cookies: any DeviceCookieSource = FixedCookie(value: "device-secret")) -> DaySync {
    let configuration = DaySync.sessionConfiguration()
    configuration.protocolClasses = [StubDay.self]
    let evaluator = GateEvaluator(store: store, setup: CompletedSetup(), shield: shield, deviceZone: { [tokyo] in tokyo })
    return DaySync(startLocation: start, cookies: cookies, session: URLSession(configuration: configuration), evaluator: evaluator, clock: { [clock] in clock.now })
  }

  func done(child: Int = 1, date: String = "2026-09-14") -> DayDone {
    DayDone(jsonData: #"{"child_id":\#(child),"date":"\#(date)"}"#, pageURL: start, startLocation: start)!
  }

  @Test func persistsADoneAnswerBeforeTheShieldIsWrittenAndClears() async {
    paired()
    StubDay.answer(state: "done", today: "2026-09-14")

    await sync().sync()

    #expect(shield.decisions == [.clear])
    #expect(shield.persistedAtApply.map { $0?.lastAnswer?.state } == [.done])
    #expect(StubDay.requests.map(\.url) == [URL(string: "https://deures.example.com/day")!])
  }

  @Test func aBridgeDoneClearsWhenTheNetworkFailsAndAPendingAnswerAppliesAgain() async {
    paired()
    StubDay.failOnTheNetwork()
    let daySync = sync()

    await daySync.receive(done())

    #expect(store.load()?.bridgeDone == Snapshot.BridgeDone(childID: 1, date: CalendarDay("2026-09-14")!, receivedAt: clock.now))
    #expect(shield.decisions == [.clear])
    #expect(StubDay.requests.count == 1)

    clock.advance(by: 60)
    StubDay.answer(state: "pending", today: "2026-09-14")
    await daySync.sync()

    #expect(shield.decisions == [.clear, shielded])
  }

  @Test func aBridgeDoneForAnotherChildIsIgnored() async {
    paired()
    StubDay.failOnTheNetwork()

    await sync().receive(done(child: 2))

    #expect(store.load()?.bridgeDone == nil)
    #expect(shield.decisions.isEmpty)
    #expect(StubDay.requests.isEmpty)
  }

  @Test func aBridgeDoneDoesNotClearWhenTheServerAnswersWithoutADay() async {
    paired()
    StubDay.respond(status: 401)

    await sync().receive(done())

    #expect(store.load()?.bridgeDone == nil)
    #expect(shield.decisions == [shielded])
  }

  @Test func anUnauthorizedAnswerKeepsTheSnapshotAndApplies() async {
    let fetchedAt = clock.now.addingTimeInterval(-3600)
    paired {
      $0.freeDates = [CalendarDay("2026-09-19")!]
      $0.lastAnswer = Snapshot.ServerDay(childID: 1, fetchedAt: fetchedAt, state: .pending, today: CalendarDay("2026-09-14")!)
      $0.latestServerToday = CalendarDay("2026-09-14")!
    }
    let before = store.load()
    StubDay.respond(status: 401)

    await sync().sync()

    #expect(store.load() == before)
    #expect(shield.decisions == [shielded])
  }

  @Test func sendsTheCookieFromTheWebViewStoreAndNeverKeepsIt() async throws {
    let token = "device-secret-\(UUID().uuidString)"
    let cookie = try #require(HTTPCookie(properties: [.name: "device_token", .value: token, .domain: "deures.example.com", .path: "/", .secure: true]))
    let cookies = WKWebsiteDataStore.default().httpCookieStore
    await cookies.setCookie(cookie)
    paired()
    StubDay.answer(state: "done", today: "2026-09-14")

    await sync(cookies: DeviceCookiePairing(host: "deures.example.com")).sync()
    await cookies.deleteCookie(cookie)

    #expect(StubDay.requests.first?.value(forHTTPHeaderField: "Cookie") == "device_token=\(token)")
    let persisted = try #require(UserDefaults(suiteName: suite)?.dictionaryRepresentation())
    #expect(!persisted.isEmpty)
    #expect(!String(describing: persisted).contains(token))
    #expect(!persisted.values.compactMap { $0 as? Data }.contains { String(decoding: $0, as: UTF8.self).contains(token) })
  }

  @Test func aNewHouseholdDayReappliesEvenWhenTheFetchFails() async {
    paired {
      $0.lastAnswer = Snapshot.ServerDay(childID: 1, fetchedAt: self.clock.now, state: .done, today: CalendarDay("2026-09-14")!)
      $0.latestServerToday = CalendarDay("2026-09-14")!
    }
    StubDay.failOnTheNetwork()
    let daySync = sync()

    await daySync.sync()
    clock.now = ISO8601DateFormatter().date(from: "2026-09-14T15:30:00Z")!
    await daySync.sync()

    #expect(shield.decisions == [.clear, shielded])
  }

  // A return to the app and a bridge `done` can each start a sync. A slow answer fetched first must
  // not land after, and over, the answer fetched once the day was done.
  @Test func overlappingSyncsFetchOneAfterAnotherSoTheFresherAnswerStays() async throws {
    paired()
    StubDay.answer(state: "pending", today: "2026-09-14", after: 0.5)
    StubDay.answer(state: "done", today: "2026-09-14", after: 0)
    let daySync = sync()

    let first = Task { await daySync.sync() }
    try await StubDay.waitForRequests(1)
    async let second = daySync.sync()
    async let third = daySync.sync()
    _ = await (first.value, second, third)

    #expect(StubDay.requests.count == 2)
    #expect(store.load()?.lastAnswer?.state == .done)
    #expect(shield.decisions.last == .clear)
  }

  @Test func theLatestServerTodayAdvancesAndNeverGoesBack() async {
    paired { $0.latestServerToday = CalendarDay("2026-09-14")! }
    let daySync = sync()

    StubDay.answer(state: "pending", today: "2026-09-15")
    await daySync.sync()
    #expect(store.load()?.latestServerToday == CalendarDay("2026-09-15")!)

    StubDay.answer(state: "pending", today: "2026-09-14")
    await daySync.sync()
    #expect(store.load()?.latestServerToday == CalendarDay("2026-09-15")!)
    #expect(store.load()?.lastAnswer?.today == CalendarDay("2026-09-14")!)
  }
}

final class RecordingShield: ShieldWriter {
  var store: (any SnapshotStore)?
  private(set) var decisions: [GateDecision] = []
  private(set) var persistedAtApply: [Snapshot?] = []

  func apply(_ decision: GateDecision) {
    decisions.append(decision)
    persistedAtApply.append(store?.load())
  }
}

struct CompletedSetup: SetupFlagReader {
  func read() -> SetupFlag {
    .completed
  }
}

struct FixedCookie: DeviceCookieSource {
  let value: String

  func deviceCookie() async -> HTTPCookie? {
    HTTPCookie(properties: [.name: "device_token", .value: value, .domain: "deures.example.com", .path: "/"])
  }
}

final class StubDay: URLProtocol {
  private enum Response {
    case network
    case http(Int, Data)
  }

  nonisolated(unsafe) private static var response = Response.network
  nonisolated(unsafe) private static var queued: [(delay: TimeInterval, response: Response)] = []
  nonisolated(unsafe) private(set) static var requests: [URLRequest] = []

  static func reset() {
    response = .network
    queued = []
    requests = []
  }

  // Queues answers served one per request, in order, each after its own delay.
  static func answer(state: String, today: String, after delay: TimeInterval) {
    answer(state: state, today: today)
    queued.append((delay, response))
  }

  static func waitForRequests(_ count: Int) async throws {
    for _ in 1...200 where requests.count < count {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require(requests.count >= count)
  }

  static func answer(state: String, today: String) {
    let body = #"{"child_id":1,"zone":"Asia/Tokyo","today":"\#(today)","state":"\#(state)","free_dates":["2026-09-19"],"windows":[]}"#
    response = .http(200, Data(body.utf8))
  }

  static func respond(status: Int) {
    response = .http(status, Data(#"{"error":"unpaired"}"#.utf8))
  }

  static func failOnTheNetwork() {
    response = .network
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requests.append(request)
    guard Self.queued.isEmpty else {
      let (delay, response) = Self.queued.removeFirst()
      DispatchQueue.global().asyncAfter(deadline: .now() + delay) { self.respond(response) }
      return
    }
    respond(Self.response)
  }

  private func respond(_ response: Response) {
    switch response {
    case .network:
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    case let .http(status, body):
      let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: body)
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {}
}
