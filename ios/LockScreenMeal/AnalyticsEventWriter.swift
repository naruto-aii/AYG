import Darwin
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
        "kind": widgetPatternKind(kind),
        "result": result,
      ]
    )
  }

  /// 枠の種類は meal か exercise だけ。それ以外は meal にする。
  static func widgetPatternKind(_ raw: String?) -> String {
    raw == "exercise" ? "exercise" : "meal"
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
  /// `kind` を渡したときはその枠の種類を書く。省略したときは保存済みの枠を読む。
  static func recordPress(
    surface: String,
    slot: Int,
    kind: String? = nil,
    outcome: (() throws -> String)? = nil
  ) rethrows -> String {
    let pattern = AnalyticsEventWriter.widgetPatternKind(
      kind ?? LockScreenMealStore.patternKind(surface: surface, slot: slot)
    )
    do {
      let result = try outcome?() ?? LockScreenMealStore.register(surface: surface, slot: slot)
      AnalyticsEventWriter.recordWidgetTap(
        surface: surface,
        slot: slot,
        result: result,
        kind: pattern
      )
      return result
    } catch {
      AnalyticsEventWriter.recordWidgetTap(
        surface: surface,
        slot: slot,
        result: "error",
        kind: pattern
      )
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

/// ウィジェットと Siri の未取り込み記録。1件1ファイルなので、取り込み中の追記は消えない。
enum PendingRecordFiles {
  static let lockScreenFolder = "lock_screen_meal_pending"
  static let siriFolder = "siri_voice_pending"
  static let legacyFileName = "pending.json"

  /// 単体テストが App Group の代わりに使う親ディレクトリ。
  static var testingRoot: URL?

  static func append(
    folder: String,
    record: [String: Any],
    idKey: String,
    legacyKey: String
  ) -> Bool {
    guard let id = stringId(record[idKey]) else {
      return false
    }
    return withDirectory(folder) { directory, defaults in
      migrateUnlocked(directory: directory, idKey: idKey, legacyKey: legacyKey, defaults: defaults)
      writeUnlocked(directory: directory, id: id, record: record)
    }
  }

  static func readJSON(folder: String, idKey: String, legacyKey: String) -> String? {
    var encoded: String?
    let ready = withDirectory(folder) { directory, defaults in
      migrateUnlocked(directory: directory, idKey: idKey, legacyKey: legacyKey, defaults: defaults)
      let rows = readUnlocked(directory: directory)
      if JSONSerialization.isValidJSONObject(rows),
         let data = try? JSONSerialization.data(withJSONObject: rows),
         let raw = String(data: data, encoding: .utf8) {
        encoded = raw
      } else {
        encoded = "[]"
      }
    }
    return ready ? encoded : nil
  }

  static func acknowledge(
    folder: String,
    ids: [String],
    idKey: String,
    legacyKey: String
  ) -> Bool {
    withDirectory(folder) { directory, defaults in
      migrateUnlocked(directory: directory, idKey: idKey, legacyKey: legacyKey, defaults: defaults)
      for id in ids {
        let url = fileURL(directory: directory, id: id)
        if FileManager.default.fileExists(atPath: url.path) {
          try? FileManager.default.removeItem(at: url)
        }
      }
    }
  }

  private static func withDirectory(
    _ folder: String,
    _ body: (URL, UserDefaults?) -> Void
  ) -> Bool {
    guard let directory = ensureDirectory(folder) else {
      return false
    }
    let lockURL = directory.appendingPathComponent(".lock")
    FileManager.default.createFile(atPath: lockURL.path, contents: nil)
    guard let handle = FileHandle(forUpdatingAtPath: lockURL.path) else {
      body(directory, sharedDefaults())
      return true
    }
    flock(handle.fileDescriptor, LOCK_EX)
    defer {
      flock(handle.fileDescriptor, LOCK_UN)
      try? handle.close()
    }
    body(directory, sharedDefaults())
    return true
  }

  private static func ensureDirectory(_ folder: String) -> URL? {
    guard let root = testingRoot ?? FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: LockScreenMealStore.appGroupId
    ) else {
      return nil
    }
    let directory = root.appendingPathComponent(folder, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    return directory
  }

  private static func sharedDefaults() -> UserDefaults? {
    AnalyticsEventWriter.testingDefaults ?? LockScreenMealStore.defaults
  }

  private static func migrateUnlocked(
    directory: URL,
    idKey: String,
    legacyKey: String,
    defaults: UserDefaults?
  ) {
    if let raw = defaults?.string(forKey: legacyKey) {
      writeLegacyArray(raw, directory: directory, idKey: idKey)
      defaults?.removeObject(forKey: legacyKey)
    }
    let legacyURL = directory.appendingPathComponent(legacyFileName)
    if let raw = try? String(contentsOf: legacyURL, encoding: .utf8) {
      writeLegacyArray(raw, directory: directory, idKey: idKey)
      try? FileManager.default.removeItem(at: legacyURL)
    }
  }

  private static func writeLegacyArray(_ raw: String, directory: URL, idKey: String) {
    guard
      let data = raw.data(using: .utf8),
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return
    }
    for record in rows {
      guard let id = stringId(record[idKey]) else {
        continue
      }
      writeUnlocked(directory: directory, id: id, record: record)
    }
  }

  private static func writeUnlocked(directory: URL, id: String, record: [String: Any]) {
    let url = fileURL(directory: directory, id: id)
    if FileManager.default.fileExists(atPath: url.path) {
      return
    }
    guard JSONSerialization.isValidJSONObject(record),
          let data = try? JSONSerialization.data(withJSONObject: record)
    else {
      return
    }
    try? data.write(to: url, options: .atomic)
  }

  private static func readUnlocked(directory: URL) -> [[String: Any]] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    var rows: [[String: Any]] = []
    for name in names.sorted() {
      if !name.hasSuffix(".json") || name == legacyFileName || name.hasPrefix(".") {
        continue
      }
      let url = directory.appendingPathComponent(name)
      guard
        let data = try? Data(contentsOf: url),
        let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else {
        continue
      }
      rows.append(row)
    }
    return rows
  }

  private static func fileURL(directory: URL, id: String) -> URL {
    let safe = id.replacingOccurrences(of: "/", with: "_")
    return directory.appendingPathComponent("\(safe).json")
  }

  private static func stringId(_ value: Any?) -> String? {
    guard let id = value as? String else {
      return nil
    }
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
