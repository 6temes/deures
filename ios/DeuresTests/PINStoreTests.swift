import FamilyControls
import Foundation
import Testing
@testable import Deures

final class InMemoryKeychain: Keychain {
  private var items: [String: Data] = [:]

  func read(_ account: String) throws -> Data? {
    items[account]
  }

  func write(_ data: Data, to account: String) throws {
    items[account] = data
  }
}

func pin(_ digits: String) throws -> PIN {
  try #require(PIN(digits))
}

func freshAuthorization() throws -> FreshAuthorization {
  try #require(FreshAuthorization(from: .notDetermined, to: .approved))
}

struct PINStoreTests {
  let keychain = InMemoryKeychain()
  let clock = TestClock(Date(timeIntervalSince1970: 1_789_000_000))

  func makeStore() -> PINStore {
    PINStore(keychain: keychain, now: { [clock] in clock.now })
  }

  func failFiveTimes(_ store: PINStore) throws {
    for _ in 1...5 {
      #expect(try store.verify(pin("000000")) == .rejected)
    }
  }

  @Test func verifiesTheSetPINAndRejectsAnyOther() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    #expect(try store.verify(pin("482913")) == .accepted)
    #expect(try store.verify(pin("482914")) == .rejected)
  }

  @Test func rejectsEverythingBeforeAPINIsSet() throws {
    let store = makeStore()

    #expect(!(try store.isSet))
    #expect(try store.verify(pin("482913")) == .rejected)
  }

  @Test(arguments: ["", "48291", "4829130", "48291a", " 482913", "４８２９１３", "-48291"])
  func acceptsOnlySixDigits(_ input: String) {
    #expect(PIN(input) == nil)
  }

  @Test func storesNeitherThePINNorAnUnsaltedHash() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    let stored = try #require(try keychain.read(PINStore.Account.pin))

    #expect(!String(decoding: stored, as: UTF8.self).contains("482913"))

    let other = InMemoryKeychain()
    try PINStore(keychain: other, now: { [clock] in clock.now }).set(pin("482913"))
    #expect(try other.read(PINStore.Account.pin) != stored)
  }

  @Test func fiveWrongAttemptsLockForOneMinuteAndFiveMoreForTwo() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    for _ in 1...4 {
      #expect(try store.verify(pin("000000")) == .rejected)
    }
    #expect(try store.lockoutRemaining == nil)
    #expect(try store.verify(pin("000000")) == .rejected)
    #expect(try store.lockoutRemaining == 60)
    #expect(try store.verify(pin("482913")) == .locked(remaining: 60))

    clock.advance(by: 59)
    #expect(try store.verify(pin("482913")) == .locked(remaining: 1))

    clock.advance(by: 1)
    #expect(try store.lockoutRemaining == nil)
    try failFiveTimes(store)
    #expect(try store.lockoutRemaining == 120)

    clock.advance(by: 120)
    try failFiveTimes(store)
    #expect(try store.lockoutRemaining == 240)
  }

  @Test func attemptsDuringALockoutDoNotCount() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    #expect(try store.verify(pin("000000")) == .locked(remaining: 60))
    clock.advance(by: 60)
    for _ in 1...4 {
      #expect(try store.verify(pin("000000")) == .rejected)
    }
    #expect(try store.lockoutRemaining == nil)
  }

  @Test func theLockoutEndsAndTheRightPINThenPasses() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    clock.advance(by: 60)
    #expect(try store.verify(pin("482913")) == .accepted)
  }

  @Test func theRightPINResetsTheCount() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    for _ in 1...4 {
      #expect(try store.verify(pin("000000")) == .rejected)
    }
    #expect(try store.verify(pin("482913")) == .accepted)
    for _ in 1...4 {
      #expect(try store.verify(pin("000000")) == .rejected)
    }
    #expect(try store.lockoutRemaining == nil)
  }

  @Test func theLockoutSurvivesANewStore() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    let relaunched = makeStore()
    #expect(try relaunched.verify(pin("482913")) == .locked(remaining: 60))

    clock.advance(by: 60)
    try failFiveTimes(relaunched)
    #expect(try relaunched.lockoutRemaining == 120)
  }

  @Test func windingTheClockBackKeepsTheLockout() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    clock.advance(by: -3600)
    #expect(try store.verify(pin("482913")) != .accepted)
    #expect(try store.lockoutRemaining != nil)
  }

  @Test func windingTheClockBackBeforeTheLastAttemptLocksEvenAfterTheLockoutEnded() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    clock.advance(by: 600)
    #expect(try store.verify(pin("000000")) == .rejected)
    clock.advance(by: -300)

    #expect(try store.verify(pin("482913")) == .locked(remaining: 300))
  }

  @Test func changingThePINNeedsTheCurrentOne() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    #expect(try store.change(from: pin("111111"), to: pin("222222")) == .rejected)
    #expect(try store.verify(pin("482913")) == .accepted)
    #expect(try store.verify(pin("222222")) == .rejected)

    #expect(try store.change(from: pin("482913"), to: pin("222222")) == .accepted)
    #expect(try store.verify(pin("222222")) == .accepted)
    #expect(try store.verify(pin("482913")) == .rejected)
  }

  @Test func wrongCurrentPINsCountTowardTheLockout() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    for _ in 1...5 {
      #expect(try store.change(from: pin("111111"), to: pin("222222")) == .rejected)
    }
    #expect(try store.change(from: pin("482913"), to: pin("222222")) == .locked(remaining: 60))
  }

  @Test func overwritingAPINNeedsAFreshAuthorization() throws {
    let store = makeStore()
    try store.set(pin("482913"))

    #expect(throws: PINStore.Refusal.freshAuthorizationRequired) {
      try store.set(pin("222222"))
    }
    #expect(try store.verify(pin("482913")) == .accepted)

    try store.set(pin("222222"), authorization: freshAuthorization())
    #expect(try store.verify(pin("222222")) == .accepted)
  }

  @Test func anAuthorizedOverwriteClearsTheLockout() throws {
    let store = makeStore()
    try store.set(pin("482913"))
    try failFiveTimes(store)

    try store.set(pin("222222"), authorization: freshAuthorization())
    #expect(try store.lockoutRemaining == nil)
    #expect(try store.verify(pin("222222")) == .accepted)
  }

  @Test func aFreshAuthorizationIsOnlyTheMoveToApproved() {
    #expect(FreshAuthorization(from: .notDetermined, to: .approved) != nil)
    #expect(FreshAuthorization(from: .denied, to: .approved) != nil)
    #expect(FreshAuthorization(from: .approved, to: .approved) == nil)
    #expect(FreshAuthorization(from: .notDetermined, to: .denied) == nil)
    #expect(FreshAuthorization(from: .approved, to: .denied) == nil)
  }
}
