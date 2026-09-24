import GateKit
@preconcurrency import HotwireNative
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Hotwire.registerBridgeComponents([DayComponent.self])
    Hotwire.registerRouteDecisionHandlers(Shell.routeDecisionHandlers)
    Hotwire.config.defaultNavigationController = { NavigationController() }
    Hotwire.config.makeCustomErrorView = { error, handler in ShellErrorView(error: error, handler: handler) }
    Hotwire.loadPathConfiguration(from: [.file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!)])
    // Visited URLs include the pairing link, which is a credential.
    #if DEBUG
    Hotwire.config.debugLoggingEnabled = true
    #endif
    return true
  }
}
