import FamilyControls
import GateKit
import SwiftUI

struct ParentOverlayView: View {
  let screens: ParentScreens

  var body: some View {
    switch screens.overlay {
    case .askGrownUp:
      AskGrownUpView { Task { await screens.refresh() } }
    case let .parent(session):
      ParentSessionView(session: session)
    case let .repairing(request):
      RepairingView(request: request)
    case let .setup(flow):
      SetupView(flow: flow)
    case nil:
      Color.clear
    }
  }
}

// Child-facing, like the shell's error screen: the grown-up figure and nothing to read. The arrow
// asks for Screen Time again, which only a parent can approve.
struct AskGrownUpView: View {
  let retry: () -> Void

  var body: some View {
    ZStack {
      Color(ShellErrorView.ground).ignoresSafeArea()

      VStack(spacing: 48) {
        GrownUp()
          .stroke(Color(ShellErrorView.muted), style: StrokeStyle(lineWidth: 6, lineCap: .round))
          .frame(width: 96, height: 96)
          .accessibilityLabel("Ask a grown-up to allow Screen Time")
        Button(action: retry) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(ShellErrorView.muted))
            .frame(width: 96, height: 96)
        }
        .accessibilityLabel("Try again")
      }
    }
  }
}

struct SetupView: View {
  let flow: SetupFlow

  var body: some View {
    NavigationStack {
      Group {
        switch flow.step {
        case .choosePIN:
          PINPad(
            title: flow.newPIN.isConfirming ? "Type the parent PIN again" : "Choose a six-digit parent PIN",
            message: flow.newPIN.mismatched ? "The two PINs were different. Start again." : nil,
            submit: flow.enterNewPIN
          )
        case .currentPIN:
          PINPromptView(prompt: flow.currentPIN, title: "Enter the parent PIN", submit: flow.enterCurrentPIN)
        case .allowlist:
          AllowlistEditor(initial: nil, save: flow.save)
        case .scanPairingCode:
          ScanPairingCodeView(failed: flow.failed, done: flow.finish)
        }
      }
      .navigationTitle("Set up Deures")
    }
  }
}

private struct ScanPairingCodeView: View {
  let failed: Bool
  let done: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "qrcode.viewfinder").font(.system(size: 72)).foregroundStyle(.secondary)
      Text("Pair this iPad").font(.title2.weight(.semibold))
      Text("Issue this child's pairing code from the console, then scan it with this iPad's Camera. Deures opens and signs the child in.")
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
      Text("Allowed apps start being enforced when you tap Done.")
        .font(.callout)
        .foregroundStyle(.secondary)
      if failed {
        Text("Setup could not be saved on this iPad. Tap Done to try again.")
          .foregroundStyle(.red)
      }
      Button("Done", action: done).buttonStyle(.borderedProminent)
    }
    .padding(32)
  }
}

struct AllowlistEditor: View {
  let save: (AllowlistChoice) -> Void

  @State private var picking = false
  @State private var selection: FamilyActivitySelection

  init(initial: Data?, save: @escaping (AllowlistChoice) -> Void) {
    self.save = save
    _selection = State(initialValue: initial.flatMap(Allowlist.selection(from:)) ?? FamilyActivitySelection())
  }

  var body: some View {
    let choice = AllowlistChoice(selection)

    Form {
      Section {
        Button("Choose allowed apps") { picking = true }
        LabeledContent("Apps", value: "\(choice.applications) of \(AllowlistChoice.limit)")
        LabeledContent("Websites", value: "\(choice.webDomains) of \(AllowlistChoice.limit)")
      } footer: {
        Text("Everything else is blocked until the day's cards are done. Pick individual apps: choosing a whole category does not allow it.")
      }

      if choice.isOverLimit {
        Text("Screen Time can allow at most \(AllowlistChoice.limit) apps and \(AllowlistChoice.limit) websites. Remove some before saving.")
          .foregroundStyle(.red)
      } else if choice.isNearLimit {
        Text("Close to the limit of \(AllowlistChoice.limit).")
          .foregroundStyle(.orange)
      }

      Button("Save") { save(choice) }
    }
    .familyActivityPicker(isPresented: $picking, selection: $selection)
  }
}

struct ParentSessionView: View {
  let session: ParentSession

  var body: some View {
    NavigationStack {
      content
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            if session.screen == .pin || session.screen == .menu {
              Button("Close", action: session.dismiss)
            } else {
              Button("Back") { session.open(.menu) }
            }
          }
        }
    }
  }

  @ViewBuilder private var content: some View {
    switch session.screen {
    case .pin:
      PINPromptView(prompt: session.prompt, title: "Enter the parent PIN", submit: session.enter)
    case .menu:
      List {
        Button("Unlock for today", systemImage: "lock.open", action: session.unlockForToday)
        Button("Change allowed apps", systemImage: "square.grid.2x2") { session.open(.allowlist) }
        Button("Change PIN", systemImage: "key") { session.open(.changePIN) }
      }
      .navigationTitle("Parent")
    case .allowlist:
      AllowlistEditor(initial: session.allowlist, save: session.save)
        .navigationTitle("Allowed apps")
    case .changePIN:
      if session.change.current == nil {
        PINPromptView(prompt: session.change.prompt, title: "Enter the current PIN", submit: session.enterForChange)
      } else {
        PINPad(
          title: session.change.newPIN.isConfirming ? "Type the new PIN again" : "Choose a new six-digit PIN",
          message: session.change.newPIN.mismatched ? "The two PINs were different. Start again." : nil,
          submit: session.enterForChange
        )
      }
    }
  }
}

struct RepairingView: View {
  let request: RepairingRequest

  var body: some View {
    NavigationStack {
      PINPromptView(prompt: request.prompt, title: "Enter the parent PIN to pair this iPad again", submit: request.enter)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: request.cancel)
          }
        }
    }
  }
}
