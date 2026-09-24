import Foundation
import Testing
@testable import Deures

struct DeviceCookieScrubTests {
  let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "deures-tests-\(UUID().uuidString)")

  func cookie(_ name: String, domain: String) throws -> HTTPCookie {
    try #require(HTTPCookie(properties: [.name: name, .value: "x", .domain: domain, .path: "/"]))
  }

  @Test func deletesTheDeviceCookieForTheStartHostAndNothingElse() throws {
    let device = try cookie("device_token", domain: "deures.example.com")
    let dotted = try cookie("device_token", domain: ".deures.example.com")
    let session = try cookie("_deures_session", domain: "deures.example.com")
    let elsewhere = try cookie("device_token", domain: "other.example.com")
    [device, dotted, session, elsewhere].forEach(storage.setCookie)
    #expect(storage.cookies?.count == 4)

    storage.deleteDeviceCookies(for: "deures.example.com")

    #expect(Set(storage.cookies ?? []) == [session, elsewhere])
  }
}
