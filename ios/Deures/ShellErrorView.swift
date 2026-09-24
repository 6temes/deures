@preconcurrency import HotwireNative
import SwiftUI

// Child-facing, so nothing to read: the same grown-up figure the web shows when an iPad has lost
// its pairing, and otherwise a single button to try again.
struct ShellErrorView: @preconcurrency ErrorPresentableView {
  let error: HotwireNativeError
  let handler: ErrorPresenter.Handler?

  var body: some View {
    ZStack {
      Color(Self.ground).ignoresSafeArea()

      switch LoadFailure(error) {
      case .notPaired:
        GrownUp()
          .stroke(Color(Self.muted), style: StrokeStyle(lineWidth: 6, lineCap: .round))
          .frame(width: 96, height: 96)
          .accessibilityLabel("Ask a grown-up to pair this iPad")
      case .unreachable:
        Button {
          handler?()
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 56, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(Self.muted))
            .frame(width: 120, height: 120)
        }
        .accessibilityLabel("Try again")
      }
    }
  }

  private static let ground = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x201e1c) : UIColor(rgb: 0xe4e1db) }
  private static let muted = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xa39c92) : UIColor(rgb: 0x6f6a62) }
}

private struct GrownUp: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = min(rect.width, rect.height) / 64
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit) }

    var path = Path()
    path.addEllipse(in: CGRect(origin: point(21, 10), size: CGSize(width: 22 * unit, height: 22 * unit)))
    path.move(to: point(11, 56))
    path.addCurve(to: point(32, 38), control1: point(11, 44.4), control2: point(20.4, 38))
    path.addCurve(to: point(53, 56), control1: point(43.6, 38), control2: point(53, 44.4))
    return path
  }
}

private extension UIColor {
  convenience init(rgb: Int) {
    self.init(red: CGFloat(rgb >> 16 & 0xff) / 255, green: CGFloat(rgb >> 8 & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
  }
}
