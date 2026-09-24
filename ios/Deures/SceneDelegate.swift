@preconcurrency import HotwireNative
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private lazy var navigator = Navigator(configuration: Navigator.Configuration(name: "main", startLocation: Shell.startLocation))
  private lazy var links = IncomingLinks(
    startLocation: Shell.startLocation,
    pairing: DeviceCookiePairing(host: Shell.startLocation.host()!),
    prompt: Shell.repairingPrompt,
    route: { [weak self] in self?.navigator.route($0) }
  )

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navigator.rootViewController
    window.makeKeyAndVisible()
    self.window = window

    if let url = connectionOptions.userActivities.lazy.compactMap(Self.webpageURL).first {
      Task {
        if await links.open(url) != .routed { navigator.start() }
      }
    } else {
      navigator.start()
    }
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = Self.webpageURL(userActivity) else { return }
    Task { await links.open(url) }
  }

  private static func webpageURL(_ activity: NSUserActivity) -> URL? {
    activity.activityType == NSUserActivityTypeBrowsingWeb ? activity.webpageURL : nil
  }
}
