import GateKit
@preconcurrency import HotwireNative
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    #if DEBUG
    if Probe.isRequested { return true }
    #endif
    Shell.dayDone = Shell.daySync
    // Scenes read this when they connect, so it has to be in place first.
    Shell.repairingPrompt = Shell.parentScreens
    Shell.followAuthorization()
    Hotwire.registerBridgeComponents([DayComponent.self])
    Hotwire.registerRouteDecisionHandlers(Shell.routeDecisionHandlers)
    Hotwire.config.defaultNavigationController = { NavigationController() }
    Hotwire.config.makeCustomErrorView = { error, handler in ShellErrorView(error: error, handler: handler) }
    Hotwire.loadPathConfiguration(from: [.file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!)])
    // Visited URLs include the pairing link, which is a credential.
    #if DEBUG
    Hotwire.config.debugLoggingEnabled = true
    #endif
    Shell.startGate()
    return true
  }
}
