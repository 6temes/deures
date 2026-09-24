import Observation
import SwiftUI
import UIKit

// The grown-up screens live in their own window above the study screen, so they never enter
// Hotwire's navigation stack. The way in from the study screen is a three-second press in its
// top-left corner, which a child is unlikely to find and which leaves every tap to the web view.
@MainActor
final class ParentWindow: NSObject, UIGestureRecognizerDelegate {
  private static let corner = CGSize(width: 88, height: 88)

  private weak var main: UIWindow?
  private let overlay: UIWindow
  private let screens: ParentScreens

  init(scene: UIWindowScene, main: UIWindow, screens: ParentScreens) {
    self.main = main
    self.screens = screens
    overlay = UIWindow(windowScene: scene)
    super.init()

    overlay.windowLevel = .normal + 1
    overlay.rootViewController = UIHostingController(rootView: ParentOverlayView(screens: screens))
    overlay.isHidden = true

    let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed))
    press.minimumPressDuration = 3
    press.cancelsTouchesInView = false
    press.delegate = self
    main.addGestureRecognizer(press)

    follow()
  }

  private func follow() {
    withObservationTracking {
      show(screens.overlay != nil)
    } onChange: { [weak self] in
      Task { @MainActor in self?.follow() }
    }
  }

  private func show(_ showing: Bool) {
    guard showing == overlay.isHidden else { return }
    if showing {
      overlay.makeKeyAndVisible()
    } else {
      overlay.isHidden = true
      main?.makeKey()
    }
  }

  @objc private func pressed(_ press: UILongPressGestureRecognizer) {
    if press.state == .began { screens.openParentAccess() }
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    CGRect(origin: .zero, size: Self.corner).contains(touch.location(in: main))
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
    true
  }
}
