@preconcurrency import HotwireNative
#if DEBUG
import SwiftUI
#endif
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private var pairingLinkRouted = false
  private var parentWindow: ParentWindow?
  private lazy var navigator = Navigator(configuration: Navigator.Configuration(name: "main", startLocation: Shell.startLocation), delegate: self)
  private lazy var links = IncomingLinks(
    startLocation: Shell.startLocation,
    pairing: DeviceCookiePairing(host: Shell.startLocation.host()!),
    prompt: Shell.repairingPrompt,
    route: { [weak self] in
      self?.pairingLinkRouted = true
      self?.navigator.route($0)
    }
  )

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window
    #if DEBUG
    if Probe.isRequested {
      window.rootViewController = UIHostingController(rootView: ProbeView())
      window.makeKeyAndVisible()
      return
    }
    #endif
    window.rootViewController = navigator.rootViewController
    window.makeKeyAndVisible()
    parentWindow = ParentWindow(scene: windowScene, main: window, screens: Shell.parentScreens)

    if let url = connectionOptions.userActivities.lazy.compactMap(Self.webpageURL).first {
      Task {
        if await links.open(url) != .routed { navigator.start() }
      }
    } else {
      navigator.start()
    }
  }

  // Also runs on launch, so every launch and every return to the app reads the day and re-evaluates,
  // which is what re-arms the gate on the first launch of each household day.
  func sceneWillEnterForeground(_ scene: UIScene) {
    #if DEBUG
    if Probe.isRequested { return }
    #endif
    Task { await Shell.parentScreens.refresh() }
    Task { await Shell.daySync.sync() }
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = Self.webpageURL(userActivity) else { return }
    Task { await links.open(url) }
  }

  private static func webpageURL(_ activity: NSUserActivity) -> URL? {
    activity.activityType == NSUserActivityTypeBrowsingWeb ? activity.webpageURL : nil
  }
}

// The pairing link sets the device cookie, so the day can only be read once its visit has finished.
extension SceneDelegate: @preconcurrency NavigatorDelegate {
  func requestDidFinish(at url: URL) {
    HTTPCookieStorage.shared.deleteDeviceCookies(for: Shell.startLocation.host()!)
    guard pairingLinkRouted else { return }
    pairingLinkRouted = false
    Task { await Shell.daySync.sync() }
  }
}
