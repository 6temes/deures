import FamilyControls
import Foundation
import GateKit

// What the parent picked, reduced to what the gate stores and what the shield can hold: Apple caps
// each exception list at 50 tokens, and a longer one would not be exempted as the parent expects.
struct AllowlistChoice: Equatable {
  static let limit = 50
  static let warning = 45

  let applications: Int
  let data: Data
  let webDomains: Int

  var isNearLimit: Bool {
    max(applications, webDomains) >= Self.warning
  }

  var isOverLimit: Bool {
    max(applications, webDomains) > Self.limit
  }
}

extension AllowlistChoice {
  init(_ selection: FamilyActivitySelection) {
    self.init(applications: selection.applicationTokens.count, data: Allowlist.encode(selection), webDomains: selection.webDomainTokens.count)
  }
}
