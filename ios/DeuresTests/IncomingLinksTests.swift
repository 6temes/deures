import Foundation
import Testing
@testable import Deures

@MainActor
struct IncomingLinksTests {
  let start = URL(string: "https://deures.example.com/")!
  let pairingLink = URL(string: "https://deures.example.com/p?token=abc")!
  let prompt = RecordingPrompt()

  @Test func routesAPairingLinkWhenTheIPadIsUnpaired() async {
    let recorder = RouteRecorder()
    let links = IncomingLinks(startLocation: start, pairing: FixedPairing(paired: false), prompt: prompt, route: recorder.route)

    let outcome = await links.open(pairingLink)

    #expect(outcome == .routed)
    #expect(recorder.urls == [pairingLink])
    #expect(prompt.asked == 0)
  }

  @Test func holdsAPairingLinkForThePromptWhenTheIPadIsPaired() async {
    let recorder = RouteRecorder()
    let links = IncomingLinks(startLocation: start, pairing: FixedPairing(paired: true), prompt: prompt, route: recorder.route)

    let outcome = await links.open(pairingLink)

    #expect(outcome == .held)
    #expect(prompt.asked == 1)
    #expect(recorder.urls.isEmpty)
  }

  @Test func loadsAHeldLinkOnlyOnceThePromptLetsItThrough() async {
    let recorder = RouteRecorder()
    let links = IncomingLinks(startLocation: start, pairing: FixedPairing(paired: true), prompt: prompt, route: recorder.route)

    await links.open(pairingLink)
    prompt.proceed?()

    #expect(recorder.urls == [pairingLink])
  }

  @Test func dropsALinkForAnotherHost() async {
    let recorder = RouteRecorder()
    let links = IncomingLinks(startLocation: start, pairing: FixedPairing(paired: false), prompt: prompt, route: recorder.route)

    let outcome = await links.open(URL(string: "https://elsewhere.example.com/p?token=abc")!)

    #expect(outcome == .dropped)
    #expect(recorder.urls.isEmpty)
    #expect(prompt.asked == 0)
  }

  @Test func refusesRepairingUntilAPromptIsInstalled() {
    var proceeded = false
    RefuseRepairing().askBeforeRepairing { proceeded = true }

    #expect(!proceeded)
  }
}

@MainActor
final class RouteRecorder {
  private(set) var urls: [URL] = []

  func route(_ url: URL) {
    urls.append(url)
  }
}

@MainActor
final class RecordingPrompt: RepairingPrompt {
  private(set) var asked = 0
  private(set) var proceed: (@MainActor () -> Void)?

  func askBeforeRepairing(then proceed: @escaping @MainActor () -> Void) {
    asked += 1
    self.proceed = proceed
  }
}

struct FixedPairing: PairingStatus {
  let paired: Bool

  func isPaired() async -> Bool {
    paired
  }
}
