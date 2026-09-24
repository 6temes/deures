import Foundation

final class TestClock {
  var now: Date

  init(_ now: Date) {
    self.now = now
  }

  func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }
}
