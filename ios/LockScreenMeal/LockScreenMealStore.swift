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
/// JSON の形は Dart の `LockScreenMealCodec`（version 1）と同じ。
enum LockScreenMealStore {
  static let appGroupId = "group.com.narutoaii.ayg"
  static let paidKey = "lockScreenMealPaid"
  static let snapshotKey = "lockScreenMealSnapshot"
  static let pendingKey = "lockScreenMealPending"
  static let widgetKind = "LockScreenMealWidget"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func isPaid() -> Bool {
    defaults?.bool(forKey: paidKey) ?? false
  }

  static func write(snapshotJSON: String, paid: Bool) {
    defaults?.set(paid, forKey: paidKey)
    defaults?.set(snapshotJSON, forKey: snapshotKey)
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }

  static func setPaid(_ paid: Bool) {
    defaults?.set(paid, forKey: paidKey)
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }

  static func buttons() -> [LockScreenMealButton] {
    guard
      let raw = defaults?.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let rows = json["buttons"] as? [[String: Any]]
    else {
      return LockScreenMealButton.placeholders
    }
    var bySlot: [Int: LockScreenMealButton] = [:]
    for row in rows {
      if let button = LockScreenMealButton(json: row) {
        bySlot[button.slot] = button
      }
    }
    return (0..<3).map { slot in
      bySlot[slot] ?? LockScreenMealButton.empty(slot: slot)
    }
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

  /// 有料かつテンプレート割り当て済みのときだけ、食事を1件追記する。
  @discardableResult
  static func register(slot: Int) -> String {
    guard isPaid() else {
      return "unpaid"
    }
    let owner = ownerUserId()
    guard !owner.isEmpty, let button = buttons().first(where: { $0.slot == slot }), button.canRegister else {
      return "unassigned"
    }
    var pending = readPendingArray()
    pending.append(button.makePendingRecord(ownerUserId: owner, loggedAt: Date()))
    writePendingArray(pending)
    return "registered"
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

  var id: Int { slot }

  var displayLabel: String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "\(slot + 1)"
    }
    return trimmed
  }

  var canRegister: Bool {
    guard let templateId, !templateId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    return !items.isEmpty
  }

  static func empty(slot: Int) -> LockScreenMealButton {
    LockScreenMealButton(slot: slot, label: "", templateId: nil, templateName: nil, items: [])
  }

  static var placeholders: [LockScreenMealButton] {
    (0..<3).map { empty(slot: $0) }
  }

  init?(json: [String: Any]) {
    guard let slotNumber = json["slot"] as? NSNumber else {
      return nil
    }
    let slot = slotNumber.intValue
    guard slot >= 0, slot < 3 else {
      return nil
    }
    let label = json["label"] as? String ?? ""
    let templateId = (json["templateId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let templateName = json["templateName"] as? String
    let itemRows = json["items"] as? [[String: Any]] ?? []
    let usable = itemRows.filter { LockScreenMealButton.isUsableItem($0) }
    self.slot = slot
    self.label = label
    self.templateId = (templateId?.isEmpty == false) ? templateId : nil
    self.templateName = templateName
    self.items = usable
  }

  init(slot: Int, label: String, templateId: String?, templateName: String?, items: [[String: Any]]) {
    self.slot = slot
    self.label = label
    self.templateId = templateId
    self.templateName = templateName
    self.items = items
  }

  func makePendingRecord(ownerUserId: String, loggedAt: Date) -> [String: Any] {
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
      "templateId": templateId ?? "",
      "mealGroupId": mealGroupId,
      "mealGroupName": mealGroupName,
      "loggedAt": LockScreenMealStore.formatLoggedAt(loggedAt),
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
}
