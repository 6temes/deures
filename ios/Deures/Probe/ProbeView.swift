#if DEBUG
import FamilyControls
import GateKit
import SwiftUI

// Drills D1 and D2, run from Xcode with the launch argument `-DeuresProbe YES`. The probe writes
// the gate's own store, so what it proves is what the gate will do, but it never touches the
// snapshot or the setup flag, and the app skips the gate entirely while it is showing.
enum Probe {
  static var isRequested: Bool {
    UserDefaults.standard.bool(forKey: "DeuresProbe")
  }
}

struct ProbeView: View {
  @State private var authorization = AuthorizationCenter.shared.authorizationStatus
  @State private var failure: String?
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()

  private let shield = ManagedSettingsShield()

  var body: some View {
    NavigationStack {
      Form {
        Section("D1: authorization") {
          LabeledContent("Status", value: String(describing: authorization))
          if let failure { Text(failure).foregroundStyle(.red) }
          Button("Request child authorization") { Task { await authorize() } }
        }
        Section {
          Button("Pick the allowlist") { picking = true }
          LabeledContent("Apps", value: "\(selection.applicationTokens.count)")
          LabeledContent("Websites", value: "\(selection.webDomainTokens.count)")
          LabeledContent("Categories, not exempted", value: "\(selection.categoryTokens.count)")
        } header: {
          Text("D2: allowlist")
        } footer: {
          Text("Pick individual apps: a shield of all categories cannot exempt a whole category.")
        }
        Section("D2: shield") {
          Button("Shield all except picked") { shield.apply(.apply(exceptions: Allowlist.encode(selection))) }
          Button("Clear", role: .destructive) { shield.apply(.clear) }
        }
      }
      .navigationTitle("Device probe")
      .familyActivityPicker(isPresented: $picking, selection: $selection)
    }
  }

  private func authorize() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .child)
      failure = nil
    } catch {
      failure = String(describing: error)
    }
    authorization = AuthorizationCenter.shared.authorizationStatus
  }
}
#endif
