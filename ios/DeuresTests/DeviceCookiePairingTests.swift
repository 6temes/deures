import Foundation
import Testing
import WebKit
@testable import Deures

@MainActor
@Suite(.serialized)
struct DeviceCookiePairingTests {
  let store = WKWebsiteDataStore.default().httpCookieStore

  @Test func isPairedOnceTheDeviceCookieIsSetForTheStartHost() async throws {
    let cookie = try #require(HTTPCookie(properties: [.name: "device_token", .value: "x", .domain: "pairing.example.com", .path: "/"]))
    await store.setCookie(cookie)
    defer { Task { await store.deleteCookie(cookie) } }

    #expect(await DeviceCookiePairing(host: "pairing.example.com").isPaired())
    #expect(await !DeviceCookiePairing(host: "other.example.com").isPaired())
  }

  @Test func isNotPairedByAnotherCookie() async throws {
    let cookie = try #require(HTTPCookie(properties: [.name: "session", .value: "x", .domain: "unpaired.example.com", .path: "/"]))
    await store.setCookie(cookie)
    defer { Task { await store.deleteCookie(cookie) } }

    #expect(await !DeviceCookiePairing(host: "unpaired.example.com").isPaired())
  }
}
