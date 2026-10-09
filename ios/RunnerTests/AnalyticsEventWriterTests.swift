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

final class RegisterDebounceTests: XCTestCase {
  func testADoubleTapWithinThreeSecondsIsDropped() {
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: nil, now: 100))
    XCTAssertFalse(RegisterDebounce.accepts(lastTapAt: 100, now: 100.45))
    XCTAssertFalse(RegisterDebounce.accepts(lastTapAt: 100, now: 102.9))
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: 100, now: 103))
    XCTAssertTrue(RegisterDebounce.accepts(lastTapAt: 100, now: 50))
  }
}
