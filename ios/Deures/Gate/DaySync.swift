import Foundation
import GateKit

@MainActor
protocol DeviceCookieSource {
  func deviceCookie() async -> HTTPCookie?
}

// Reads today from the server and hands it to the gate. The server's answer decides; a bridge
// `done` only stands on its own when the server cannot be reached at all.
@MainActor
final class DaySync: DayDoneHandling {
  private enum Fetch {
    case answer(DayPayload)
    case network
    case refused
  }

  private let clock: () -> Date
  private let cookies: any DeviceCookieSource
  private let dayURL: URL
  private let evaluator: GateEvaluator
  private let session: URLSession
  private var rerun = false
  private var syncing: Task<GateDecision, Never>?

  init(startLocation: URL, cookies: any DeviceCookieSource, session: URLSession, evaluator: GateEvaluator, clock: @escaping () -> Date = Date.init) {
    self.clock = clock
    self.cookies = cookies
    self.dayURL = startLocation.appending(path: "day")
    self.evaluator = evaluator
    self.session = session
  }

  // The device cookie is a two-year credential, so it is sent by hand and nothing keeps a copy.
  static func sessionConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    return configuration
  }

  // One fetch at a time, so a slow answer can never land over a fresher one. A sync asked for while
  // one is running is folded into a single fetch that starts after the running one ends, so what
  // the caller recorded before asking, such as a bridge `done`, is in what the server is asked.
  @discardableResult
  func sync() async -> GateDecision {
    if let syncing {
      rerun = true
      return await syncing.value
    }

    let task = Task {
      var decision: GateDecision
      repeat {
        rerun = false
        decision = await syncOnce()
      } while rerun
      syncing = nil
      return decision
    }
    syncing = task
    return await task.value
  }

  private func syncOnce() async -> GateDecision {
    switch await fetch() {
    case let .answer(answer):
      let now = clock()
      return evaluator.evaluate(now: now, answer: answer) { $0.record(answer, fetchedAt: now) }
    case .network:
      return evaluator.evaluate(now: clock())
    case .refused:
      return evaluator.evaluate(now: clock()) { $0.bridgeDone = nil }
    }
  }

  func dayDone(_ done: DayDone) {
    Task { await receive(done) }
  }

  @discardableResult
  func receive(_ done: DayDone) async -> GateDecision? {
    guard var snapshot = evaluator.store.load(), snapshot.childID == done.childID else { return nil }

    snapshot.bridgeDone = Snapshot.BridgeDone(childID: done.childID, date: done.date, receivedAt: clock())
    evaluator.store.save(snapshot)
    return await sync()
  }

  private func fetch() async -> Fetch {
    var request = URLRequest(url: dayURL)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let cookie = await cookies.deviceCookie() {
      HTTPCookie.requestHeaderFields(with: [cookie]).forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }

    do {
      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200, let answer = DayPayload.decode(data) else { return .refused }
      return .answer(answer)
    } catch {
      return .network
    }
  }
}
