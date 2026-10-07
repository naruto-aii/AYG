import Foundation

/// ウィジェットと Siri が、アプリが動いていなくても App Group に 1 件 1 ファイルで残す。
/// ファイルの作成日時は読まない。起動からの経過時間の API も使わない。
enum AnalyticsEventWriter {
  static let consentKey = "analyticsConsent"
  static let ownerKey = "analyticsOwnerUserId"
  static let installKey = "analyticsInstallId"
  static let queueFolder = "analytics_queue"
  static let maxFiles = 5000
  static let widgetSequenceKey = "analyticsSequence.widget"
  static let siriSequenceKey = "analyticsSequence.siri"

  /// 単体テストが App Group の代わりに使う。
  static var testingDirectory: URL?
  static var testingDefaults: UserDefaults?

  private static let lock = NSLock()

  static func recordWidgetTap(surface: String, slot: Int, result: String, kind: String = "meal") {
    let origin = surface == "home" ? "home_widget" : "lock_widget"
    write(
      name: "widget_tap",
      origin: origin,
      stream: "widget",
      sequenceKey: widgetSequenceKey,
      props: [
        "surface": surface,
        "slot": slot,
        "kind": kind,
        "result": result,
      ]
    )
  }

  static func recordSiri(
    name: String,
    props: [String: Any]
  ) {
    write(
      name: name,
      origin: "siri",
      stream: "siri",
      sequenceKey: siriSequenceKey,
      props: props
    )
  }

  static func pendingDirectory() -> URL? {
    if let testingDirectory {
      return testingDirectory
    }
    return FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: LockScreenMealStore.appGroupId)?
      .appendingPathComponent(queueFolder, isDirectory: true)
  }

  static func defaults() -> UserDefaults? {
    testingDefaults ?? LockScreenMealStore.defaults
  }

  static func fileCount() -> Int {
    guard let directory = pendingDirectory() else {
      return 0
    }
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.filter { $0.hasSuffix(".json") }.count
  }

  static func overflow(for stream: String) -> Int {
    defaults()?.integer(forKey: "analyticsDroppedOverflow.\(stream)") ?? 0
  }

  private static func write(
    name: String,
    origin: String,
    stream: String,
    sequenceKey: String,
    props: [String: Any]
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard defaults()?.bool(forKey: consentKey) == true else {
      return
    }
    guard let directory = pendingDirectory() else {
      return
    }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if fileCountUnlocked(directory) >= maxFiles {
      let key = "analyticsDroppedOverflow.\(stream)"
      let next = (defaults()?.integer(forKey: key) ?? 0) + 1
      defaults()?.set(next, forKey: key)
      return
    }
    let sequence = (defaults()?.integer(forKey: sequenceKey) ?? 0) + 1
    defaults()?.set(sequence, forKey: sequenceKey)
    let eventId = UUID().uuidString.lowercased()
    let owner = defaults()?.string(forKey: ownerKey) ?? LockScreenMealStore.ownerUserId()
    let install = defaults()?.string(forKey: installKey) ?? ""
    let payload: [String: Any] = [
      "event_id": eventId,
      "event_name": name,
      "occurred_at": isoNow(),
      "origin": origin,
      "install_id": install,
      "session_id": NSNull(),
      "stream": stream,
      "sequence_number": sequence,
      "app_version": "",
      "app_build": "",
      "schema_version": 1,
      "props": props,
      "owner_user_id": owner,
    ]
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload)
    else {
      return
    }
    let url = directory.appendingPathComponent("\(eventId).json")
    try? data.write(to: url, options: .atomic)
  }

  private static func fileCountUnlocked(_ directory: URL) -> Int {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.filter { $0.hasSuffix(".json") }.count
  }

  private static func isoNow() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }
}

enum WidgetAnalytics {
  /// `RegisterMealWidgetIntent.perform` と同じ記録。テストはこちらの関数を呼ぶ。
  static func recordPress(
    surface: String,
    slot: Int,
    outcome: (() throws -> String)? = nil
  ) rethrows -> String {
    do {
      let result = try outcome?() ?? LockScreenMealStore.register(surface: surface, slot: slot)
      AnalyticsEventWriter.recordWidgetTap(surface: surface, slot: slot, result: result)
      return result
    } catch {
      AnalyticsEventWriter.recordWidgetTap(surface: surface, slot: slot, result: "error")
      throw error
    }
  }
}

enum SiriAnalytics {
  private static var requestId = UUID().uuidString.lowercased()
  private static var prompts = 0
  private static var startedAt = Date()
  private static var finished = false

  static func started(intent: String, hasParameter: Bool) {
    requestId = UUID().uuidString.lowercased()
    prompts = 0
    startedAt = Date()
    finished = false
    AnalyticsEventWriter.recordSiri(
      name: "siri_request_started",
      props: [
        "intent": intent,
        "has_parameter": hasParameter,
      ]
    )
  }

  static func prompt(kind: String) {
    prompts += 1
    AnalyticsEventWriter.recordSiri(
      name: "siri_prompt",
      props: [
        "request_id": requestId,
        "prompt_kind": kind,
        "answered": false,
      ]
    )
  }

  static func finished(status: String, stopReason: String, itemsCount: Int = 0, continued: Bool = false) {
    if finished {
      return
    }
    finished = true
    let duration = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
    AnalyticsEventWriter.recordSiri(
      name: "siri_request_finished",
      props: [
        "request_id": requestId,
        "status": status,
        "stop_reason": stopReason,
        "prompts_count": prompts,
        "duration_ms": duration,
        "items_count": itemsCount,
        "continued_in_app": continued,
      ]
    )
  }
}
