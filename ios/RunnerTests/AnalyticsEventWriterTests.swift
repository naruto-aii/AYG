import XCTest

final class AnalyticsEventWriterTests: XCTestCase {
  private var directory: URL!
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defaults = UserDefaults(suiteName: "analytics-writer-tests")!
    defaults.removePersistentDomain(forName: "analytics-writer-tests")
    AnalyticsEventWriter.testingDirectory = directory
    AnalyticsEventWriter.testingDefaults = defaults
    defaults.set(true, forKey: AnalyticsEventWriter.consentKey)
  }

  override func tearDown() {
    AnalyticsEventWriter.testingDirectory = nil
    AnalyticsEventWriter.testingDefaults = nil
    try? FileManager.default.removeItem(at: directory)
    super.tearDown()
  }

  func testWidgetPressWritesWithoutTheApp() throws {
    let unpaid = try WidgetAnalytics.recordPress(surface: "lock", slot: 0) {
      "unpaid"
    }
    let unassigned = try WidgetAnalytics.recordPress(surface: "home", slot: 1) {
      "unassigned"
    }
    XCTAssertEqual(unpaid, "unpaid")
    XCTAssertEqual(unassigned, "unassigned")
    XCTAssertThrowsError(
      try WidgetAnalytics.recordPress(surface: "lock", slot: 2) {
        throw NSError(domain: "test", code: 1)
      }
    )
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    XCTAssertEqual(files.count, 3)
    let results = try files.map { url -> String in
      let data = try Data(contentsOf: url)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let props = json?["props"] as? [String: Any]
      return props?["result"] as? String ?? ""
    }
    XCTAssertTrue(results.contains("unpaid"))
    XCTAssertTrue(results.contains("unassigned"))
    XCTAssertTrue(results.contains("error"))
  }

  func testWidgetPressKeepsSlotAndKind() throws {
    _ = try WidgetAnalytics.recordPress(surface: "home", slot: 4, kind: "exercise") {
      "registered"
    }
    XCTAssertThrowsError(
      try WidgetAnalytics.recordPress(surface: "home", slot: 3, kind: "exercise") {
        throw NSError(domain: "test", code: 1)
      }
    )
    _ = try WidgetAnalytics.recordPress(surface: "lock", slot: 0, kind: "not-a-kind") {
      "unpaid"
    }
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    XCTAssertEqual(files.count, 3)
    let rows = try files.map { url -> (Int, String, String) in
      let data = try Data(contentsOf: url)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let props = json?["props"] as? [String: Any]
      let slot = (props?["slot"] as? NSNumber)?.intValue ?? -1
      let kind = props?["kind"] as? String ?? ""
      let result = props?["result"] as? String ?? ""
      return (slot, kind, result)
    }
    XCTAssertTrue(rows.contains { $0 == (4, "exercise", "registered") })
    XCTAssertTrue(rows.contains { $0 == (3, "exercise", "error") })
    XCTAssertTrue(rows.contains { $0 == (0, "meal", "unpaid") })
  }

  func testConsentFalseWritesNothing() throws {
    defaults.set(false, forKey: AnalyticsEventWriter.consentKey)
    _ = try WidgetAnalytics.recordPress(surface: "lock", slot: 0) { "unpaid" }
    SiriAnalytics.started(intent: "log_food", hasParameter: false)
    SiriAnalytics.finished(status: "cancelled", stopReason: "test")
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    XCTAssertTrue(files.isEmpty)
  }

  func testSiriExitsWriteFiles() {
    defaults.set(true, forKey: AnalyticsEventWriter.consentKey)
    SiriAnalytics.started(intent: "log_food", hasParameter: true)
    SiriAnalytics.prompt(kind: "value")
    SiriAnalytics.finished(status: "cancelled", stopReason: "user")
    SiriAnalytics.started(intent: "log_exercise", hasParameter: false)
    SiriAnalytics.finished(status: "blocked", stopReason: "unpaid")
    SiriAnalytics.started(intent: "log_utterance", hasParameter: false)
    SiriAnalytics.finished(status: "not_found", stopReason: "rescue")
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    XCTAssertGreaterThanOrEqual(names.count, 6)
  }

  func testOverflowCountsInsteadOfWriting() throws {
    defaults.set(true, forKey: AnalyticsEventWriter.consentKey)
    for index in 0..<AnalyticsEventWriter.maxFiles {
      AnalyticsEventWriter.recordWidgetTap(surface: "lock", slot: index % 3, result: "registered")
    }
    AnalyticsEventWriter.recordWidgetTap(surface: "lock", slot: 0, result: "registered")
    XCTAssertEqual(AnalyticsEventWriter.fileCount(), AnalyticsEventWriter.maxFiles)
    XCTAssertEqual(AnalyticsEventWriter.overflow(for: "widget"), 1)
  }

  func testConcurrentWritesStayIntact() {
    defaults.set(true, forKey: AnalyticsEventWriter.consentKey)
    let group = DispatchGroup()
    for index in 0..<40 {
      group.enter()
      DispatchQueue.global().async {
        AnalyticsEventWriter.recordWidgetTap(surface: index.isMultiple(of: 2) ? "home" : "lock", slot: index, result: "registered")
        group.leave()
      }
    }
    group.wait()
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    XCTAssertEqual(names.count, 40)
    for name in names {
      let url = directory.appendingPathComponent(name)
      let data = try? Data(contentsOf: url)
      XCTAssertNotNil(data)
      XCTAssertNotNil(try? JSONSerialization.jsonObject(with: data ?? Data()))
    }
  }
}

final class ShortcutAccessRulesTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)
  private var future: Date { now.addingTimeInterval(3600) }
  private var past: Date { now.addingTimeInterval(-3600) }

  private func decide(
    _ source: String,
    _ expiresAt: Date? = nil,
    _ store: PlusStoreSnapshot = .failed
  ) -> ShortcutAccess {
    ShortcutAccessRules.decide(
      source: source,
      expiresAt: expiresAt,
      store: store,
      now: now
    )
  }

  func testFreePaidExpiredRefundedAndComplimentary() {
    XCTAssertEqual(decide("none"), .unpaid)
    XCTAssertEqual(decide("none", nil, .none), .unpaid)
    XCTAssertEqual(decide("store", future), .paid)
    XCTAssertEqual(decide("store", past), .expired)
    XCTAssertEqual(decide("store", now), .expired)
    XCTAssertEqual(decide("store", future, .revoked), .refunded)
    XCTAssertEqual(decide("revoked", future), .refunded)
    XCTAssertEqual(decide("complimentary", nil, .revoked), .paid)
    XCTAssertEqual(decide("preview", nil, .none), .paid)
    XCTAssertEqual(decide("none", nil, .active(expiresAt: future)), .paid)
    XCTAssertEqual(decide("none", nil, .active(expiresAt: nil)), .paid)
    XCTAssertEqual(decide("revoked", nil, .active(expiresAt: future)), .paid)
    XCTAssertEqual(decide("none", nil, .active(expiresAt: past)), .expired)
    XCTAssertEqual(decide("store", future, .active(expiresAt: past)), .expired)
  }

  func testReduceKeepsALivePurchaseAheadOfARefund() {
    let monthly = "calonavi_plus_monthly"
    XCTAssertEqual(PlusStoreProbe.reduce([], now: now), .none)
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [PlusStoreTransaction(productId: monthly, expiresAt: future, revoked: false)],
        now: now
      ),
      .active(expiresAt: future)
    )
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [PlusStoreTransaction(productId: monthly, expiresAt: future, revoked: true)],
        now: now
      ),
      .revoked
    )
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [
          PlusStoreTransaction(productId: monthly, expiresAt: future, revoked: true),
          PlusStoreTransaction(productId: "calonavi_plus_yearly", expiresAt: future, revoked: false),
        ],
        now: now
      ),
      .active(expiresAt: future)
    )
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [PlusStoreTransaction(productId: monthly, expiresAt: past, revoked: false)],
        now: now
      ),
      .none
    )
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [PlusStoreTransaction(productId: monthly, expiresAt: nil, revoked: false)],
        now: now
      ),
      .active(expiresAt: nil)
    )
    XCTAssertEqual(
      PlusStoreProbe.reduce(
        [PlusStoreTransaction(productId: "other", expiresAt: future, revoked: false)],
        now: now
      ),
      .none
    )
  }

  func testSavedGrantSurvivesASnapshotWrite() {
    let suite = "shortcut-access-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    LockScreenMealStore.testingDefaults = defaults
    defer {
      LockScreenMealStore.testingDefaults = nil
      defaults.removePersistentDomain(forName: suite)
    }

    defaults.set(true, forKey: LockScreenMealStore.paidKey)
    XCTAssertEqual(LockScreenMealStore.readGrant().source, "none")
    XCTAssertEqual(LockScreenMealStore.access(store: .failed, now: now), .unpaid)
    XCTAssertEqual(LockScreenMealStore.access(store: .revoked, now: now), .refunded)
    XCTAssertEqual(
      LockScreenMealStore.access(store: .active(expiresAt: future), now: now),
      .paid
    )
    defaults.set("preview", forKey: LockScreenMealStore.sourceKey)
    XCTAssertEqual(LockScreenMealStore.readGrant().source, "preview")
    XCTAssertEqual(LockScreenMealStore.access(store: .none, now: now), .paid)
    defaults.removeObject(forKey: LockScreenMealStore.sourceKey)

    LockScreenMealStore.setGrant(source: "complimentary", expiresAtISO: nil)
    LockScreenMealStore.write(snapshotJSON: "{}", paid: false)
    XCTAssertEqual(LockScreenMealStore.readGrant().source, "complimentary")
    XCTAssertEqual(LockScreenMealStore.access(store: .revoked, now: now), .paid)

    LockScreenMealStore.setGrant(source: "store", expiresAtISO: "2099-01-01T00:00:00Z")
    XCTAssertEqual(LockScreenMealStore.access(store: .failed, now: now), .paid)
    LockScreenMealStore.setGrant(source: "store", expiresAtISO: "2000-01-01T00:00:00Z")
    XCTAssertEqual(LockScreenMealStore.access(store: .failed, now: now), .expired)
    LockScreenMealStore.setGrant(source: "revoked", expiresAtISO: "2099-01-01T00:00:00Z")
    XCTAssertEqual(LockScreenMealStore.access(store: .failed, now: now), .refunded)
    LockScreenMealStore.setGrant(source: "none", expiresAtISO: nil)
    XCTAssertEqual(LockScreenMealStore.access(store: .failed, now: now), .unpaid)
  }

  func testWidgetPreviewRoundsEachItemBeforeSumming() {
    let items: [[String: Any]] = [
      ["baseAmount": 1, "consumedAmount": 1, "kcalPerBase": 10.4],
      ["baseAmount": 1, "consumedAmount": 1, "kcalPerBase": 10.4],
    ]
    XCTAssertEqual(LockScreenMealStore.foodKcal(items), 20)
    XCTAssertEqual(
      LockScreenMealStore.exerciseKcal([
        ["netKcal": 10.6],
        ["netKcal": 10.6],
      ]),
      22
    )
  }

  func testPaidTimelineRefreshesInFifteenMinutesAndKeepsExpiryDates() {
    let midnight = now.addingTimeInterval(TimeInterval(8 * 3600))
    let expiry = now.addingTimeInterval(3600)
    let storeExpiry = now.addingTimeInterval(7200)
    let dates = WidgetTimelinePlan.dates(
      now: now,
      midnight: midnight,
      grantExpiresAt: expiry,
      storeExpiresAt: storeExpiry
    )
    XCTAssertEqual(dates[0], now)
    XCTAssertTrue(dates.contains(midnight))
    XCTAssertTrue(dates.contains(expiry))
    XCTAssertTrue(dates.contains(storeExpiry))
    XCTAssertEqual(WidgetTimelinePlan.paidRefreshInterval, TimeInterval(15 * 60))
    XCTAssertEqual(
      WidgetTimelinePlan.refreshAt(access: .paid, now: now),
      now.addingTimeInterval(TimeInterval(15 * 60))
    )
    XCTAssertNil(WidgetTimelinePlan.refreshAt(access: .unpaid, now: now))
    XCTAssertNil(WidgetTimelinePlan.refreshAt(access: .expired, now: now))
    XCTAssertNil(WidgetTimelinePlan.refreshAt(access: .refunded, now: now))
  }
}

final class RegisterDebounceTests: XCTestCase {
  func testADoubleTapWithinThreeSecondsIsDropped() {
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: nil, now: 100))
    XCTAssertFalse(RegisterDebounce.accepts(lastTapAt: 100, now: 100.45))
    XCTAssertFalse(RegisterDebounce.accepts(lastTapAt: 100, now: 102.9))
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: 100, now: 103))
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: 100, now: 50))
  }
}
