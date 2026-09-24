@preconcurrency import HotwireNative
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private var pairingLinkRouted = false
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

  // Also runs on launch, so every launch and every return to the app reads the day and re-evaluates,
  // which is what re-arms the gate on the first launch of each household day.
  func sceneWillEnterForeground(_ scene: UIScene) {
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
    guard pairingLinkRouted else { return }
    pairingLinkRouted = false
    Task { await Shell.daySync.sync() }
  }
}
