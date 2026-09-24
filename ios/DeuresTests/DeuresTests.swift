import Foundation
import Testing
@testable import Deures

struct DeuresTests {
  @Test func appHostIsSubstitutedIntoTheBundle() throws {
    let host = try #require(Bundle.main.object(forInfoDictionaryKey: "AppHost") as? String)
    #expect(!host.isEmpty)
    #expect(!host.contains("$("))
  }
}
