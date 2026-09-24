import Foundation
@preconcurrency import HotwireNative
import Testing
import UIKit
@testable import Deures

@MainActor
struct ShellTests {
  let configuration = Navigator.Configuration(name: "main", startLocation: URL(string: "https://deures.example.com/")!)

  @Test func navigatesWithinTheStartHost() {
    let navigator = FakeNavigator()

    #expect(decide("https://deures.example.com/p?token=abc", navigator) == .navigate)
  }

  @Test(arguments: ["https://elsewhere.example.com/", "http://deures.example.com/", "mailto:someone@example.com", "https://deures.example.com.evil.example/"])
  func dropsAURLOffTheStartHostWithoutPresentingIt(url: String) {
    let navigator = FakeNavigator()

    #expect(decide(url, navigator) == .cancel)
  }

  @Test(arguments: ["/", "/p?token=abc", "/day", "/answers", "/anything/else"])
  func bundledPathConfigurationTurnsOffPullToRefreshAndReplacesTheRoot(path: String) throws {
    let file = try #require(Bundle.main.url(forResource: "path-configuration", withExtension: "json"))
    let pathConfiguration = PathConfiguration(sources: [.file(file)])
    let properties = pathConfiguration.properties(for: path)

    #expect(properties.pullToRefreshEnabled == false)
    #expect(properties.presentation == .replaceRoot)
  }

  @Test func theNavigationControllerHasNoBarAndNoBackGesture() {
    let controller = Hotwire.config.defaultNavigationController()
    controller.loadViewIfNeeded()

    #expect(controller is HotwireNavigationController)
    #expect(controller.isNavigationBarHidden)
    #expect(controller.interactivePopGestureRecognizer?.isEnabled == false)
  }

  @Test func anUnauthorizedVisitAsksForAGrownUp() {
    #expect(LoadFailure(.http(.client(.unauthorized))) == .notPaired)
  }

  @Test(arguments: [
    HotwireNativeError.web(WebError(errorCode: -1009, message: "offline")),
    .http(.server(.badGateway)),
    .http(.client(.notFound))
  ])
  func anyOtherFailureIsRetried(error: HotwireNativeError) {
    #expect(LoadFailure(error) == .unreachable)
  }

  private func decide(_ url: String, _ navigator: FakeNavigator) -> Router.Decision? {
    let proposal = VisitProposal(url: URL(string: url)!, options: VisitOptions())
    let handler = Shell.routeDecisionHandlers.first { $0.matches(proposal: proposal, configuration: configuration) }
    return handler?.handle(proposal: proposal, configuration: configuration, navigator: navigator) ?? .cancel
  }
}

@MainActor
final class FakeNavigator: @preconcurrency Navigating {
  let rootViewController = UINavigationController()
  let modalRootViewController = UINavigationController()
  var activeNavigationController: UINavigationController { rootViewController }

  func route(_ url: URL, options: VisitOptions?, parameters: [String: Any]?) {}
  func route(_ proposal: VisitProposal) {}

  func pop(animated: Bool) {}
  func clearAll(animated: Bool) {}
  func reload() {}
}
