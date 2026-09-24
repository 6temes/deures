import SwiftUI

struct PINPad: View {
  let title: String
  var message: String?
  var disabled = false
  let submit: (String) -> Void

  @State private var digits = ""

  var body: some View {
    VStack(spacing: 28) {
      Text(title).font(.title2.weight(.semibold))

      HStack(spacing: 16) {
        ForEach(0..<6, id: \.self) { index in
          Circle()
            .strokeBorder(.secondary, lineWidth: 2)
            .background(Circle().fill(index < digits.count ? Color.primary : .clear))
            .frame(width: 18, height: 18)
        }
      }
      .accessibilityElement()
      .accessibilityLabel("\(digits.count) of 6 digits")

      Text(message ?? " ")
        .font(.callout)
        .foregroundStyle(.red)
        .monospacedDigit()

      Grid(horizontalSpacing: 20, verticalSpacing: 16) {
        ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
          GridRow { ForEach(row, id: \.self, content: key) }
        }
        GridRow {
          Color.clear.frame(width: 76, height: 76)
          key("0")
          Button {
            if !digits.isEmpty { digits.removeLast() }
          } label: {
            Image(systemName: "delete.left").font(.title2).frame(width: 76, height: 76)
          }
          .accessibilityLabel("Delete")
        }
      }
      .disabled(disabled)
    }
    .padding(32)
  }

  private func key(_ digit: String) -> some View {
    Button {
      digits.append(digit)
      guard digits.count == 6 else { return }
      submit(digits)
      digits = ""
    } label: {
      Text(digit)
        .font(.title.monospacedDigit())
        .frame(width: 76, height: 76)
        .background(Circle().fill(.quaternary))
    }
    .buttonStyle(.plain)
  }
}

// Counts a lockout down while it lasts: the store only knows when it ends.
struct PINPromptView: View {
  let prompt: PINPrompt
  let title: String
  let submit: (String) -> Void

  var body: some View {
    PINPad(title: title, message: message, disabled: isLocked, submit: submit)
      .task(id: isLocked) {
        while isLocked, !Task.isCancelled {
          try? await Task.sleep(for: .seconds(1))
          prompt.refresh()
        }
      }
  }

  private var isLocked: Bool {
    if case .locked = prompt.status { return true }
    return false
  }

  private var message: String? {
    switch prompt.status {
    case let .locked(remaining):
      let wait = Duration.seconds(remaining.rounded(.up)).formatted(.time(pattern: .minuteSecond))
      return "Too many tries. Try again in \(wait)."
    case .ready:
      return nil
    case .wrong:
      return "That is not the parent PIN."
    }
  }
}
