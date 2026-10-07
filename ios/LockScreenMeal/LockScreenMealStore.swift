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
  static func figures() -> (remaining: Int?, intake: Int?, burn: Int?, target: Int?, overage: Int?) {
    let json = snapshotObject()
    return (
      (json?["remaining"] as? NSNumber)?.intValue,
      (json?["intake"] as? NSNumber)?.intValue,
      (json?["burn"] as? NSNumber)?.intValue,
      (json?["target"] as? NSNumber)?.intValue,
      (json?["overage"] as? NSNumber)?.intValue
    )
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
    defaults?.string(forKey: pendingKey) ?? "[]"
  }

  static func acknowledge(ids: [String]) {
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
    var pending = readPendingArray()
    pending.append(
      button.makePendingRecord(ownerUserId: owner, loggedAt: Date(), surface: surface)
    )
    writePendingArray(pending)
    let intake = button.kind == "exercise" ? 0 : foodKcal(button.items)
    let burn = button.kind == "exercise" ? exerciseKcal(button.exercises) : 0
    applyFigures(intakeDelta: intake, burnDelta: burn)
    return "registered"
  }

  /// 押した直後に、残り・摂取・消費・超過の整数を動かす。Dart の `applyMealWidgetFigures` と同じ。
  /// 残りが 0 未満になった分は超過にする。目標（`target`）はそのまま残す。
  static func applyFigures(intakeDelta: Double, burnDelta: Double) {
    guard var json = snapshotObject() else {
      reloadWidgets()
      return
    }
    let intakeAdd = Int(intakeDelta.rounded())
    let burnAdd = Int(burnDelta.rounded())
    let intake = (json["intake"] as? NSNumber)?.intValue ?? 0
    let burn = (json["burn"] as? NSNumber)?.intValue ?? 0
    json["intake"] = intake + intakeAdd
    json["burn"] = burn + burnAdd
    if let remaining = (json["remaining"] as? NSNumber)?.intValue {
      let overage = (json["overage"] as? NSNumber)?.intValue ?? 0
      let balance = overage > 0 ? -overage : remaining
      let next = balance - intakeAdd + burnAdd
      json["remaining"] = next < 0 ? 0 : next
      json["overage"] = next < 0 ? -next : NSNull()
    }
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
