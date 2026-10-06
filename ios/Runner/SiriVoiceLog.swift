import AppIntents
import Foundation

/// 食事と運動を、復唱して「はい」のときだけ1件登録する。
///
/// 決まった始まりは「Hey Siri、カロナビで」。食事か運動かは言葉から判別する。
/// 登録前に「鶏むね100gの食事でいいですね」のように復唱する。
/// どちらとも取れない言葉は、復唱で食事か運動かを確認する。
/// 「Hey Siri、カロナビに登録」では、先に食事か運動かを聞き、そのあと食品か種目を聞く。
/// 「カロナビで登録」「カロナビで記録」も同じ。答えた自由文は今までの名寄せへ渡す。
/// 「Hey Siri、カロナビで、食事にささみを300グラム。」
/// 「Hey Siri、カロナビで、運動にジョギングを30分。」
/// 食事だけの言い方と運動だけの言い方も残す。フレーズのパラメータは1つだけ、型は AppEntity。
/// 食品名と量は、その1つの言葉から今までどおり分ける。
///
/// 「いいえ」や無言では `requestConfirmation` が途中で終わるので、その前には書かない。
/// 食事と運動のテンプレート名でも登録する。未課金は登録しない。公開食品は扱わない。
/// `openAppWhenRun` は false。判定と書き込みは App Group だけで、アプリが閉じていても Siri が実行する。
/// 名寄せの順は Dart の `pickSiriMatches` と同じ。0件は言い直したあと、検索語を残してアプリを開く。
/// ショートカットのアイコンは後で差し替える。今はプレースホルダー。
enum SiriVoiceStore {
  static let catalogKey = "siriVoiceCatalog"
  static let pendingKey = "siriVoicePending"
  static let openSearchKey = "siriVoiceOpenSearch"
  static let continueSearchKey = "siriVoiceContinueSearch"

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
    commitAll([record])
  }

  static func commitAll(_ records: [[String: Any]]) {
    var pending = readPendingArray()
    pending.append(contentsOf: records)
    writePendingArray(pending)
    var intake = 0.0
    var burn = 0.0
    for record in records {
      if record["kind"] as? String == "food" {
        intake += LockScreenMealStore.foodKcal([record])
      } else {
        burn += LockScreenMealStore.number(record["netKcal"])
      }
    }
    if intake != 0 || burn != 0 {
      LockScreenMealStore.applyFigures(intakeDelta: intake, burnDelta: burn)
    }
  }

  private static func jsonInt(_ value: Any?) -> Int? {
    if let number = value as? Int {
      return number
    }
    if let number = value as? NSNumber {
      return number.intValue
    }
    return nil
  }

  private static func jsonBool(_ value: Any?) -> Bool {
    if let flag = value as? Bool {
      return flag
    }
    if let number = value as? NSNumber {
      return number.boolValue
    }
    return false
  }

  struct Plan {
    var spoken: String
    var asksConfirmation: Bool
    var asksKind: Bool = false
    var asksChoice: Bool = false
    var asksAmount: Bool = false
    var asksRetry: Bool = false
    var record: [String: Any]?
    var records: [[String: Any]] = []
    var choices: [[String: Any]] = []
    var pendingName: String?
    var pendingAmount: Double?
    var pendingUnit: String?
    var pendingQuantity: String?
    var searchQuery: String?
    var searchKind: String = "food"
    var intakeKcal: Double = 0
    var burnKcal: Double = 0
  }

  @available(iOS 16.0, *)
  static func planFood(name: String, quantity: String) async -> Plan {
    await plan(name: name, quantity: quantity, forced: .meal)
  }

  @available(iOS 16.0, *)
  static func planExercise(name: String, quantity: String) async -> Plan {
    await plan(name: name, quantity: quantity, forced: .exercise)
  }

  @available(iOS 16.0, *)
  static func planUtterance(name: String, quantity: String) async -> Plan {
    await plan(name: name, quantity: quantity, forced: nil)
  }

  @available(iOS 16.0, *)
  static func resolveKind(_ plan: Plan, kind: SiriSpokenKind) async -> Plan {
    guard plan.asksKind,
          let name = plan.pendingName,
          let amount = plan.pendingAmount,
          let unit = plan.pendingUnit
    else {
      return plan
    }
    let parsed = ParsedQuantity(amount: amount, unit: unit)
    if kind == .meal {
      return await mealPlan(name: name, parsed: parsed)
    }
    return exercisePlan(name: name, parsed: parsed)
  }

  @available(iOS 16.0, *)
  private static func plan(
    name: String,
    quantity: String,
    forced: SiriSpokenKind?
  ) async -> Plan {
    if let blocked = blocked() {
      return blocked
    }
    let source = utterance(name, quantity)
    if mentionsPhraseShape(source) && !source.contains("カロナビ") {
      return stop("アプリ名が無いので登録しません")
    }
    let explicit = explicitKind(source)
    let kind = explicit ?? (mentionsPhraseShape(source) ? nil : forced)
    let spoken = quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? name
      : name.trimmingCharacters(in: .whitespacesAndNewlines)
        + " "
        + quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    var interpretations: [String] = []
    for option in speechInterpretations(spoken) {
      let folded = foldSpokenQuantities(option)
      if !folded.isEmpty && !interpretations.contains(folded) {
        interpretations.append(folded)
      }
    }
    if interpretations.count > 1 {
      if let chosen = await chooseInterpretation(interpretations, kind: kind) {
        return chosen
      }
    }
    let repaired = interpretations.first ?? spoken
    let split = splitUtterance(
      name: repaired,
      quantity: interpretations.isEmpty ? quantity : ""
    )
    if kind == .meal {
      return await mealPlan(spoken: split.name, quantity: split.quantity)
    }
    if kind == .exercise {
      return exercisePlan(spoken: split.name, quantity: split.quantity)
    }
    return await classify(name: split.name, quantity: split.quantity)
  }

  private static func classify(name: String, quantity: String) async -> Plan {
    let spokenName = cleanName(name)
    if spokenName.isEmpty {
      return stop("内容が分かりません")
    }
    let parsed = parseQuantity(quantity)
    let foodNamed = await mealNamed(spokenName)
    let exerciseNamed = exerciseNamed(spokenName)
    if foodNamed && !exerciseNamed {
      return await mealPlan(name: spokenName, quantityText: quantity, parsed: parsed)
    }
    if exerciseNamed && !foodNamed {
      return exercisePlan(name: spokenName, quantityText: quantity, parsed: parsed)
    }
    guard let parsed else {
      if !foodNamed && !exerciseNamed {
        return rescue(spokenName)
      }
      return stop("量が分かりません")
    }
    return Plan(
      spoken: "\(spokenName)\(formatQuantity(parsed))は、食事ですか、運動ですか",
      asksConfirmation: true,
      asksKind: true,
      record: nil,
      pendingName: spokenName,
      pendingAmount: parsed.amount,
      pendingUnit: parsed.unit,
      pendingQuantity: quantity
    )
  }

  private static func mealPlan(spoken: String, quantity: String) async -> Plan {
    let name = cleanName(spoken)
    let parsed = parseQuantity(quantity)
    if name.isEmpty {
      return stop("食品名が分かりません")
    }
    return await mealPlan(name: name, quantityText: quantity, parsed: parsed)
  }

  private static func mealPlan(name: String, parsed: ParsedQuantity) async -> Plan {
    await mealPlan(name: name, quantityText: formatQuantity(parsed), parsed: parsed)
  }

  private static func mealPlan(
    name: String,
    quantityText: String,
    parsed: ParsedQuantity?
  ) async -> Plan {
    if name.isEmpty {
      return stop("食品名が分かりません")
    }
    let templates = rankTemplates(mealTemplates(), name: name)
    let foods = await rankFoods(name)
    let templateExact = templates.count == 1 && (jsonInt(templates[0]["matchRank"]) ?? 9) == 0
      && isObvious(templates)
    let foodExact = foods.count == 1 && (jsonInt(foods[0]["matchRank"]) ?? 9) == 0
      && isObvious(foods)
    if templateExact && foodExact {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: [
          choice(templates[0], kind: "mealTemplate", suffix: "（テンプレート）"),
          choice(foods[0], kind: "food", suffix: ""),
        ]
      )
    }
    if templateExact {
      return confirmMealTemplate(templates[0])
    }
    if foods.isEmpty && templates.isEmpty {
      return rescue(name, kind: "food")
    }
    if !isObvious(foods) && foods.count > 1 {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: foods.prefix(4).map { choice($0, kind: "food", suffix: "") }
      )
    }
    if foods.isEmpty && !isObvious(templates) && templates.count > 1 {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: templates.prefix(4).map { choice($0, kind: "mealTemplate", suffix: "（テンプレート）") }
      )
    }
    if foods.isEmpty, let template = templates.first {
      return confirmMealTemplate(template)
    }
    return confirmFood(foods[0], quantityText: quantityText, parsed: parsed, assumeUnit: false)
  }

  private static func exercisePlan(spoken: String, quantity: String) -> Plan {
    let name = cleanName(spoken)
    if name.isEmpty {
      return stop("種目が分かりません")
    }
    return exercisePlan(name: name, quantityText: quantity, parsed: parseQuantity(quantity))
  }

  private static func exercisePlan(name: String, parsed: ParsedQuantity) -> Plan {
    exercisePlan(name: name, quantityText: formatQuantity(parsed), parsed: parsed)
  }

  private static func exercisePlan(
    name: String,
    quantityText: String,
    parsed: ParsedQuantity?
  ) -> Plan {
    if name.isEmpty {
      return stop("種目が分かりません")
    }
    let templates = rankTemplates(workoutTemplates(), name: name)
    let activities = rankExercises(name)
    let templateExact = templates.count == 1 && (jsonInt(templates[0]["matchRank"]) ?? 9) == 0
      && isObvious(templates)
    let activityExact = activities.count == 1 && (jsonInt(activities[0]["matchRank"]) ?? 9) == 0
      && isObvious(activities)
    if templateExact && activityExact {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: [
          choice(templates[0], kind: "workoutTemplate", suffix: "（テンプレート）"),
          choice(activities[0], kind: "exercise", suffix: ""),
        ]
      )
    }
    if templateExact {
      return confirmWorkoutTemplate(templates[0])
    }
    if activities.isEmpty && templates.isEmpty {
      return rescue(name, kind: "exercise")
    }
    if !isObvious(activities) && activities.count > 1 {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: activities.prefix(4).map { choice($0, kind: "exercise", suffix: "") }
      )
    }
    if activities.isEmpty, let template = templates.first, templates.count == 1 || isObvious(templates) {
      return confirmWorkoutTemplate(template)
    }
    if activities.isEmpty {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: templates.prefix(4).map { choice($0, kind: "workoutTemplate", suffix: "（テンプレート）") }
      )
    }
    return confirmExercise(
      activities[0],
      quantityText: quantityText,
      parsed: parsed,
      assumeMinutes: false
    )
  }

  private static func mealNamed(_ name: String) async -> Bool {
    if !rankTemplates(mealTemplates(), name: name).isEmpty {
      return true
    }
    return !(await rankFoods(name)).isEmpty
  }

  private static func exerciseNamed(_ name: String) -> Bool {
    if spokenExerciseId(name) != nil {
      return true
    }
    if !rankExercises(name).isEmpty {
      return true
    }
    return !rankTemplates(workoutTemplates(), name: name).isEmpty
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
    record["netKcal"] = exerciseNetKcal(activity, parsed: parsed)
    return record
  }

  private static func exerciseNetKcal(_ activity: [String: Any], parsed: ParsedQuantity) -> Double {
    if (activity["lifestyleIncluded"] as? Bool) == true {
      return 0
    }
    let weight = weightKg() ?? 0
    if weight <= 0 {
      return 0
    }
    if parsed.unit == "minutes" {
      let met = LockScreenMealStore.number(activity["met"])
      if met <= 1 {
        return 0
      }
      return (met - 1) * 3.5 * weight / 200 * parsed.amount
    }
    if parsed.unit == "kilometers" {
      let factor = LockScreenMealStore.number(activity["netKcalPerKgKm"])
      if factor <= 0 {
        return 0
      }
      return factor * weight * parsed.amount
    }
    return 0
  }

  private static func copy(_ source: [String: Any], _ key: String, into record: inout [String: Any]) {
    if let value = source[key], !(value is NSNull) {
      record[key] = value
    }
  }

  private static func officialFoodRows(query: String) async -> [[String: Any]] {
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
      "p_query": String(query.prefix(64)),
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
    return rows
  }

  /// 助詞を除いた言い方も成分表へ投げる。SQL の並びを sqlOrder で残す。
  /// 2文字以下は完全一致だけを残し、「ささ」で「ささみ」を採らない。
  private static func officialFoods(query: String) async -> [[String: Any]] {
    var merged: [String: [String: Any]] = [:]
    var sequence = 0
    for variant in queryVariants(query) {
      let rows = await officialFoodRows(query: variant)
      for row in rows {
        guard var food = officialFood(row), let id = food["id"] as? String else {
          continue
        }
        let rank = jsonInt(food["matchRank"]) ?? 9
        if variant.count < 3, rank > 0 {
          continue
        }
        food["sqlOrder"] = sequence
        sequence += 1
        if let current = merged[id] {
          merged[id] = hitPrecedes(food, current) ? food : current
        } else {
          merged[id] = food
        }
      }
    }
    return merged.values.sorted(by: hitPrecedes)
  }

  /// SQL が順位づけ済みの行を、完全一致で捨てない。
  private static func officialFood(_ row: [String: Any]) -> [String: Any]? {
    let name = row["name"] as? String ?? ""
    let display = row["display_name"] as? String ?? ""
    let alias = row["matched_alias"] as? String ?? ""
    let unit = (row["unit_type"] as? String ?? "g").lowercased()
    guard unit == "g" || unit == "ml" else {
      return nil
    }
    let speak = !display.isEmpty ? display : (!alias.isEmpty ? alias : name)
    let code = row["food_code"] as? String ?? ""
    if code.isEmpty || speak.isEmpty {
      return nil
    }
    var food: [String: Any] = [
      "id": code,
      "speakName": speak,
      "keys": [normalize(speak)],
      "baseAmount": row["base_amount"] as? NSNumber ?? 100,
      "unit": unit,
      "source": "mext_sfct",
      "officialFoodCode": code,
      "officialFoodName": name,
      "matchRank": jsonInt(row["match_rank"]) ?? 9,
      "isCandidate": jsonBool(row["is_candidate"]),
      "candidateRank": jsonInt(row["candidate_rank"]) ?? 100,
      "priority": jsonInt(row["priority"]) ?? 100,
      "aliasMatched": !alias.isEmpty,
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
    var compact = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
    if let trailing = try? NSRegularExpression(pattern: #"[。．.！!？?]+$"#) {
      let trailingRange = NSRange(compact.startIndex..., in: compact)
      compact = trailing.stringByReplacingMatches(
        in: compact,
        range: trailingRange,
        withTemplate: ""
      )
    }
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

  @available(iOS 16.0, *)
  private static func explicitKind(_ source: String) -> SiriSpokenKind? {
    let meal = source.contains("食事に")
    let exercise = source.contains("運動に")
    if meal == exercise {
      return nil
    }
    return meal ? .meal : .exercise
  }

  private static func utterance(_ name: String, _ quantity: String) -> String {
    let raw = quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? name
      : name + quantity
    return raw
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
  }

  private static func mentionsPhraseShape(_ source: String) -> Bool {
    source.contains("カロナビ")
      || source.contains("食事に")
      || source.contains("運動に")
      || source.contains("HeySiri")
      || source.contains("heySiri")
  }

  /// Dart の `siriSpeechInterpretations` と同じ。孤立したフィラーだけを落とす。
  private static func speechInterpretations(_ raw: String) -> [String] {
    let tokens = contentTokens(raw)
    if tokens.isEmpty {
      return []
    }
    let concatenated = tokens.joined()
    let adopted = adoptLater(tokens).joined()
    var interpretations: [String] = []
    if !adopted.isEmpty {
      interpretations.append(adopted)
    }
    if !concatenated.isEmpty && concatenated != adopted {
      interpretations.append(concatenated)
    }
    return interpretations
  }

  private static let fillerSurfaces = [
    "あ", "あー", "あぁ", "ああ", "あっ", "あ〜", "あ～",
    "え", "えー", "えぇ", "ええ", "えっ", "え〜",
    "えっと", "えーっと", "えーと", "えと",
    "うーん", "ううん", "うん",
    "んー", "んん", "ん",
    "あの", "あのー", "あのう", "あのね",
    "その", "そのー", "そのね",
    "まあ", "まー", "まぁ",
    "なんか", "なんかー", "なんかね",
    "えっとね", "えーっとね", "えーとね",
  ]

  private static func contentTokens(_ raw: String) -> [String] {
    var tokens: [String] = []
    var buffer = ""
    let characters = Array(raw)
    for index in characters.indices {
      let character = String(characters[index])
      let previous = index == characters.startIndex ? "" : String(characters[characters.index(before: index)])
      let nextIndex = characters.index(after: index)
      let next = nextIndex < characters.endIndex ? String(characters[nextIndex]) : ""
      if isSpeechDelimiter(character, previous: previous, next: next) {
        flushToken(&buffer, into: &tokens)
      } else {
        buffer.append(character)
      }
    }
    flushToken(&buffer, into: &tokens)
    return tokens
  }

  private static func flushToken(_ buffer: inout String, into tokens: inout [String]) {
    let token = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    buffer = ""
    if token.isEmpty || isFiller(token) {
      return
    }
    tokens.append(token)
  }

  private static func isSpeechDelimiter(
    _ character: String,
    previous: String,
    next: String
  ) -> Bool {
    if character == " " || character == "\n" || character == "\t" || character == "\r" || character == "　" {
      return true
    }
    if "、。，,！!？?・…".contains(character) {
      return true
    }
    if character == "." || character == "．" {
      let before = Int(previous) != nil
      let after = Int(next) != nil
      return !(before && after)
    }
    return false
  }

  private static func isFiller(_ token: String) -> Bool {
    fillerKeys.contains(fillerKey(token))
  }

  private static let fillerKeys: Set<String> = Set(fillerSurfaces.map { fillerKey($0) })

  private static func fillerKey(_ token: String) -> String {
    var folded = token
    let pairs = [
      ("ぁ", "あ"), ("ぃ", "い"), ("ぅ", "う"), ("ぇ", "え"), ("ぉ", "お"),
      ("ァ", "ア"), ("ィ", "イ"), ("ゥ", "ウ"), ("ェ", "エ"), ("ォ", "オ"),
    ]
    for pair in pairs {
      folded = folded.replacingOccurrences(of: pair.0, with: pair.1)
    }
    return normalize(folded)
  }

  private static func adoptLater(_ tokens: [String]) -> [String] {
    var kept: [String] = []
    for token in tokens {
      if let last = kept.last, laterCorrects(token, earlier: last) {
        kept[kept.count - 1] = token
      } else {
        kept.append(token)
      }
    }
    return kept
  }

  private static func laterCorrects(_ later: String, earlier: String) -> Bool {
    let laterKey = normalize(later)
    let earlierKey = normalize(earlier)
    return !earlierKey.isEmpty && laterKey.hasPrefix(earlierKey)
  }

  private static let quantityUnits = [
    "ミリリットル", "キロメートル", "グラム", "分間", "食分",
    "ml", "mL", "ML", "ｍｌ", "km", "KM", "㎞", "キロ",
    "個", "こ", "コ", "食", "分", "回", "g", "G", "ｇ",
  ]

  private static func foldSpokenQuantities(_ text: String) -> String {
    var result = text
    for unit in quantityUnits {
      var from = result.startIndex
      while from < result.endIndex,
            let range = result.range(of: unit, range: from..<result.endIndex) {
        if let number = japaneseNumberBefore(result, at: range.lowerBound) {
          let digits = String(number.value)
          let prefixCount = result.distance(from: result.startIndex, to: number.start)
          result.replaceSubrange(number.start..<range.lowerBound, with: digits)
          let start = result.index(result.startIndex, offsetBy: prefixCount)
          let afterDigits = result.index(start, offsetBy: digits.count, limitedBy: result.endIndex)
            ?? result.endIndex
          from = result.index(afterDigits, offsetBy: unit.count, limitedBy: result.endIndex)
            ?? result.endIndex
        } else {
          from = range.upperBound
        }
      }
    }
    return result
  }

  private static func japaneseNumberBefore(
    _ text: String,
    at: String.Index
  ) -> (start: String.Index, value: Int)? {
    var index = at
    while index > text.startIndex {
      let previous = text.index(before: index)
      if !isHiragana(text[previous]) {
        break
      }
      index = previous
    }
    let slice = String(text[index..<at])
    if slice.isEmpty {
      return nil
    }
    var cut = slice.startIndex
    while cut < slice.endIndex {
      let part = String(slice[cut...])
      if let value = parseJapaneseNumber(part) {
        let start = text.index(index, offsetBy: slice.distance(from: slice.startIndex, to: cut))
        return (start, value)
      }
      cut = slice.index(after: cut)
    }
    return nil
  }

  private static func isHiragana(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
      return false
    }
    return scalar.value >= 0x3041 && scalar.value <= 0x3096
  }

  private static func parseJapaneseNumber(_ text: String) -> Int? {
    if text.isEmpty {
      return nil
    }
    let ones = [
      "れい": 0, "いち": 1, "に": 2, "さん": 3, "よん": 4, "し": 4,
      "ご": 5, "ろく": 6, "なな": 7, "しち": 7, "はち": 8, "きゅう": 9, "く": 9,
    ]
    let units = [
      "せん": 1000, "ぜん": 1000, "ひゃく": 100, "びゃく": 100, "ぴゃく": 100,
      "じゅう": 10, "じゅっ": 10, "じっ": 10,
    ]
    var index = text.startIndex
    var total = 0
    var current = 0
    var saw = false
    while index < text.endIndex {
      if let taken = takeNumber(units, from: text, at: index) {
        let count = current == 0 ? 1 : current
        total += count * taken.value
        current = 0
        index = text.index(index, offsetBy: taken.length)
        saw = true
        continue
      }
      guard let one = takeNumber(ones, from: text, at: index) else {
        return nil
      }
      current = one.value
      index = text.index(index, offsetBy: one.length)
      saw = true
    }
    if !saw {
      return nil
    }
    return total + current
  }

  private static func takeNumber(
    _ table: [String: Int],
    from text: String,
    at index: String.Index
  ) -> (value: Int, length: Int)? {
    let keys = table.keys.sorted { $0.count > $1.count }
    for key in keys where text[index...].hasPrefix(key) {
      return (table[key] ?? 0, key.count)
    }
    return nil
  }

  private static func chooseInterpretation(
    _ interpretations: [String],
    kind: SiriSpokenKind?
  ) async -> Plan? {
    struct Score {
      var name: String
      var quantity: String
      var rank: Int
      var id: String
      var title: String
      var choiceKind: String
    }
    var scores: [Score] = []
    for text in interpretations {
      let split = splitUtterance(name: text, quantity: "")
      if let hit = await bestSpeechHit(split.name, kind: kind) {
        scores.append(
          Score(
            name: split.name,
            quantity: split.quantity,
            rank: hit.rank,
            id: hit.id,
            title: hit.title,
            choiceKind: hit.choiceKind
          )
        )
      } else {
        scores.append(
          Score(
            name: split.name,
            quantity: split.quantity,
            rank: 9,
            id: "",
            title: "",
            choiceKind: ""
          )
        )
      }
    }
    guard let best = scores.map(\.rank).min(), best < 9 else {
      return nil
    }
    let winners = scores.filter { $0.rank == best && !$0.id.isEmpty }
    let ids = Set(winners.map(\.id))
    guard let winner = winners.first else {
      return nil
    }
    if ids.count <= 1 {
      if kind == .meal {
        return await mealPlan(spoken: winner.name, quantity: winner.quantity)
      }
      if kind == .exercise {
        return exercisePlan(spoken: winner.name, quantity: winner.quantity)
      }
      return await classify(name: winner.name, quantity: winner.quantity)
    }
    return choicePlan(
      name: winner.name,
      quantityText: winner.quantity,
      choices: winners.map { item in
        [
          "id": item.id,
          "title": item.title,
          "kind": item.choiceKind,
        ]
      }
    )
  }

  private static func bestSpeechHit(
    _ name: String,
    kind: SiriSpokenKind?
  ) async -> (rank: Int, id: String, title: String, choiceKind: String)? {
    var bestRank = 9
    var best: (rank: Int, id: String, title: String, choiceKind: String)?
    func consider(_ hits: [[String: Any]], choiceKind: String, suffix: String) {
      guard let top = hits.first else { return }
      let rank = jsonInt(top["matchRank"]) ?? 9
      if rank < bestRank {
        bestRank = rank
        let speak = (top["speakName"] as? String ?? "") + suffix
        best = (rank, top["id"] as? String ?? "", speak, choiceKind)
      }
    }
    if kind != .exercise {
      consider(await rankFoods(name), choiceKind: "food", suffix: "")
      consider(
        rankTemplates(mealTemplates(), name: name),
        choiceKind: "mealTemplate",
        suffix: "（テンプレート）"
      )
    }
    if kind != .meal {
      consider(rankExercises(name), choiceKind: "exercise", suffix: "")
      consider(
        rankTemplates(workoutTemplates(), name: name),
        choiceKind: "workoutTemplate",
        suffix: "（テンプレート）"
      )
    }
    return best
  }

  private static func splitUtterance(name: String, quantity: String) -> (name: String, quantity: String) {
    if parseQuantity(quantity) != nil && !mentionsPhraseShape(utterance(name, "")) {
      return (cleanName(name), quantity.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var source = quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? name.trimmingCharacters(in: .whitespacesAndNewlines)
      : name.trimmingCharacters(in: .whitespacesAndNewlines)
        + " "
        + quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    if let wake = try? NSRegularExpression(pattern: #"^(?:Hey|hey)\s*Siri[、,]?\s*"#) {
      let range = NSRange(source.startIndex..., in: source)
      source = wake.stringByReplacingMatches(in: source, range: range, withTemplate: "")
    }
    guard let regex = try? NSRegularExpression(
      pattern: #"^(?:カロナビで[、,]?)?(?:食事に|運動に)?(.+?)を\s*(\d.*)$"#
    ) else {
      return (cleanName(name), quantity)
    }
    let range = NSRange(source.startIndex..., in: source)
    if let found = regex.firstMatch(in: source, range: range),
       let nameRange = Range(found.range(at: 1), in: source),
       let quantityRange = Range(found.range(at: 2), in: source) {
      return (String(source[nameRange]), String(source[quantityRange]))
    }
    let compact = source
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
    let units = "ミリリットル|キロメートル|グラム|分間|食分|ml|mL|ML|ｍｌ|km|KM|㎞|キロ|個|こ|コ|食|分|回|g|G|ｇ"
    if let tail = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)(\(units))$"),
       let tailMatch = tail.firstMatch(
        in: compact,
        range: NSRange(compact.startIndex..., in: compact)
       ),
       let amountRange = Range(tailMatch.range(at: 1), in: compact),
       let unitRange = Range(tailMatch.range(at: 2), in: compact) {
      let cleaned = cleanName(String(compact[..<amountRange.lowerBound]))
      let spokenQuantity = String(compact[amountRange]) + String(compact[unitRange])
      if !cleaned.isEmpty && parseQuantity(spokenQuantity) != nil {
        return (cleaned, spokenQuantity)
      }
    }
    if let vague = splitVagueTail(cleanName(compact)) {
      return vague
    }
    return (name, quantity)
  }

  private static func cleanName(_ raw: String) -> String {
    var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let wake = try? NSRegularExpression(pattern: #"^(?:Hey|hey)\s*Siri[、,]?\s*"#) {
      let range = NSRange(name.startIndex..., in: name)
      name = wake.stringByReplacingMatches(in: name, range: range, withTemplate: "")
    }
    if let app = try? NSRegularExpression(pattern: #"^カロナビで[、,]?\s*"#) {
      let range = NSRange(name.startIndex..., in: name)
      name = app.stringByReplacingMatches(in: name, range: range, withTemplate: "")
    }
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

  private static func confirmFood(
    _ food: [String: Any],
    quantityText: String,
    parsed: ParsedQuantity?,
    assumeUnit: Bool
  ) -> Plan {
    let speakName = food["speakName"] as? String ?? ""
    let unit = food["unit"] as? String ?? "g"
    let amount = parsed ?? (assumeUnit ? parseQuantity(quantityText + foodUnitSuffix(unit)) : nil)
    guard let amount else {
      return Plan(
        spoken: foodAmountQuestion(unit),
        asksConfirmation: false,
        asksAmount: true,
        record: food,
        pendingName: speakName,
        pendingQuantity: quantityText
      )
    }
    guard foodUnitFits(unit, spoken: amount.unit) else {
      return stop("\(speakName)は\(foodUnitLabel(unit))で指定してください")
    }
    let record = foodRecord(food, amount: amount.amount)
    return Plan(
      spoken: "\(speakName)\(formatQuantity(amount))の食事でいいですね",
      asksConfirmation: true,
      record: record,
      records: [record],
      intakeKcal: LockScreenMealStore.foodKcal([record])
    )
  }

  private static func confirmExercise(
    _ activity: [String: Any],
    quantityText: String,
    parsed: ParsedQuantity?,
    assumeMinutes: Bool
  ) -> Plan {
    let speakName = activity["speakName"] as? String ?? ""
    if (activity["requiresManualKcal"] as? Bool) == true || activity["unit"] as? String == "reps" {
      return stop("\(speakName)は手入力の種目です")
    }
    let amount = parsed ?? (assumeMinutes ? parseQuantity(quantityText + "分") : nil)
    guard let amount else {
      return Plan(
        spoken: "何分ですか？",
        asksConfirmation: false,
        asksAmount: true,
        record: activity,
        pendingName: speakName,
        pendingQuantity: quantityText
      )
    }
    let unit = activity["unit"] as? String ?? ""
    let minutesOk = unit == "distanceKm" && amount.unit == "minutes"
    let spokenFits = (unit == "durationMin" && amount.unit == "minutes")
      || (unit == "distanceKm" && amount.unit == "kilometers")
      || minutesOk
    if !spokenFits {
      let label = unit == "distanceKm" ? "kmか分" : "分"
      return stop("\(speakName)は\(label)で指定してください")
    }
    let lifestyle = (activity["lifestyleIncluded"] as? Bool) == true
    if !lifestyle && (weightKg() == nil || (weightKg() ?? 0) <= 0) {
      return stop("体重が無いので登録できません")
    }
    let record = exerciseRecord(activity, parsed: amount)
    let burn = LockScreenMealStore.number(record["netKcal"])
    return Plan(
      spoken: "\(speakName)\(formatQuantity(amount))の運動でいいですね",
      asksConfirmation: true,
      record: record,
      records: [record],
      burnKcal: burn
    )
  }

  private static func confirmMealTemplate(_ template: [String: Any]) -> Plan {
    let items = template["items"] as? [[String: Any]] ?? []
    if items.isEmpty {
      return stop("テンプレートの中身がありません")
    }
    let speakName = template["speakName"] as? String ?? ""
    var records: [[String: Any]] = []
    for item in items {
      let amount = (item["consumedAmount"] as? NSNumber)?.doubleValue ?? 0
      if amount <= 0 { continue }
      records.append(foodRecord(item, amount: amount))
    }
    if records.isEmpty {
      return stop("テンプレートの中身がありません")
    }
    return Plan(
      spoken: "\(speakName)のテンプレートでいいですね",
      asksConfirmation: true,
      record: records[0],
      records: records,
      intakeKcal: LockScreenMealStore.foodKcal(records)
    )
  }

  private static func confirmWorkoutTemplate(_ template: [String: Any]) -> Plan {
    let items = template["exercises"] as? [[String: Any]] ?? []
    let speakName = template["speakName"] as? String ?? ""
    var records: [[String: Any]] = []
    var burn = 0.0
    for item in items {
      let activityId = item["activityId"] as? String ?? ""
      guard let activity = activities().first(where: { $0["id"] as? String == activityId }) else {
        continue
      }
      let kilometers = (item["kilometers"] as? NSNumber)?.doubleValue ?? 0
      let minutes = (item["minutes"] as? NSNumber)?.doubleValue ?? 0
      let parsed: ParsedQuantity?
      if kilometers > 0 {
        parsed = ParsedQuantity(amount: kilometers, unit: "kilometers")
      } else if minutes > 0 {
        parsed = ParsedQuantity(amount: minutes, unit: "minutes")
      } else {
        parsed = nil
      }
      guard let parsed else { continue }
      let lifestyle = (activity["lifestyleIncluded"] as? Bool) == true
      if !lifestyle && (weightKg() == nil || (weightKg() ?? 0) <= 0) {
        return stop("体重が無いので登録できません")
      }
      let record = exerciseRecord(activity, parsed: parsed)
      burn += LockScreenMealStore.number(record["netKcal"])
      records.append(record)
    }
    if records.isEmpty {
      return stop("テンプレートの中身がありません")
    }
    return Plan(
      spoken: "\(speakName)のテンプレートでいいですね",
      asksConfirmation: true,
      record: records[0],
      records: records,
      burnKcal: burn
    )
  }

  @available(iOS 16.0, *)
  static func resolveChoice(_ plan: Plan, id: String) async -> Plan {
    guard plan.asksChoice,
          let choice = plan.choices.first(where: { $0["id"] as? String == id }),
          let kind = choice["kind"] as? String
    else {
      return plan
    }
    let quantity = plan.pendingQuantity ?? ""
    let parsed = parseQuantity(quantity)
    if kind == "mealTemplate" {
      if let template = mealTemplates().first(where: { $0["id"] as? String == id }) {
        return confirmMealTemplate(template)
      }
    }
    if kind == "workoutTemplate" {
      if let template = workoutTemplates().first(where: { $0["id"] as? String == id }) {
        return confirmWorkoutTemplate(template)
      }
    }
    if kind == "exercise" {
      if let activity = activities().first(where: { $0["id"] as? String == id }) {
        return confirmExercise(activity, quantityText: quantity, parsed: parsed, assumeMinutes: false)
      }
    }
    if let food = foods().first(where: { $0["id"] as? String == id }) {
      return confirmFood(food, quantityText: quantity, parsed: parsed, assumeUnit: false)
    }
    let pool = await rankFoods(plan.pendingName ?? "")
    if let food = pool.first(where: { $0["id"] as? String == id }) {
      return confirmFood(food, quantityText: quantity, parsed: parsed, assumeUnit: false)
    }
    return rescue(plan.pendingName ?? "")
  }

  static func resolveAmount(_ plan: Plan, text: String) -> Plan {
    guard plan.asksAmount, let stored = plan.record else {
      return plan
    }
    if stored["items"] != nil {
      return confirmMealTemplate(stored)
    }
    if stored["activityId"] != nil || stored["unit"] as? String == "durationMin" || stored["unit"] as? String == "distanceKm" {
      if stored["speakName"] != nil && stored["source"] == nil {
        return confirmExercise(stored, quantityText: text, parsed: nil, assumeMinutes: true)
      }
    }
    return confirmFood(stored, quantityText: text, parsed: nil, assumeUnit: true)
  }

  private static func choicePlan(
    name: String,
    quantityText: String,
    choices: [[String: Any]]
  ) -> Plan {
    let titles = choices.compactMap { $0["title"] as? String }.joined(separator: "、")
    return Plan(
      spoken: "\(name)は次のどれですか。\(titles)",
      asksConfirmation: false,
      asksChoice: true,
      choices: choices,
      pendingName: name,
      pendingQuantity: quantityText
    )
  }

  private static func rescue(_ name: String, kind: String = "food") -> Plan {
    let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let spokenName = label.isEmpty ? "それ" : label
    return Plan(
      spoken: "\(spokenName)は見つかりません。もう一度言うか、アプリで検索します",
      asksConfirmation: false,
      asksRetry: true,
      pendingName: spokenName,
      searchQuery: spokenName,
      searchKind: kind
    )
  }

  private static func choice(_ hit: [String: Any], kind: String, suffix: String) -> [String: Any] {
    let title = (hit["speakName"] as? String ?? "") + suffix
    return [
      "id": hit["id"] as? String ?? "",
      "title": title,
      "kind": kind,
    ]
  }

  private static func isObvious(_ hits: [[String: Any]]) -> Bool {
    if hits.count <= 1 {
      return !hits.isEmpty
    }
    let top = hits[0]
    let next = hits[1]
    let topRank = jsonInt(top["matchRank"]) ?? 9
    let nextRank = jsonInt(next["matchRank"]) ?? 9
    if topRank < nextRank {
      return true
    }
    let topCandidate = jsonBool(top["isCandidate"])
    let nextCandidate = jsonBool(next["isCandidate"])
    return !topCandidate && nextCandidate && topRank == nextRank
  }

  private static func rankFoods(_ name: String) async -> [[String: Any]] {
    let saved = foods().filter { $0["source"] as? String == "saved_food" }
    let savedHits = rankLocalFoods(saved, name: name)
    if !savedHits.isEmpty {
      return savedHits
    }
    let localOfficial = rankLocalFoods(
      foods().filter { $0["source"] as? String == "mext_sfct" },
      name: name
    )
    if !localOfficial.isEmpty {
      return localOfficial
    }
    return await officialFoods(query: name)
  }

  private static func rankLocalFoods(_ rows: [[String: Any]], name: String) -> [[String: Any]] {
    var hits: [[String: Any]] = []
    for row in rows {
      let keys = row["keys"] as? [String] ?? []
      let rank = bestRank(keys, name: name)
      if rank >= 9 { continue }
      var hit = row
      hit["matchRank"] = rank
      hit["isCandidate"] = jsonBool(row["isCandidate"])
      hit["candidateRank"] = jsonInt(row["candidateRank"]) ?? 100
      hit["priority"] = jsonInt(row["priority"]) ?? 100
      hit["aliasMatched"] = rank == 0
      hits.append(hit)
    }
    return hits.sorted(by: hitPrecedes)
  }

  private static func rankExercises(_ name: String) -> [[String: Any]] {
    if let id = spokenExerciseId(name),
       let activity = activities().first(where: { $0["id"] as? String == id }) {
      var hit = activity
      hit["matchRank"] = 0
      hit["isCandidate"] = false
      return [hit]
    }
    var hits: [[String: Any]] = []
    for activity in activities() {
      let keys = activity["keys"] as? [String] ?? []
      let rank = bestRank(keys, name: name)
      if rank >= 9 { continue }
      var hit = activity
      hit["matchRank"] = rank
      hit["isCandidate"] = false
      hits.append(hit)
    }
    return hits.sorted(by: hitPrecedes)
  }

  private static func rankTemplates(_ rows: [[String: Any]], name: String) -> [[String: Any]] {
    var hits: [[String: Any]] = []
    for row in rows {
      let keys = row["keys"] as? [String] ?? []
      let rank = bestRank(keys, name: name)
      if rank >= 9 { continue }
      var hit = row
      hit["matchRank"] = rank
      hit["isCandidate"] = false
      hits.append(hit)
    }
    return hits.sorted(by: hitPrecedes)
  }

  private static func bestRank(_ keys: [String], name: String) -> Int {
    var best = 9
    for variant in queryVariants(name) {
      for key in keys {
        let rank = textRank(haystack: key, needle: variant)
        if rank < best { best = rank }
      }
    }
    return best
  }

  private static func textRank(haystack: String, needle: String) -> Int {
    if haystack.isEmpty || needle.isEmpty { return 9 }
    if haystack == needle { return 0 }
    if needle.count < 3 { return 9 }
    if haystack.hasPrefix(needle) { return 1 }
    if haystack.contains(needle) { return 2 }
    return 9
  }

  private static func queryVariants(_ raw: String) -> [String] {
    let primary = normalize(raw)
    if primary.isEmpty { return [] }
    let stripped = primary.replacingOccurrences(
      of: "[をのはがにとでも]",
      with: "",
      options: .regularExpression
    )
    if stripped.isEmpty || stripped == primary { return [primary] }
    return [primary, stripped]
  }

  /// Dart の `spokenExerciseActivityIds` と同じ。キーは正規化後。
  private static func spokenExerciseId(_ raw: String) -> String? {
    let map = [
      "さんぽ": "walk_brisk",
      "散歩": "walk_brisk",
      "うぉきんぐ": "walk_brisk",
      "うぉく": "walk_brisk",
      "歩き": "walk_brisk",
      "あるき": "walk_brisk",
      "歩く": "walk_brisk",
      "あるく": "walk_brisk",
      "じょぎんぐ": "jogging",
      "じょぐ": "jogging",
      "らんにんぐ": "running",
      "らん": "running",
      "走り": "running",
      "はしり": "running",
      "筋トレ": "weight_training",
      "きんとれ": "weight_training",
      "自転車": "cycle_road",
      "じてんしゃ": "cycle_road",
      "ちゃり": "cycle_road",
    ]
    for variant in queryVariants(raw) {
      if let id = map[variant] { return id }
    }
    return nil
  }

  private static func hitPrecedes(_ a: [String: Any], _ b: [String: Any]) -> Bool {
    let rankA = jsonInt(a["matchRank"]) ?? 9
    let rankB = jsonInt(b["matchRank"]) ?? 9
    if rankA != rankB { return rankA < rankB }
    let candA = jsonBool(a["isCandidate"]) ? 1 : 0
    let candB = jsonBool(b["isCandidate"]) ? 1 : 0
    if candA != candB { return candA < candB }
    let orderA = jsonInt(a["candidateRank"]) ?? 100
    let orderB = jsonInt(b["candidateRank"]) ?? 100
    if orderA != orderB { return orderA < orderB }
    let aliasA = jsonBool(a["aliasMatched"]) ? 0 : 1
    let aliasB = jsonBool(b["aliasMatched"]) ? 0 : 1
    if aliasA != aliasB { return aliasA < aliasB }
    let priA = jsonInt(a["priority"]) ?? 100
    let priB = jsonInt(b["priority"]) ?? 100
    if priA != priB { return priA < priB }
    if let sqlA = jsonInt(a["sqlOrder"]), let sqlB = jsonInt(b["sqlOrder"]), sqlA != sqlB {
      return sqlA < sqlB
    }
    let idA = a["id"] as? String ?? ""
    let idB = b["id"] as? String ?? ""
    return idA < idB
  }

  private static func preferHit(_ candidate: [String: Any], _ current: [String: Any]) -> [String: Any] {
    hitPrecedes(candidate, current) ? candidate : current
  }

  private static func mealTemplates() -> [[String: Any]] {
    catalog()["mealTemplates"] as? [[String: Any]] ?? []
  }

  private static func workoutTemplates() -> [[String: Any]] {
    catalog()["workoutTemplates"] as? [[String: Any]] ?? []
  }

  private static func foodAmountQuestion(_ unit: String) -> String {
    switch unit {
    case "ml": return "何mlですか？"
    case "piece": return "何個ですか？"
    case "serving": return "何食分ですか？"
    default: return "何gですか？"
    }
  }

  private static func foodUnitSuffix(_ unit: String) -> String {
    switch unit {
    case "ml": return "ml"
    case "piece": return "個"
    case "serving": return "食"
    default: return "g"
    }
  }

  private static let vagueWords = [
    "大盛り", "おおもり", "大盛", "少なめ", "すくなめ", "半分", "はんぶん",
    "普通", "ふつう", "多め", "おおめ", "一杯", "いっぱい", "カップ", "かっぷ",
    "パック", "ぱっく", "袋", "皿", "さら", "杯", "膳", "人前",
    "ちょっと", "少し", "すこし", "軽く", "かるく", "しました", "やった", "やって", "した",
  ]

  private static func splitVagueTail(_ raw: String) -> (name: String, quantity: String)? {
    var compact = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
    if let trailing = try? NSRegularExpression(pattern: #"[。．.！!？?]+$"#) {
      let range = NSRange(compact.startIndex..., in: compact)
      compact = trailing.stringByReplacingMatches(in: compact, range: range, withTemplate: "")
    }
    let words = vagueWords.sorted { $0.count > $1.count }
    for word in words {
      if let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\(NSRegularExpression.escapedPattern(for: word))$"),
         let found = regex.firstMatch(in: compact, range: NSRange(compact.startIndex..., in: compact)),
         let range = Range(found.range, in: compact),
         range.lowerBound > compact.startIndex {
        return (String(compact[..<range.lowerBound]), String(compact[range]))
      }
      if compact.hasSuffix(word), compact.count > word.count {
        return (String(compact.dropLast(word.count)), word)
      }
    }
    return nil
  }

  static func rememberSearch(kind: String, query: String) {
    let payload: [String: String] = ["kind": kind, "query": query]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let raw = String(data: data, encoding: .utf8)
    else {
      return
    }
    defaults?.set(raw, forKey: openSearchKey)
    defaults?.set(true, forKey: continueSearchKey)
  }

  static func readOpenSearch() -> String {
    defaults?.string(forKey: openSearchKey) ?? ""
  }

  static func clearOpenSearch() {
    defaults?.removeObject(forKey: openSearchKey)
  }

  static func consumeContinueSearch() -> Bool {
    let armed = defaults?.bool(forKey: continueSearchKey) ?? false
    if armed {
      defaults?.set(false, forKey: continueSearchKey)
    }
    return armed
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

/// 話した通りの文字列を受け取る。候補の一覧は持たず、言葉そのものを返す。
@available(iOS 16.0, *)
struct SiriSpokenText: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "内容")
  static var defaultQuery = SiriSpokenTextQuery()

  var id: String
  var text: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: LocalizedStringResource(stringLiteral: text))
  }
}

@available(iOS 16.0, *)
struct SiriSpokenTextQuery: EntityStringQuery {
  func entities(for identifiers: [SiriSpokenText.ID]) async throws -> [SiriSpokenText] {
    identifiers.map { SiriSpokenText(id: $0, text: $0) }
  }

  func entities(matching string: String) async throws -> [SiriSpokenText] {
    let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return [] }
    return [SiriSpokenText(id: text, text: text)]
  }

  func suggestedEntities() async throws -> [SiriSpokenText] {
    []
  }
}

@available(iOS 17.0, *)
struct LogSpokenFoodIntent: AppIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "食事を登録"
  static var description = IntentDescription("食品名と量を復唱し、はいのときだけ今日の食事に1件登録します。")
  static var openAppWhenRun = false

  /// フレーズに置けるパラメータはこれだけ。食品名と量はこの言葉から分ける。
  /// パラメータなしの言い方では空のまま始まるので、空なら聞き返してから名寄せへ渡す。
  @Parameter(
    title: "食品",
    requestValueDialog: IntentDialog(stringLiteral: "何を食べましたか？")
  )
  var foodName: SiriSpokenText

  /// 言葉から食事か運動かが決まらないときだけ選ばせる。未指定のまま始め、先に聞かない。
  @Parameter(title: "種類")
  var kind: SiriSpokenKind?

  @Parameter(title: "候補")
  var choice: SiriChoiceEntity?

  @Parameter(title: "量")
  var amountReply: String?

  @Parameter(title: "言い直し")
  var retryReply: String?

  init() {
    self.foodName = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    if SiriVoiceStore.consumeContinueSearch() {
      return .result(dialog: "アプリで検索します")
    }
    let spoken = try promptedFoodName()
    var plan = await SiriVoiceStore.planFood(name: spoken, quantity: "")
    var retried = false
    while true {
      if plan.asksKind {
        let picked = try await $kind.requestDisambiguation(
          among: SiriSpokenKind.allCases,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveKind(plan, kind: picked)
      }
      if plan.asksChoice {
        let options = SiriChoiceEntity.list(plan.choices)
        guard !options.isEmpty else {
          return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
        }
        let picked = try await $choice.requestDisambiguation(
          among: options,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
      }
      if plan.asksAmount {
        let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = SiriVoiceStore.resolveAmount(plan, text: text)
      }
      if plan.asksRetry {
        if retried {
          SiriVoiceStore.rememberSearch(kind: "food", query: plan.searchQuery ?? spoken)
          throw needsToContinueInForegroundError()
        }
        retried = true
        let again = try await $retryReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = await SiriVoiceStore.planFood(name: again, quantity: "")
        continue
      }
      break
    }
    guard plan.asksConfirmation, !plan.records.isEmpty else {
      return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    }
    try await requestConfirmation(
      result: .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    )
    SiriVoiceStore.commitAll(plan.records)
    return .result(dialog: "登録しました")
  }

  /// 言い方に食品が無いときだけ聞く。入っていればそのまま名寄せへ渡す。
  /// init の空文字は値として残るので、requestValue ではなく聞き直してからやり直す。
  private func promptedFoodName() throws -> String {
    let current = foodName.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !current.isEmpty {
      return current
    }
    throw $foodName.needsValueError(IntentDialog(stringLiteral: "何を食べましたか？"))
  }
}

@available(iOS 17.0, *)
struct LogSpokenExerciseIntent: AppIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "運動を登録"
  static var description = IntentDescription("種目と量を復唱し、はいのときだけ今日の運動に1件登録します。")
  static var openAppWhenRun = false

  /// フレーズに置けるパラメータはこれだけ。種目と量はこの言葉から分ける。
  /// パラメータなしの言い方では空のまま始まるので、空なら聞き返してから名寄せへ渡す。
  @Parameter(
    title: "種目",
    requestValueDialog: IntentDialog(stringLiteral: "何をしましたか？")
  )
  var activityName: SiriSpokenText

  /// 言葉から食事か運動かが決まらないときだけ選ばせる。未指定のまま始め、先に聞かない。
  @Parameter(title: "種類")
  var kind: SiriSpokenKind?

  @Parameter(title: "候補")
  var choice: SiriChoiceEntity?

  @Parameter(title: "量")
  var amountReply: String?

  @Parameter(title: "言い直し")
  var retryReply: String?

  init() {
    self.activityName = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    if SiriVoiceStore.consumeContinueSearch() {
      return .result(dialog: "アプリで検索します")
    }
    let spoken = try promptedActivityName()
    var plan = await SiriVoiceStore.planExercise(name: spoken, quantity: "")
    var retried = false
    while true {
    if plan.asksKind {
      let picked = try await $kind.requestDisambiguation(
        among: SiriSpokenKind.allCases,
        dialog: IntentDialog(stringLiteral: plan.spoken)
      )
      plan = await SiriVoiceStore.resolveKind(plan, kind: picked)
    }
    if plan.asksChoice {
      let options = SiriChoiceEntity.list(plan.choices)
      let picked = try await $choice.requestDisambiguation(
        among: options,
        dialog: IntentDialog(stringLiteral: plan.spoken)
      )
      plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
    }
    if plan.asksAmount {
      let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
      plan = SiriVoiceStore.resolveAmount(plan, text: text)
    }
    if plan.asksRetry {
      if retried {
        SiriVoiceStore.rememberSearch(
          kind: "exercise",
          query: plan.searchQuery ?? spoken
        )
        throw needsToContinueInForegroundError()
      }
      retried = true
      let again = try await $retryReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
      plan = await SiriVoiceStore.planExercise(name: again, quantity: "")
      continue
    }
    break
    }
    guard plan.asksConfirmation, !plan.records.isEmpty else {
      return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    }
    try await requestConfirmation(
      result: .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    )
    SiriVoiceStore.commitAll(plan.records)
    return .result(dialog: "登録しました")
  }

  /// 言い方に種目が無いときだけ聞く。入っていればそのまま名寄せへ渡す。
  /// init の空文字は値として残るので、requestValue ではなく聞き直してからやり直す。
  private func promptedActivityName() throws -> String {
    let current = activityName.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !current.isEmpty {
      return current
    }
    throw $activityName.needsValueError(IntentDialog(stringLiteral: "何をしましたか？"))
  }
}

@available(iOS 17.0, *)
struct LogSpokenEntryIntent: AppIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "食事か運動を登録"
  static var description = IntentDescription("話した内容が食事か運動かを判別し、復唱してはいのときだけ1件登録します。")
  static var openAppWhenRun = false

  /// フレーズに置けるパラメータはこれだけ。
  /// 「カロナビに登録」など値の無い言い方では空のまま。種類を聞いてから自由文を聞く。
  @Parameter(title: "内容")
  var utterance: SiriSpokenText

  /// 言葉から食事か運動かが決まらないときだけ選ばせる。未指定のまま始め、先に聞かない。
  @Parameter(title: "種類")
  var kind: SiriSpokenKind?

  @Parameter(title: "候補")
  var choice: SiriChoiceEntity?

  @Parameter(title: "量")
  var amountReply: String?

  @Parameter(title: "言い直し")
  var retryReply: String?

  /// 「カロナビに登録」で種類のあとに聞く自由文。未指定のまま始め、先に聞かない。
  @Parameter(title: "答え")
  var entryReply: String?

  init() {
    self.utterance = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    if SiriVoiceStore.consumeContinueSearch() {
      return .result(dialog: "アプリで検索します")
    }
    let routed = try await routedEntry()
    let spoken = routed.text
    let forced = routed.kind
    var plan = routed.plan
    var retried = false
    while true {
      if plan.asksKind {
        let picked = try await $kind.requestDisambiguation(
          among: SiriSpokenKind.allCases,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveKind(plan, kind: picked)
      }
      if plan.asksChoice {
        let options = SiriChoiceEntity.list(plan.choices)
        guard !options.isEmpty else {
          return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
        }
        let picked = try await $choice.requestDisambiguation(
          among: options,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
      }
      if plan.asksAmount {
        let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = SiriVoiceStore.resolveAmount(plan, text: text)
      }
      if plan.asksRetry {
        if retried {
          SiriVoiceStore.rememberSearch(
            kind: plan.searchKind,
            query: plan.searchQuery ?? spoken
          )
          throw needsToContinueInForegroundError()
        }
        retried = true
        let again = try await $retryReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        if forced == .meal {
          plan = await SiriVoiceStore.planFood(name: again, quantity: "")
        } else if forced == .exercise {
          plan = await SiriVoiceStore.planExercise(name: again, quantity: "")
        } else {
          plan = await SiriVoiceStore.planUtterance(name: again, quantity: "")
        }
        continue
      }
      break
    }
    guard plan.asksConfirmation, !plan.records.isEmpty else {
      return .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    }
    try await requestConfirmation(
      result: .result(dialog: IntentDialog(stringLiteral: plan.spoken))
    )
    SiriVoiceStore.commitAll(plan.records)
    return .result(dialog: "登録しました")
  }

  /// 値のある言い方はその言葉を名寄せへ渡す。
  /// 値の無い「カロナビに登録」は、食事か運動かを聞いてから食品か種目を聞く。
  private func routedEntry() async throws -> (
    text: String,
    kind: SiriSpokenKind?,
    plan: SiriVoiceStore.Plan
  ) {
    let current = utterance.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !current.isEmpty {
      if kind == .meal {
        return (current, kind, await SiriVoiceStore.planFood(name: current, quantity: ""))
      }
      if kind == .exercise {
        return (current, kind, await SiriVoiceStore.planExercise(name: current, quantity: ""))
      }
      return (current, nil, await SiriVoiceStore.planUtterance(name: current, quantity: ""))
    }
    let picked: SiriSpokenKind
    if let kind {
      picked = kind
    } else {
      picked = try await $kind.requestDisambiguation(
        among: SiriSpokenKind.allCases,
        dialog: IntentDialog(stringLiteral: "食事ですか、運動ですか？")
      )
    }
    let text: String
    if picked == .meal {
      text = try await $entryReply.requestValue(IntentDialog(stringLiteral: "何を食べましたか？"))
      return (text, picked, await SiriVoiceStore.planFood(name: text, quantity: ""))
    }
    text = try await $entryReply.requestValue(IntentDialog(stringLiteral: "何をしましたか？"))
    return (text, picked, await SiriVoiceStore.planExercise(name: text, quantity: ""))
  }
}

@available(iOS 16.0, *)
struct SiriChoiceEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "候補")
  static var defaultQuery = SiriChoiceQuery()

  var id: String
  var title: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
  }

  static func list(_ rows: [[String: Any]]) -> [SiriChoiceEntity] {
    rows.compactMap { row in
      guard let id = row["id"] as? String, !id.isEmpty else { return nil }
      let title = row["title"] as? String ?? id
      return SiriChoiceEntity(id: id, title: title)
    }
  }
}

@available(iOS 16.0, *)
struct SiriChoiceQuery: EntityStringQuery {
  func entities(for identifiers: [SiriChoiceEntity.ID]) async throws -> [SiriChoiceEntity] {
    identifiers.map { SiriChoiceEntity(id: $0, title: $0) }
  }

  func entities(matching string: String) async throws -> [SiriChoiceEntity] {
    let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return [] }
    return [SiriChoiceEntity(id: text, title: text)]
  }

  func suggestedEntities() async throws -> [SiriChoiceEntity] {
    []
  }
}

@available(iOS 16.0, *)
enum SiriSpokenKind: String, AppEnum {
  case meal
  case exercise

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "種類")

  static var caseDisplayRepresentations: [SiriSpokenKind: DisplayRepresentation] = [
    .meal: DisplayRepresentation(title: "食事"),
    .exercise: DisplayRepresentation(title: "運動"),
  ]
}

@available(iOS 17.0, *)
struct CalonaviSiriShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogSpokenFoodIntent(),
      phrases: [
        "\(.applicationName)で食事を記録",
        "\(.applicationName)で食事を登録",
        "\(.applicationName)で、食事に\(\.$foodName)",
      ],
      shortTitle: "食事を登録",
      systemImageName: "fork.knife"
    )
    AppShortcut(
      intent: LogSpokenExerciseIntent(),
      phrases: [
        "\(.applicationName)で運動を記録",
        "\(.applicationName)で運動を登録",
        "\(.applicationName)で、運動に\(\.$activityName)",
      ],
      shortTitle: "運動を登録",
      systemImageName: "figure.run"
    )
    AppShortcut(
      intent: LogSpokenEntryIntent(),
      phrases: [
        "\(.applicationName)に登録",
        "\(.applicationName)で登録",
        "\(.applicationName)で記録",
        "\(.applicationName)で \(\.$utterance)",
      ],
      shortTitle: "食事か運動を登録",
      systemImageName: "mic"
    )
  }
}
