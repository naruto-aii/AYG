import Foundation
import WidgetKit

/// ロック画面の食事ボタンとアプリが共有する App Group。
///
/// ボタンの App Intent は `openAppWhenRun = false`。押した瞬間にここへ
/// 今日の食事を1件追記し、アプリは開かない。Isar へは次回の起動・復帰で
/// 取り込む。`loggedAt` は押した時刻の壁時計。
///
/// 有料フラグ `lockScreenMealPaid` が true のときだけ追記する。
/// レシート検証と販売画面は無い。フラグの既定は false。
/// JSON の形は Dart の `LockScreenMealCodec`（version 3）と同じ。
/// ホームは5枠で、枠ごとに食事か運動。ロック画面は保存された3枠を kind のまま読む。
/// アプリは保存時にホームの1〜3枠目をロックへコピーする。古い `buttons` はロック画面として読む。
/// kind が無い保存値は、ホームの4枠目以降を運動、それ以外を食事として読む。
/// ボタンの中身はウィジェット専用で、食事テンプレートの id では引かない。
enum LockScreenMealStore {
  static let appGroupId = "group.com.narutoaii.ayg"
  static let paidKey = "lockScreenMealPaid"
  static let snapshotKey = "lockScreenMealSnapshot"
  static let pendingKey = "lockScreenMealPending"
  static let homeWidgetKind = "HomeMealWidget"
  static let lockWidgetKind = "LockScreenMealWidget"
  static let widgetKind = lockWidgetKind

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func isPaid() -> Bool {
    defaults?.bool(forKey: paidKey) ?? false
  }

  static func write(snapshotJSON: String, paid: Bool) {
    defaults?.set(paid, forKey: paidKey)
    defaults?.set(snapshotJSON, forKey: snapshotKey)
    reloadWidgets()
  }

  static func setPaid(_ paid: Bool) {
    defaults?.set(paid, forKey: paidKey)
    reloadWidgets()
  }

  static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: homeWidgetKind)
    WidgetCenter.shared.reloadTimelines(ofKind: lockWidgetKind)
  }

  static func homeButtons() -> [LockScreenMealButton] {
    loadButtons(key: "home", count: 5, fallbackLabels: ["朝ごはん", "昼ごはん", "夜ごはん", "ウォーキング", "ジョギング"])
  }

  static func lockButtons() -> [LockScreenMealButton] {
    let parsed = loadButtons(key: "lock", count: 3, fallbackLabels: ["朝", "昼", "夜"])
    if snapshotObject()?["lock"] != nil {
      return parsed
    }
    if snapshotObject()?["buttons"] != nil {
      return loadButtons(key: "buttons", count: 3, fallbackLabels: ["朝", "昼", "夜"])
    }
    return parsed
  }

  /// `target` と `overage` は後から足したキー。古いアプリが書いた JSON では nil になる。
  /// `day` は書いた日のローカル日付（yyyy-MM-dd）。今日でなければ今日の初期状態を返す。
  /// `day` が無い古いデータは、アプリが新しく書くまで今までどおりそのまま返す。
  static func figures(now: Date = Date()) -> StoredMealFigures {
    StoredMealFigures(json: snapshotObject()).forToday(MealWidgetDay.key(now))
  }

  static func snapshotObject() -> [String: Any]? {
    guard
      let raw = defaults?.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return json
  }

  static func loadButtons(key: String, count: Int, fallbackLabels: [String]) -> [LockScreenMealButton] {
    let rows = snapshotObject()?[key] as? [[String: Any]] ?? []
    var bySlot: [Int: LockScreenMealButton] = [:]
    for row in rows {
      if let button = LockScreenMealButton(json: row, maxSlot: count) {
        bySlot[button.slot] = button
      }
    }
    return (0..<count).map { slot in
      if let button = bySlot[slot] {
        return button
      }
      let label = slot < fallbackLabels.count ? fallbackLabels[slot] : ""
      return LockScreenMealButton(slot: slot, label: label, templateId: nil, templateName: nil, items: [])
    }
  }

  static func buttons() -> [LockScreenMealButton] {
    lockButtons()
  }

  /// 保存済みの枠の種類。meal か exercise。無い枠は meal。
  static func patternKind(surface: String, slot: Int) -> String {
    let buttons = surface == "home" ? homeButtons() : lockButtons()
    let raw = buttons.first(where: { $0.slot == slot })?.kind
    return raw == "exercise" ? "exercise" : "meal"
  }

  static func ownerUserId() -> String {
    guard
      let raw = defaults?.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let owner = json["ownerUserId"] as? String
    else {
      return ""
    }
    return owner.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func readPendingJSON() -> String {
    PendingRecordFiles.readJSON(
      folder: PendingRecordFiles.lockScreenFolder,
      idKey: "registrationId",
      legacyKey: pendingKey
    ) ?? defaults?.string(forKey: pendingKey) ?? "[]"
  }

  static func acknowledge(ids: [String]) {
    if PendingRecordFiles.acknowledge(
      folder: PendingRecordFiles.lockScreenFolder,
      ids: ids,
      idKey: "registrationId",
      legacyKey: pendingKey
    ) {
      return
    }
    let idSet = Set(ids)
    var pending = readPendingArray()
    pending.removeAll { record in
      guard let id = record["registrationId"] as? String else {
        return false
      }
      return idSet.contains(id)
    }
    writePendingArray(pending)
  }

  /// 有料かつパターンの中身があるときだけ、食事か運動を1件追記する。アプリは開かない。
  @discardableResult
  static func register(surface: String, slot: Int) -> String {
    guard isPaid() else {
      return "unpaid"
    }
    let owner = ownerUserId()
    let source = surface == "home" ? homeButtons() : lockButtons()
    guard !owner.isEmpty, let button = source.first(where: { $0.slot == slot }), button.canRegister else {
      return "unassigned"
    }
    let now = Date()
    // 同じボタンの連打（0.5秒差など）は1件にする。反応を待たずに押し直しても二重にならない。
    let tapKey = lastTapKey(surface: surface, slot: slot)
    let last = defaults?.object(forKey: tapKey) as? Double
    guard RegisterDebounce.accepts(lastTapAt: last, now: now.timeIntervalSince1970) else {
      return "duplicate"
    }
    defaults?.set(now.timeIntervalSince1970, forKey: tapKey)
    let record = button.makePendingRecord(ownerUserId: owner, loggedAt: now, surface: surface)
    let wrote = PendingRecordFiles.append(
      folder: PendingRecordFiles.lockScreenFolder,
      record: record,
      idKey: "registrationId",
      legacyKey: pendingKey
    )
    if !wrote {
      var pending = readPendingArray()
      pending.append(record)
      writePendingArray(pending)
    }
    let intake = button.kind == "exercise" ? 0 : foodKcal(button.items)
    let burn = button.kind == "exercise" ? exerciseKcal(button.exercises) : 0
    applyFigures(intakeDelta: intake, burnDelta: burn)
    return "registered"
  }

  static func lastTapKey(surface: String, slot: Int) -> String {
    "lockScreenMealLastTap.\(surface).\(slot)"
  }

  /// 押した直後に、残り・摂取・消費・超過の整数を動かす。Dart の `applyMealWidgetFigures` と同じ。
  /// 残りが 0 未満になった分は超過にする。目標（`target`）はそのまま残す。
  /// 保存日（`day`）が今日でなければ、昨日の合計に足さず今日の 0 から始める。
  static func applyFigures(intakeDelta: Double, burnDelta: Double, now: Date = Date()) {
    guard var json = snapshotObject() else {
      reloadWidgets()
      return
    }
    let next = StoredMealFigures(json: json).applying(
      intakeAdd: Int(intakeDelta.rounded()),
      burnAdd: Int(burnDelta.rounded()),
      today: MealWidgetDay.key(now)
    )
    next.write(into: &json)
    guard JSONSerialization.isValidJSONObject(json),
          let data = try? JSONSerialization.data(withJSONObject: json),
          let raw = String(data: data, encoding: .utf8)
    else {
      reloadWidgets()
      return
    }
    defaults?.set(raw, forKey: snapshotKey)
    defaults?.synchronize()
    reloadWidgets()
  }

  static func foodKcal(_ items: [[String: Any]]) -> Double {
    var total = 0.0
    for item in items {
      let base = number(item["baseAmount"])
      let consumed = number(item["consumedAmount"])
      let kcal = number(item["kcalPerBase"])
      if base > 0, consumed > 0 {
        total += kcal * consumed / base
      }
    }
    return total
  }

  static func exerciseKcal(_ items: [[String: Any]]) -> Double {
    var total = 0.0
    for item in items {
      total += number(item["netKcal"])
    }
    return total
  }

  /// JSON の NSNumber と、同じプロセスで入れた Double の両方を読む。
  static func number(_ value: Any?) -> Double {
    if let number = value as? Double {
      return number
    }
    if let number = value as? Int {
      return Double(number)
    }
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return 0
  }

  static func formatLoggedAt(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond],
      from: date
    )
    let millisecond = (parts.nanosecond ?? 0) / 1_000_000
    return String(
      format: "%04d-%02d-%02dT%02d:%02d:%02d.%03d",
      parts.year ?? 0,
      parts.month ?? 0,
      parts.day ?? 0,
      parts.hour ?? 0,
      parts.minute ?? 0,
      parts.second ?? 0,
      millisecond
    )
  }

  private static func readPendingArray() -> [[String: Any]] {
    guard
      let raw = defaults?.string(forKey: pendingKey),
      let data = raw.data(using: .utf8),
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }
    return rows
  }

  private static func writePendingArray(_ rows: [[String: Any]]) {
    guard JSONSerialization.isValidJSONObject(rows),
          let data = try? JSONSerialization.data(withJSONObject: rows),
          let raw = String(data: data, encoding: .utf8)
    else {
      return
    }
    defaults?.set(raw, forKey: pendingKey)
  }
}

/// ウィジェットの日付。アプリ（Dart の `mealWidgetDayKey`）と同じく端末のローカル日付。
enum MealWidgetDay {
  static func key(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  /// 次のローカル 0 時。ウィジェットはこの時刻に今日の初期状態へ切り替える。
  static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
    let start = calendar.startOfDay(for: date)
    return calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
  }
}

/// App Group に保存したウィジェットの数字。Dart の `MealWidgetFigures` と同じ。
struct StoredMealFigures: Equatable {
  var remaining: Int?
  var intake: Int?
  var burn: Int?
  var target: Int?
  var overage: Int?
  var day: String?

  init(
    remaining: Int? = nil,
    intake: Int? = nil,
    burn: Int? = nil,
    target: Int? = nil,
    overage: Int? = nil,
    day: String? = nil
  ) {
    self.remaining = remaining
    self.intake = intake
    self.burn = burn
    self.target = target
    self.overage = overage
    self.day = day
  }

  init(json: [String: Any]?) {
    self.init(
      remaining: (json?["remaining"] as? NSNumber)?.intValue,
      intake: (json?["intake"] as? NSNumber)?.intValue,
      burn: (json?["burn"] as? NSNumber)?.intValue,
      target: (json?["target"] as? NSNumber)?.intValue,
      overage: (json?["overage"] as? NSNumber)?.intValue,
      day: (json?["day"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    )
  }

  /// 保存日が今日と違えば今日の初期状態（摂取0・消費0・あと=目標・超過なし）。
  /// 日付が無い古いデータは、そのまま返す。Dart の `mealWidgetFiguresForToday` と同じ。
  func forToday(_ today: String) -> StoredMealFigures {
    guard let day, day != today else {
      return self
    }
    return StoredMealFigures(
      remaining: target.map { max($0, 0) },
      intake: 0,
      burn: 0,
      target: target,
      overage: nil,
      day: today
    )
  }

  /// 今日の数字に、押した分を足す。前の日の数字なら今日の 0 から始める。
  /// 前の日の記録の取り消し（どちらも 0 以下）は、今日の数字を動かさない。
  func applying(intakeAdd: Int, burnAdd: Int, today: String) -> StoredMealFigures {
    let base = forToday(today)
    let rolledOver = base.day != day
    if rolledOver && intakeAdd <= 0 && burnAdd <= 0 {
      return base
    }
    var next = base
    next.intake = (base.intake ?? 0) + intakeAdd
    next.burn = (base.burn ?? 0) + burnAdd
    if let remaining = base.remaining {
      let overage = base.overage ?? 0
      let balance = overage > 0 ? -overage : remaining
      let moved = balance - intakeAdd + burnAdd
      next.remaining = moved < 0 ? 0 : moved
      next.overage = moved < 0 ? -moved : nil
    }
    return next
  }

  /// 保存用の JSON に書き戻す。`day` が無い古いデータには足さない。
  func write(into json: inout [String: Any]) {
    json["intake"] = intake ?? 0
    json["burn"] = burn ?? 0
    if let remaining {
      json["remaining"] = remaining
      json["overage"] = overage.map { $0 as Any } ?? NSNull()
    } else if day != nil {
      // 日付が変わって目標も無いときは、昨日の残りを残さない
      json["remaining"] = NSNull()
      json["overage"] = NSNull()
    }
    if let day {
      json["day"] = day
    }
  }
}

struct LockScreenMealButton: Identifiable {
  let slot: Int
  let label: String
  let templateId: String?
  let templateName: String?
  let items: [[String: Any]]
  let kind: String
  let exercises: [[String: Any]]

  var id: Int { slot }

  var displayLabel: String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "\(slot + 1)"
    }
    return trimmed
  }

  var canRegister: Bool {
    if kind == "exercise" {
      return exercises.contains { LockScreenMealButton.isUsableExercise($0) }
    }
    return items.contains { LockScreenMealButton.isUsableItem($0) }
  }

  static func empty(slot: Int) -> LockScreenMealButton {
    LockScreenMealButton(slot: slot, label: "", templateId: nil, templateName: nil, items: [])
  }

  static var homePlaceholders: [LockScreenMealButton] {
    labeled(["朝ごはん", "昼ごはん", "夜ごはん", "ウォーキング", "ジョギング"])
  }

  static var lockPlaceholders: [LockScreenMealButton] {
    labeled(["朝", "昼", "夜"])
  }

  private static func labeled(_ labels: [String]) -> [LockScreenMealButton] {
    labels.enumerated().map { slot, label in
      LockScreenMealButton(slot: slot, label: label, templateId: nil, templateName: nil, items: [])
    }
  }

  init?(json: [String: Any], maxSlot: Int) {
    guard let slotNumber = json["slot"] as? NSNumber else {
      return nil
    }
    let slot = slotNumber.intValue
    guard slot >= 0, slot < maxSlot else {
      return nil
    }
    let label = json["label"] as? String ?? ""
    let templateId = (json["templateId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let templateName = json["templateName"] as? String
    let itemRows = json["items"] as? [[String: Any]] ?? []
    let usable = itemRows.filter { LockScreenMealButton.isUsableItem($0) }
    let exerciseRows = json["exercises"] as? [[String: Any]] ?? []
    let usableExercises = exerciseRows.filter { LockScreenMealButton.isUsableExercise($0) }
    let rawKind = json["kind"] as? String
    let kind: String
    if rawKind == "exercise" || rawKind == "meal" {
      kind = rawKind!
    } else if maxSlot > 3 && slot >= 3 {
      kind = "exercise"
    } else {
      kind = "meal"
    }
    self.slot = slot
    self.label = label
    self.templateId = (templateId?.isEmpty == false) ? templateId : nil
    self.templateName = templateName
    self.items = kind == "exercise" ? [] : usable
    self.kind = kind
    self.exercises = kind == "exercise" ? usableExercises : []
  }

  init(
    slot: Int,
    label: String,
    templateId: String?,
    templateName: String?,
    items: [[String: Any]],
    kind: String = "meal",
    exercises: [[String: Any]] = []
  ) {
    self.slot = slot
    self.label = label
    self.templateId = templateId
    self.templateName = templateName
    self.items = items
    self.kind = kind
    self.exercises = exercises
  }

  func makePendingRecord(ownerUserId: String, loggedAt: Date, surface: String) -> [String: Any] {
    if kind == "exercise" {
      let copied: [[String: Any]] = exercises.map { item in
        var copy = item
        copy["id"] = UUID().uuidString
        return copy
      }
      return [
        "registrationId": UUID().uuidString,
        "ownerUserId": ownerUserId,
        "slot": slot,
        "kind": "exercise",
        "templateId": templateId ?? "",
        "mealGroupName": displayLabel,
        "loggedAt": LockScreenMealStore.formatLoggedAt(loggedAt),
        "surface": surface,
        "exercises": copied,
      ]
    }
    let mealGroupId = UUID().uuidString
    let mealName = templateName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let mealGroupName = (mealName?.isEmpty == false) ? mealName! : displayLabel
    let copiedItems: [[String: Any]] = items.map { item in
      var copy = item
      copy["id"] = UUID().uuidString
      return copy
    }
    return [
      "registrationId": UUID().uuidString,
      "ownerUserId": ownerUserId,
      "slot": slot,
      "kind": "meal",
      "templateId": templateId ?? "",
      "mealGroupId": mealGroupId,
      "mealGroupName": mealGroupName,
      "loggedAt": LockScreenMealStore.formatLoggedAt(loggedAt),
      "surface": surface,
      "items": copiedItems,
    ]
  }

  private static func isUsableItem(_ item: [String: Any]) -> Bool {
    guard let name = item["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    guard let base = (item["baseAmount"] as? NSNumber)?.doubleValue, base > 0 else {
      return false
    }
    guard let consumed = (item["consumedAmount"] as? NSNumber)?.doubleValue, consumed > 0 else {
      return false
    }
    return true
  }

  private static func isUsableExercise(_ item: [String: Any]) -> Bool {
    guard let activityId = item["activityId"] as? String,
          !activityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return false
    }
    if let distance = (item["distanceKm"] as? NSNumber)?.doubleValue, distance > 0 {
      return true
    }
    if let minutes = (item["durationMin"] as? NSNumber)?.intValue, minutes > 0 {
      return true
    }
    return false
  }
}

/// ウィジェットの同じボタンを続けて押したときの間引き。端末の時計だけで決める。
enum RegisterDebounce {
  /// これより短い間隔の2回目は記録しない（秒）。
  static let window: Double = 3

  static func accepts(lastTapAt: Double?, now: Double) -> Bool {
    guard let last = lastTapAt else {
      return true
    }
    // 時計が戻ったときは受け付ける。
    if now < last {
      return true
    }
    return now - last >= window
  }
}
