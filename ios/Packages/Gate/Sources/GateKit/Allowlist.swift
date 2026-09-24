#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

// The allowlist travels through GateCore as opaque data; only GateKit knows it is a picker selection.
public enum Allowlist {
  public static func encode(_ selection: FamilyActivitySelection) -> Data {
    try! JSONEncoder().encode(selection)
  }

  public static func selection(from data: Data) -> FamilyActivitySelection? {
    try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  // iOS 26.5 sends expiry notices for tokens that are still good, so a failed refresh keeps the
  // allowlist as it was rather than dropping the parent's picks.
  @available(iOS 26.5, *)
  public static func refreshed(_ data: Data) -> Data? {
    guard var selection = selection(from: data) else { return nil }

    var applications = Array(selection.applicationTokens)
    var webDomains = Array(selection.webDomainTokens)
    do {
      try ManagedSettingsStore.refresh(&applications)
      try ManagedSettingsStore.refresh(&webDomains)
    } catch {
      return nil
    }
    selection.applicationTokens = Set(applications)
    selection.webDomainTokens = Set(webDomains)
    return encode(selection)
  }
}
#endif
