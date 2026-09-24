import Foundation
@preconcurrency import HotwireNative

@MainActor
enum Shell {
  nonisolated static let startLocation = URL(string: "https://\(Bundle.main.object(forInfoDictionaryKey: "AppHost") as! String)/")!

  static var dayDone: any DayDoneHandling = IgnoreDayDone()
  static var repairingPrompt: any RepairingPrompt = RefuseRepairing()

  static var routeDecisionHandlers: [any RouteDecisionHandler] {
    [StartHostRouteDecisionHandler()]
  }
}

extension URL {
  func isOnStartHost(_ startLocation: URL) -> Bool {
    scheme?.lowercased() == startLocation.scheme?.lowercased() && host()?.lowercased() == startLocation.host()?.lowercased()
  }
}

// Replaces Hotwire's defaults, which open any other host in an in-app Safari view or in Safari
// itself: either would make the app a browser the shield does not cover.
struct StartHostRouteDecisionHandler: RouteDecisionHandler {
  let name = "start-host"

  func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
    true
  }

  func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: Navigating) -> Router.Decision {
    proposal.url.isOnStartHost(configuration.startLocation) ? .navigate : .cancel
  }
}

enum LoadFailure: Equatable {
  case notPaired, unreachable

  init(_ error: HotwireNativeError) {
    self = error == .http(.client(.unauthorized)) ? .notPaired : .unreachable
  }
}
