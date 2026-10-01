import AppIntents
import Foundation

/// 食事と運動を、復唱して「はい」のときだけ1件登録する。
///
/// 「いいえ」や無言では `requestConfirmation` が途中で終わるので、その前には書かない。
/// 食事テンプレートの一発登録は作らない。未課金は登録しない。
/// 判定の順は Dart の `planSiriFood` / `planSiriExercise` と同じ。
enum SiriVoiceStore {
  static let catalogKey = "siriVoiceCatalog"
  static let pendingKey = "siriVoicePending"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: LockScreenMealStore.appGroupId)
  }

  static func writeCatalog(_ json: String) {
    defaults?.set(json, forKey: catalogKey)
  }

  static func readPendingJSON() -> String {
    defaults?.string(forKey: pendingKey) ?? "[]"
  }

  static func acknowledge(ids: [String]) {
    let idSet = Set(ids)
    var pending = readPendingArray()
    pending.removeAll { record in
      guard let id = record["id"] as? String else { return false }
      return idSet.contains(id)
    }
    writePendingArray(pending)
  }

  static func commit(_ record: [String: Any]) {
    var pending = readPendingArray()
    pending.append(record)
    writePendingArray(pending)
  }

  struct Plan {
    var spoken: String
    var asksConfirmation: Bool
    var record: [String: Any]?
  }

  static func planFood(name: String, quantity: String) async -> Plan {
    if let blocked = blocked() {
      return blocked
    }
    let split = splitUtterance(name: name, quantity: quantity)
    guard let parsed = parseQuantity(split.quantity) else {
      if cleanName(split.name).isEmpty {
        return stop("食品名が分かりません")
      }
      return stop("量が分かりません")
    }
    let spokenName = cleanName(split.name)
    if spokenName.isEmpty {
      return stop("食品名が分かりません")
    }
    let key = normalize(spokenName)
    var matches = foods().filter { food in
      let keys = food["keys"] as? [String] ?? []
      return keys.contains(key)
    }
    if matches.isEmpty {
      matches = await officialFoods(query: spokenName, key: key)
    }
    let saved = matches.filter { $0["source"] as? String == "saved_food" }
    let pool = saved.isEmpty
      ? matches.filter { $0["source"] as? String == "mext_sfct" }
      : saved
    if pool.isEmpty {
      return stop("\(spokenName)は見つかりません")
    }
    let ids = Set(pool.compactMap { $0["id"] as? String })
    if ids.count != 1 {
      return stop("\(spokenName)はひとつに決まりません")
    }
    let food = pool[0]
    let speakName = food["speakName"] as? String ?? spokenName
    let unit = food["unit"] as? String ?? ""
    guard foodUnitFits(unit, spoken: parsed.unit) else {
      return stop("\(speakName)は\(foodUnitLabel(unit))で指定してください")
    }
    return Plan(
      spoken: "\(speakName)を\(formatQuantity(parsed))ですね",
      asksConfirmation: true,
      record: foodRecord(food, amount: parsed.amount)
    )
  }

  static func planExercise(name: String, quantity: String) -> Plan {
    if let blocked = blocked() {
      return blocked
    }
    let split = splitUtterance(name: name, quantity: quantity)
    guard let parsed = parseQuantity(split.quantity) else {
      if cleanName(split.name).isEmpty {
        return stop("種目が分かりません")
      }
      return stop("量が分かりません")
    }
    let spokenName = cleanName(split.name)
    if spokenName.isEmpty {
      return stop("種目が分かりません")
    }
    let key = normalize(spokenName)
    let matches = activities().filter { activity in
      let keys = activity["keys"] as? [String] ?? []
      return keys.contains(key)
    }
    if matches.isEmpty {
      return stop("\(spokenName)は見つかりません")
    }
    if matches.count != 1 {
      return stop("\(spokenName)はひとつに決まりません")
    }
    let activity = matches[0]
    let speakName = activity["speakName"] as? String ?? spokenName
    if (activity["requiresManualKcal"] as? Bool) == true || activity["unit"] as? String == "reps" {
      return stop("\(speakName)は手入力の種目です")
    }
    let unit = activity["unit"] as? String ?? ""
    let spokenFits = (unit == "durationMin" && parsed.unit == "minutes")
      || (unit == "distanceKm" && parsed.unit == "kilometers")
    if !spokenFits {
      let label = unit == "distanceKm" ? "km" : "分"
      return stop("\(speakName)は\(label)で指定してください")
    }
    let lifestyle = (activity["lifestyleIncluded"] as? Bool) == true
    if !lifestyle && (weightKg() == nil || (weightKg() ?? 0) <= 0) {
      return stop("体重が無いので登録できません")
    }
    return Plan(
      spoken: "\(speakName)を\(formatQuantity(parsed))ですね",
      asksConfirmation: true,
      record: exerciseRecord(activity, parsed: parsed)
    )
  }

  private static func blocked() -> Plan? {
    if !LockScreenMealStore.isPaid() {
      return stop("こちらはカロナビ+の機能です")
    }
    if ownerUserId().isEmpty {
      return stop("ログインしてください")
    }
    return nil
  }

  private static func stop(_ spoken: String) -> Plan {
    Plan(spoken: spoken, asksConfirmation: false, record: nil)
  }

  private static func catalog() -> [String: Any] {
    guard
      let raw = defaults?.string(forKey: catalogKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    return json
  }

  private static func foods() -> [[String: Any]] {
    catalog()["foods"] as? [[String: Any]] ?? []
  }

  private static func activities() -> [[String: Any]] {
    catalog()["activities"] as? [[String: Any]] ?? []
  }

  private static func ownerUserId() -> String {
    (catalog()["ownerUserId"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func weightKg() -> Double? {
    (catalog()["weightKg"] as? NSNumber)?.doubleValue
  }

  private static func foodRecord(_ food: [String: Any], amount: Double) -> [String: Any] {
    var record: [String: Any] = [
      "kind": "food",
      "id": UUID().uuidString,
      "ownerUserId": ownerUserId(),
      "loggedAt": LockScreenMealStore.formatLoggedAt(Date()),
      "name": food["speakName"] as? String ?? "",
      "baseAmount": food["baseAmount"] as? NSNumber ?? 100,
      "unit": food["unit"] as? String ?? "g",
      "consumedAmount": amount,
      "source": food["source"] as? String ?? "saved_food",
    ]
    copy(food, "kcalPerBase", into: &record)
    copy(food, "proteinPerBase", into: &record)
    copy(food, "fatPerBase", into: &record)
    copy(food, "carbPerBase", into: &record)
    copy(food, "savedFoodId", into: &record)
    copy(food, "sourceOwnerUserId", into: &record)
    copy(food, "version", into: &record)
    copy(food, "officialFoodCode", into: &record)
    copy(food, "officialFoodName", into: &record)
    return record
  }

  private static func exerciseRecord(
    _ activity: [String: Any],
    parsed: ParsedQuantity
  ) -> [String: Any] {
    var record: [String: Any] = [
      "kind": "exercise",
      "id": UUID().uuidString,
      "ownerUserId": ownerUserId(),
      "loggedAt": LockScreenMealStore.formatLoggedAt(Date()),
      "activityId": activity["id"] as? String ?? "",
      "amount": parsed.amount,
      "quantityUnit": parsed.unit,
    ]
    if let weight = weightKg() {
      record["weightKg"] = weight
    }
    return record
  }

  private static func copy(_ source: [String: Any], _ key: String, into record: inout [String: Any]) {
    if let value = source[key], !(value is NSNull) {
      record[key] = value
    }
  }

  private static func officialFoods(query: String, key: String) async -> [[String: Any]] {
    let json = catalog()
    guard json["officialFoodsEnabled"] as? Bool == true,
          let base = json["supabaseUrl"] as? String, !base.isEmpty,
          let apiKey = json["supabaseAnonKey"] as? String, !apiKey.isEmpty,
          let url = URL(string: "\(base)/rest/v1/rpc/search_official_foods")
    else {
      return []
    }
    var request = URLRequest(url: url, timeoutInterval: 8)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "p_query": query,
      "p_limit": 30,
    ])
    guard
      let (data, response) = try? await URLSession.shared.data(for: request),
      let http = response as? HTTPURLResponse,
      http.statusCode == 200,
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }
    var byCode: [String: [String: Any]] = [:]
    for row in rows {
      guard let food = officialFood(row, key: key), let id = food["id"] as? String else {
        continue
      }
      byCode[id] = food
    }
    return Array(byCode.values)
  }

  private static func officialFood(_ row: [String: Any], key: String) -> [String: Any]? {
    let name = row["name"] as? String ?? ""
    let display = row["display_name"] as? String ?? ""
    let alias = row["matched_alias"] as? String ?? ""
    let reading = row["reading"] as? String ?? ""
    let matched = [alias, display, name, reading].contains { normalize($0) == key && !key.isEmpty }
    if !matched {
      return nil
    }
    let unit = (row["unit_type"] as? String ?? "g").lowercased()
    guard unit == "g" || unit == "ml" else {
      return nil
    }
    let speak = normalize(alias) == key && !alias.isEmpty
      ? alias
      : (normalize(display) == key && !display.isEmpty ? display : name)
    let code = row["food_code"] as? String ?? ""
    if code.isEmpty || speak.isEmpty {
      return nil
    }
    var food: [String: Any] = [
      "id": code,
      "speakName": speak,
      "keys": [key],
      "baseAmount": row["base_amount"] as? NSNumber ?? 100,
      "unit": unit,
      "source": "mext_sfct",
      "officialFoodCode": code,
      "officialFoodName": name,
    ]
    if let kcal = row["kcal"] as? NSNumber { food["kcalPerBase"] = kcal }
    if let protein = row["protein_g"] as? NSNumber { food["proteinPerBase"] = protein }
    if let fat = row["fat_g"] as? NSNumber { food["fatPerBase"] = fat }
    if let carb = row["carb_g"] as? NSNumber { food["carbPerBase"] = carb }
    return food
  }

  private struct ParsedQuantity {
    var amount: Double
    var unit: String
  }

  private static func parseQuantity(_ raw: String) -> ParsedQuantity? {
    let compact = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
    guard let regex = try? NSRegularExpression(pattern: #"^(\d+(?:\.\d+)?)(.*)$"#) else {
      return nil
    }
    let range = NSRange(compact.startIndex..., in: compact)
    guard let found = regex.firstMatch(in: compact, range: range),
          let amountRange = Range(found.range(at: 1), in: compact),
          let unitRange = Range(found.range(at: 2), in: compact),
          let amount = Double(compact[amountRange]),
          amount > 0, amount < 100_000
    else {
      return nil
    }
    let unit = String(compact[unitRange])
    let mapped: String?
    switch unit {
    case "g", "G", "ｇ", "グラム":
      mapped = "grams"
    case "ml", "mL", "ML", "ｍｌ", "ミリリットル":
      mapped = "milliliters"
    case "個", "こ", "コ":
      mapped = "piece"
    case "食", "食分":
      mapped = "serving"
    case "分", "分間":
      mapped = "minutes"
    case "回":
      mapped = "reps"
    case "km", "KM", "㎞", "キロ", "キロメートル":
      mapped = "kilometers"
    default:
      mapped = nil
    }
    guard let mapped else { return nil }
    return ParsedQuantity(amount: amount, unit: mapped)
  }

  private static func formatQuantity(_ quantity: ParsedQuantity) -> String {
    let number = quantity.amount == quantity.amount.rounded()
      ? String(Int(quantity.amount.rounded()))
      : String(quantity.amount)
    let suffix: String
    switch quantity.unit {
    case "grams":
      suffix = "g"
    case "milliliters":
      suffix = "ml"
    case "piece":
      suffix = "個"
    case "serving":
      suffix = "食"
    case "minutes":
      suffix = "分"
    case "reps":
      suffix = "回"
    case "kilometers":
      suffix = "km"
    default:
      suffix = ""
    }
    return number + suffix
  }

  private static func foodUnitFits(_ foodUnit: String, spoken: String) -> Bool {
    switch foodUnit {
    case "g": return spoken == "grams"
    case "ml": return spoken == "milliliters"
    case "piece": return spoken == "piece"
    case "serving": return spoken == "serving"
    default: return false
    }
  }

  private static func foodUnitLabel(_ unit: String) -> String {
    switch unit {
    case "g": return "g"
    case "ml": return "ml"
    case "piece": return "個"
    case "serving": return "1食分"
    default: return unit
    }
  }

  private static func splitUtterance(name: String, quantity: String) -> (name: String, quantity: String) {
    if parseQuantity(quantity) != nil {
      return (name, quantity)
    }
    let source = quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? name.trimmingCharacters(in: .whitespacesAndNewlines)
      : name.trimmingCharacters(in: .whitespacesAndNewlines) + quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let regex = try? NSRegularExpression(pattern: #"^(?:食事に|運動に)?(.+?)を\s*(\d.*)$"#) else {
      return (name, quantity)
    }
    let range = NSRange(source.startIndex..., in: source)
    guard let found = regex.firstMatch(in: source, range: range),
          let nameRange = Range(found.range(at: 1), in: source),
          let quantityRange = Range(found.range(at: 2), in: source)
    else {
      return (name, quantity)
    }
    return (String(source[nameRange]), String(source[quantityRange]))
  }

  private static func cleanName(_ raw: String) -> String {
    var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if name.hasPrefix("食事に") {
      name = String(name.dropFirst(3))
    } else if name.hasPrefix("運動に") {
      name = String(name.dropFirst(3))
    }
    if name.hasSuffix("を") {
      name = String(name.dropLast(1))
    }
    return name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Dart の `FoodSearchNormalizer.normalize` と同じ手順。
  static func normalize(_ raw: String?) -> String {
    guard let raw, !raw.isEmpty else { return "" }
    let composed = composeHalfwidthVoiced(raw)
    var output = ""
    for scalar in composed.unicodeScalars {
      var code = scalar.value
      if code >= 0xFF01 && code <= 0xFF5E {
        code -= 0xFEE0
      } else if code == 0x3000 {
        code = 0x20
      } else if let mapped = halfwidthKatakana(code) {
        code = mapped
      }
      if code >= 0x30A1 && code <= 0x30F6 {
        code -= 0x60
      }
      if code >= 0x41 && code <= 0x5A {
        code += 0x20
      }
      if isLongVowelOrHyphen(code) || isWhitespace(code) {
        continue
      }
      if let unicode = UnicodeScalar(code) {
        output.unicodeScalars.append(unicode)
      }
    }
    return output
  }

  private static func composeHalfwidthVoiced(_ text: String) -> String {
    let dakutenBase = Array("ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ")
    let dakutenTo = Array("ガギグゲゴザジズゼゾダヂヅデドバビブベボ")
    let handakutenBase = Array("ﾊﾋﾌﾍﾎ")
    let handakutenTo = Array("パピプペポ")
    let scalars = Array(text.unicodeScalars)
    var output = ""
    var index = 0
    while index < scalars.count {
      let code = scalars[index].value
      if index + 1 < scalars.count {
        let next = scalars[index + 1].value
        if next == 0xFF9E, let at = dakutenBase.firstIndex(where: { $0.unicodeScalars.first?.value == code }) {
          output.append(dakutenTo[at])
          index += 2
          continue
        }
        if next == 0xFF9F, let at = handakutenBase.firstIndex(where: { $0.unicodeScalars.first?.value == code }) {
          output.append(handakutenTo[at])
          index += 2
          continue
        }
      }
      output.unicodeScalars.append(scalars[index])
      index += 1
    }
    return output
  }

  private static func halfwidthKatakana(_ code: UInt32) -> UInt32? {
    guard code >= 0xFF66 && code <= 0xFF9D else { return nil }
    let from = Array("ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ")
    let to = Array("ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン")
    guard let at = from.firstIndex(where: { $0.unicodeScalars.first?.value == code }),
          let mapped = to[at].unicodeScalars.first?.value
    else {
      return nil
    }
    return mapped
  }

  private static func isLongVowelOrHyphen(_ code: UInt32) -> Bool {
    [0x30FC, 0x002D, 0x2010, 0x2011, 0x2013, 0x2014, 0x2212].contains(code)
  }

  private static func isWhitespace(_ code: UInt32) -> Bool {
    if code == 9 || code == 10 || code == 11 || code == 12 || code == 13 || code == 32 {
      return true
    }
    if code == 133 || code == 160 || code == 5760 || code == 8232 || code == 8233 || code == 8239 || code == 8287 || code == 12288 || code == 65279 {
      return true
    }
    return code >= 8192 && code <= 8202
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

@available(iOS 17.0, *)
struct LogSpokenFoodIntent: AppIntent {
  static var title: LocalizedStringResource = "食事を登録"
  static var description = IntentDescription("食品名と量を復唱し、はいのときだけ今日の食事に1件登録します。")
  static var openAppWhenRun = false

  @Parameter(title: "食品")
  var foodName: String

  @Parameter(title: "量")
  var quantity: String

  init() {
    self.foodName = ""
    self.quantity = ""
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let plan = await SiriVoiceStore.planFood(name: foodName, quantity: quantity)
    guard plan.asksConfirmation, let record = plan.record else {
      return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    }
    try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: plan.spoken)))
    SiriVoiceStore.commit(record)
    return .result(dialog: "登録しました")
  }
}

@available(iOS 17.0, *)
struct LogSpokenExerciseIntent: AppIntent {
  static var title: LocalizedStringResource = "運動を登録"
  static var description = IntentDescription("種目と量を復唱し、はいのときだけ今日の運動に1件登録します。")
  static var openAppWhenRun = false

  @Parameter(title: "種目")
  var activityName: String

  @Parameter(title: "量")
  var quantity: String

  init() {
    self.activityName = ""
    self.quantity = ""
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let plan = SiriVoiceStore.planExercise(name: activityName, quantity: quantity)
    guard plan.asksConfirmation, let record = plan.record else {
      return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    }
    try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: plan.spoken)))
    SiriVoiceStore.commit(record)
    return .result(dialog: "登録しました")
  }
}

@available(iOS 17.0, *)
struct CalonaviSiriShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogSpokenFoodIntent(),
      phrases: [
        "\(.applicationName)で食事に\(\.$foodName)を\(\.$quantity)",
      ],
      shortTitle: "食事を登録",
      systemImageName: "fork.knife"
    )
    AppShortcut(
      intent: LogSpokenExerciseIntent(),
      phrases: [
        "\(.applicationName)で運動に\(\.$activityName)を\(\.$quantity)",
      ],
      shortTitle: "運動を登録",
      systemImageName: "figure.run"
    )
  }
}
