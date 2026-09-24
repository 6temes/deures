import Foundation
import WebKit

@MainActor
protocol PairingStatus {
  func isPaired() async -> Bool
}

// The device cookie is httponly, so the web view's own store is the only place it can be seen.
struct DeviceCookiePairing: PairingStatus {
  let host: String

  func isPaired() async -> Bool {
    let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
    return cookies.contains { $0.name == "device_token" && $0.domain.trimmingPrefix(".").lowercased() == host.lowercased() }
  }
}

@MainActor
protocol RepairingPrompt {
  func askBeforeRepairing(then proceed: @escaping @MainActor () -> Void)
}

struct RefuseRepairing: RepairingPrompt {
  func askBeforeRepairing(then proceed: @escaping @MainActor () -> Void) {}
}

// The site association lists only the pairing link, so on a paired iPad every incoming link waits
// for the parent: a sibling's code must not reach the web view, where loading it spends the token.
@MainActor
final class IncomingLinks {
  enum Outcome {
    case dropped, held, routed
  }

  private let startLocation: URL
  private let pairing: any PairingStatus
  private let prompt: any RepairingPrompt
  private let route: @MainActor (URL) -> Void

  init(startLocation: URL, pairing: any PairingStatus, prompt: any RepairingPrompt, route: @escaping @MainActor (URL) -> Void) {
    self.startLocation = startLocation
    self.pairing = pairing
    self.prompt = prompt
    self.route = route
  }

  @discardableResult
  func open(_ url: URL) async -> Outcome {
    guard url.isOnStartHost(startLocation) else { return .dropped }

    if await pairing.isPaired() {
      prompt.askBeforeRepairing { [route] in route(url) }
      return .held
    }

    route(url)
    return .routed
  }
}
