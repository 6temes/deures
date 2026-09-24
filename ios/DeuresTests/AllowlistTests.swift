import FamilyControls
import Foundation
import GateKit
import Testing

struct AllowlistTests {
  @Test func roundTripsAPickerSelection() throws {
    let selection = FamilyActivitySelection(includeEntireCategory: true)

    let decoded = try #require(Allowlist.selection(from: Allowlist.encode(selection)))

    #expect(decoded == selection)
    #expect(decoded != FamilyActivitySelection())
  }

  @Test func anythingElseIsNoSelection() {
    #expect(Allowlist.selection(from: Data("allowlist-tokens".utf8)) == nil)
    #expect(Allowlist.selection(from: Data()) == nil)
  }
}
