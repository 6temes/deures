#if os(iOS)
import FamilyControls
import ManagedSettings

// The one store the gate writes. The app, the extension and the probe must all name the same one:
// across stores the most restrictive setting wins, so a second store could never be lifted.
public struct ManagedSettingsShield: ShieldWriter {
  private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("gate"))

  public init() {}

  public func apply(_ decision: GateDecision) {
    switch decision {
    case let .apply(exceptions):
      let selection = exceptions.flatMap(Allowlist.selection(from:)) ?? FamilyActivitySelection()
      store.shield.applicationCategories = .all(except: selection.applicationTokens)
      store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
    case .clear:
      store.shield.applicationCategories = nil
      store.shield.webDomainCategories = nil
    case .leave:
      break
    }
  }
}
#endif
