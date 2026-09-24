import Foundation
import GateKit
@preconcurrency import HotwireNative

@MainActor
protocol DayDoneHandling {
  func dayDone(_ done: DayDone)
}

struct IgnoreDayDone: DayDoneHandling {
  func dayDone(_ done: DayDone) {}
}

struct DayDone: Equatable {
  let childID: Int
  let date: CalendarDay

  init?(jsonData: String, pageURL: URL?, startLocation: URL) {
    guard let pageURL, pageURL.isOnStartHost(startLocation),
          let payload = try? JSONDecoder().decode(Payload.self, from: Data(jsonData.utf8)),
          payload.childID > 0
    else { return nil }

    childID = payload.childID
    date = payload.date
  }

  private struct Payload: Decodable {
    let childID: Int
    let date: CalendarDay

    enum CodingKeys: String, CodingKey {
      case childID = "child_id"
      case date
    }
  }
}

final class DayComponent: BridgeComponent {
  override nonisolated class var name: String { "day" }

  override func onReceive(message: Message) {
    guard message.event == "done",
          let done = DayDone(jsonData: message.jsonData, pageURL: delegate?.webView?.url, startLocation: Shell.startLocation)
    else { return }

    Shell.dayDone.dayDone(done)
  }
}
