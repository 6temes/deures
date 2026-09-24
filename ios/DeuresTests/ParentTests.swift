import FamilyControls
import Foundation
import GateKit
import Testing
@testable import Deures

final class MemorySnapshotStore: SnapshotStore {
  private(set) var snapshot: Snapshot?

  init(_ snapshot: Snapshot? = nil) {
    self.snapshot = snapshot
  }

  func load() -> Snapshot? {
    snapshot
  }

  func save(_ snapshot: Snapshot) {
    self.snapshot = snapshot
  }
}

final class RecordingSetupFlag: SetupFlagRecording {
  var flag = SetupFlag.absent
  private let store: any SnapshotStore
  private(set) var allowlistWhenRecorded: [Data?] = []

  init(store: any SnapshotStore) {
    self.store = store
  }

  func read() -> SetupFlag {
    flag
  }

  func recordCompleted() throws {
    allowlistWhenRecorded.append(store.load()?.allowlist)
    flag = .completed
  }
}

@MainActor
final class ParentFixture {
  let allowlist = Data("allowlist-tokens".utf8)
  let clock = TestClock(ISO8601DateFormatter().date(from: "2026-09-14T20:00:00Z")!)
  let keychain = InMemoryKeychain()
  let shield = RecordingShield()
  let store: MemorySnapshotStore
  let flag: RecordingSetupFlag

  init(snapshot: Snapshot? = nil, setup: SetupFlag = .completed) {
    store = MemorySnapshotStore(snapshot)
    flag = RecordingSetupFlag(store: store)
    flag.flag = setup
    shield.store = store
  }

  var pins: PINStore {
    PINStore(keychain: keychain, now: { [clock] in clock.now })
  }

  var evaluator: GateEvaluator {
    GateEvaluator(store: store, setup: flag, shield: shield, deviceZone: { .gmt })
  }

  func withPIN(_ digits: String = "482913") throws -> Self {
    try pins.set(pin(digits))
    return self
  }

  func session(close: @escaping @MainActor () -> Void = {}) -> ParentSession {
    ParentSession(pins: pins, evaluator: evaluator, clock: { [clock] in clock.now }, deviceZone: { .gmt }, close: close)
  }

  func setup(authorization: FreshAuthorization? = nil, finished: @escaping @MainActor () -> Void = {}) -> SetupFlow {
    SetupFlow(pins: pins, evaluator: evaluator, flag: flag, authorization: authorization, clock: { [clock] in clock.now }, finished: finished)
  }

  func choice(applications: Int = 3, webDomains: Int = 0) -> AllowlistChoice {
    AllowlistChoice(applications: applications, data: allowlist, webDomains: webDomains)
  }
}

let pendingInTokyo = Snapshot(
  allowlist: Data("allowlist-tokens".utf8),
  childID: 1,
  lastAnswer: Snapshot.ServerDay(childID: 1, fetchedAt: Date(timeIntervalSince1970: 0), state: .pending, today: CalendarDay("2026-09-15")!),
  latestServerToday: CalendarDay("2026-09-15")!,
  zoneIdentifier: "Asia/Tokyo"
)

@MainActor
struct PINPromptTests {
  @Test func aWrongPINShowsTheErrorAndTheRightOnePasses() throws {
    let fixture = try ParentFixture().withPIN()
    let prompt = PINPrompt(pins: fixture.pins)

    #expect(prompt.status == .ready)
    #expect(!prompt.submit("000000"))
    #expect(prompt.status == .wrong)
    #expect(prompt.submit("482913"))
    #expect(prompt.status == .ready)
  }

  @Test func aLockedOutPromptShowsTheTimeRemainingAndCountsDown() throws {
    let fixture = try ParentFixture().withPIN()
    let prompt = PINPrompt(pins: fixture.pins)

    for _ in 1...4 {
      prompt.submit("000000")
    }
    #expect(prompt.status == .wrong)
    prompt.submit("000000")
    #expect(prompt.status == .locked(remaining: 60))

    fixture.clock.advance(by: 25)
    prompt.refresh()
    #expect(prompt.status == .locked(remaining: 35))

    #expect(!prompt.submit("482913"))
    #expect(prompt.status == .locked(remaining: 35))

    fixture.clock.advance(by: 35)
    prompt.refresh()
    #expect(prompt.status == .ready)
    #expect(prompt.submit("482913"))
  }

  @Test func aPromptOpenedDuringALockoutStartsLocked() throws {
    let fixture = try ParentFixture().withPIN()
    for _ in 1...5 {
      _ = try fixture.pins.verify(pin("000000"))
    }

    #expect(PINPrompt(pins: fixture.pins).status == .locked(remaining: 60))
  }

  @Test func aNewPINMustBeTypedTheSameTwice() {
    let entry = NewPINEntry()

    #expect(entry.enter("111111") == nil)
    #expect(entry.isConfirming)
    #expect(entry.enter("222222") == nil)
    #expect(entry.mismatched)
    #expect(!entry.isConfirming)

    #expect(entry.enter("333333") == nil)
    #expect(entry.enter("333333") == PIN("333333"))
  }
}

@MainActor
struct ParentSessionTests {
  // Covers AE5.
  @Test func unlockingForTodayWritesTheHouseholdDateAndClears() throws {
    let fixture = try ParentFixture(snapshot: pendingInTokyo).withPIN()
    var closed = false
    let session = fixture.session { closed = true }

    session.enter("482913")
    session.unlockForToday()

    #expect(fixture.store.load()?.pinUnlock == CalendarDay("2026-09-15"))
    #expect(fixture.shield.decisions == [.clear])
    #expect(fixture.shield.persistedAtApply.map { $0?.pinUnlock } == [CalendarDay("2026-09-15")])
    #expect(closed)
  }

  @Test func unlockingWithoutAHouseholdZoneUsesTheDeviceZone() throws {
    var snapshot = pendingInTokyo
    snapshot.zoneIdentifier = nil
    snapshot.latestServerToday = nil
    let fixture = try ParentFixture(snapshot: snapshot).withPIN()
    let session = fixture.session()

    session.enter("482913")
    session.unlockForToday()

    #expect(fixture.store.load()?.pinUnlock == CalendarDay("2026-09-14"))
    #expect(fixture.shield.decisions == [.clear])
  }

  @Test func nothingIsReachableBeforeThePINVerifies() throws {
    let fixture = try ParentFixture(snapshot: pendingInTokyo).withPIN()
    let session = fixture.session()

    session.open(.allowlist)
    #expect(session.screen == .pin)

    session.unlockForToday()
    session.save(fixture.choice())
    #expect(fixture.store.load() == pendingInTokyo)
    #expect(fixture.shield.decisions.isEmpty)

    session.enter("000000")
    session.open(.allowlist)
    #expect(session.screen == .pin)
    #expect(session.prompt.status == .wrong)

    session.enter("482913")
    #expect(session.screen == .menu)
    session.open(.allowlist)
    #expect(session.screen == .allowlist)
  }

  @Test func savingTheAllowlistStoresItAndEvaluates() throws {
    let fixture = try ParentFixture(snapshot: pendingInTokyo).withPIN()
    let session = fixture.session()
    let picked = AllowlistChoice(applications: 50, data: Data("new-tokens".utf8), webDomains: 0)

    session.enter("482913")
    session.open(.allowlist)
    session.save(picked)

    #expect(fixture.store.load()?.allowlist == picked.data)
    #expect(fixture.shield.decisions == [.apply(exceptions: picked.data)])
    #expect(session.screen == .menu)
  }

  @Test(arguments: [(51, 0), (0, 51)])
  func savingMoreThanFiftyIsRefused(applications: Int, webDomains: Int) throws {
    let fixture = try ParentFixture(snapshot: pendingInTokyo).withPIN()
    let session = fixture.session()

    session.enter("482913")
    session.open(.allowlist)
    session.save(AllowlistChoice(applications: applications, data: Data("too-many".utf8), webDomains: webDomains))

    #expect(session.refusedAllowlist)
    #expect(session.screen == .allowlist)
    #expect(fixture.store.load()?.allowlist == pendingInTokyo.allowlist)
    #expect(fixture.shield.decisions.isEmpty)
  }

  @Test func theLimitWarnsBeforeItRefuses() {
    let fixture = ParentFixture()

    #expect(!fixture.choice(applications: 44).isNearLimit)
    #expect(fixture.choice(applications: 45).isNearLimit)
    #expect(!fixture.choice(applications: 50).isOverLimit)
    #expect(fixture.choice(applications: 51).isOverLimit)
  }

  @Test func changingThePINNeedsTheCurrentOneThenTheNewOneTwice() throws {
    let fixture = try ParentFixture().withPIN()
    let session = fixture.session()
    session.enter("482913")
    session.open(.changePIN)

    session.enterForChange("111111")
    #expect(session.change.prompt.status == .wrong)
    #expect(session.change.current == nil)

    session.enterForChange("482913")
    session.enterForChange("222222")
    session.enterForChange("333333")
    #expect(session.change.newPIN.mismatched)
    #expect(try fixture.pins.verify(pin("482913")) == .accepted)

    session.enterForChange("222222")
    session.enterForChange("222222")
    #expect(session.screen == .menu)
    #expect(try fixture.pins.verify(pin("222222")) == .accepted)
    #expect(try fixture.pins.verify(pin("482913")) == .rejected)
  }
}

@MainActor
struct SetupFlowTests {
  @Test func firstRunSetsThePINThenSavesTheAllowlistThenRecordsTheFlag() throws {
    let fixture = ParentFixture(setup: .absent)
    let setup = fixture.setup()

    #expect(setup.step == .choosePIN)
    setup.enterNewPIN("482913")
    setup.enterNewPIN("482913")
    #expect(setup.step == .allowlist)
    #expect(try fixture.pins.verify(pin("482913")) == .accepted)
    #expect(fixture.flag.allowlistWhenRecorded.isEmpty)

    setup.save(fixture.choice())

    #expect(fixture.flag.allowlistWhenRecorded == [fixture.allowlist])
    #expect(setup.step == .scanPairingCode)
  }

  @Test func theGateIsEvaluatedWhenTheParentFinishes() {
    let fixture = ParentFixture(setup: .absent)
    var finished = false
    let setup = fixture.setup { finished = true }
    setup.enterNewPIN("482913")
    setup.enterNewPIN("482913")
    setup.save(fixture.choice())
    #expect(fixture.shield.decisions.isEmpty)

    setup.finish()

    #expect(fixture.shield.decisions == [.apply(exceptions: fixture.allowlist)])
    #expect(finished)
  }

  @Test func aMismatchedPINIsNotStored() throws {
    let fixture = ParentFixture(setup: .absent)
    let setup = fixture.setup()

    setup.enterNewPIN("482913")
    setup.enterNewPIN("482914")

    #expect(setup.step == .choosePIN)
    #expect(setup.newPIN.mismatched)
    #expect(!(try fixture.pins.isSet))
  }

  @Test func savingMoreThanFiftyAppsIsRefusedAndTheFlagStaysUnwritten() {
    let fixture = ParentFixture(setup: .absent)
    let setup = fixture.setup()
    setup.enterNewPIN("482913")
    setup.enterNewPIN("482913")

    setup.save(fixture.choice(applications: 51))

    #expect(setup.refusedAllowlist)
    #expect(setup.step == .allowlist)
    #expect(fixture.store.load()?.allowlist == nil)
    #expect(fixture.flag.allowlistWhenRecorded.isEmpty)
  }

  @Test func reRunningWithoutAFreshAuthorizationKeepsThePINAndAsksForIt() throws {
    let fixture = try ParentFixture(setup: .absent).withPIN()
    let setup = fixture.setup()

    #expect(setup.step == .currentPIN)
    setup.save(fixture.choice())
    #expect(fixture.flag.allowlistWhenRecorded.isEmpty)

    setup.enterCurrentPIN("000000")
    #expect(setup.step == .currentPIN)
    #expect(setup.currentPIN.status == .wrong)

    setup.enterCurrentPIN("482913")
    #expect(setup.step == .allowlist)
    #expect(try fixture.pins.verify(pin("482913")) == .accepted)
  }

  @Test func aFreshAuthorizationLetsSetupReplaceTheForgottenPIN() throws {
    let fixture = try ParentFixture(setup: .absent).withPIN()
    let setup = fixture.setup(authorization: try freshAuthorization())

    #expect(setup.step == .choosePIN)
    setup.enterNewPIN("222222")
    setup.enterNewPIN("222222")

    #expect(setup.step == .allowlist)
    #expect(try fixture.pins.verify(pin("222222")) == .accepted)
  }
}

@MainActor
struct ParentScreensTests {
  final class FakeCenter {
    var status: AuthorizationStatus
    var grants: AuthorizationStatus?
    private(set) var requests = 0

    init(_ status: AuthorizationStatus, grants: AuthorizationStatus? = nil) {
      self.status = status
      self.grants = grants
    }

    func request() {
      requests += 1
      if let grants { status = grants }
    }
  }

  func screens(_ fixture: ParentFixture, center: FakeCenter) -> ParentScreens {
    let authorization = ScreenTimeAuthorization(current: { center.status }, request: { center.request() })
    return ParentScreens(authorization: authorization, pins: fixture.pins, evaluator: fixture.evaluator, flag: fixture.flag, clock: { [clock = fixture.clock] in clock.now }, deviceZone: { .gmt })
  }

  @Test func asksForAGrownUpWhileScreenTimeIsNotGranted() async {
    let center = FakeCenter(.notDetermined, grants: .denied)
    let screens = screens(ParentFixture(), center: center)
    #expect(screens.overlay == nil)

    await screens.refresh()
    #expect(center.requests == 1)
    guard case .askGrownUp = screens.overlay else { Issue.record("expected ask a grown-up"); return }

    center.grants = .approved
    await screens.refresh()
    #expect(screens.overlay == nil)
  }

  @Test func aGrantMadeDuringThisRunIsFresh() async {
    let granted = ScreenTimeAuthorization(current: { .approved }, request: {})
    #expect(granted.fresh == nil)

    let center = FakeCenter(.notDetermined, grants: .approved)
    let authorization = ScreenTimeAuthorization(current: { center.status }, request: { center.request() })
    await authorization.request()
    #expect(authorization.fresh != nil)
  }

  @Test func setupFollowsAuthorizationWhenTheFlagIsAbsent() async throws {
    let fixture = ParentFixture(setup: .absent)
    let screens = screens(fixture, center: FakeCenter(.notDetermined, grants: .approved))

    await screens.refresh()

    guard case let .setup(setup) = screens.overlay else { Issue.record("expected setup"); return }
    #expect(setup.step == .choosePIN)
  }

  @Test func parentAccessOpensAtThePINPrompt() async throws {
    let fixture = try ParentFixture(snapshot: pendingInTokyo).withPIN()
    let screens = screens(fixture, center: FakeCenter(.approved))
    await screens.refresh()

    screens.openParentAccess()

    guard case let .parent(session) = screens.overlay else { Issue.record("expected the PIN prompt"); return }
    #expect(session.screen == .pin)
    session.enter("482913")
    session.unlockForToday()
    #expect(screens.overlay == nil)
  }

  @Test func theRepairingPromptProceedsOnlyAfterTheRightPIN() async throws {
    let fixture = try ParentFixture().withPIN()
    let screens = screens(fixture, center: FakeCenter(.approved))
    await screens.refresh()
    var proceeded = 0

    screens.askBeforeRepairing { proceeded += 1 }
    guard case let .repairing(request) = screens.overlay else { Issue.record("expected the PIN prompt"); return }

    request.enter("000000")
    #expect(proceeded == 0)
    #expect(request.prompt.status == .wrong)

    request.enter("482913")
    #expect(proceeded == 1)
    #expect(screens.overlay == nil)
  }

  @Test func cancellingTheRepairingPromptDropsTheLink() async throws {
    let fixture = try ParentFixture().withPIN()
    let screens = screens(fixture, center: FakeCenter(.approved))
    await screens.refresh()
    var proceeded = false

    screens.askBeforeRepairing { proceeded = true }
    guard case let .repairing(request) = screens.overlay else { Issue.record("expected the PIN prompt"); return }
    request.cancel()

    #expect(!proceeded)
    #expect(screens.overlay == nil)
  }
}
