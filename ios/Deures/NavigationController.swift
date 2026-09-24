import HotwireNative
import UIKit

final class NavigationController: HotwireNavigationController {
  override func viewDidLoad() {
    super.viewDidLoad()
    setNavigationBarHidden(true, animated: false)
    interactivePopGestureRecognizer?.isEnabled = false
  }
}
