import AppIntents
import Foundation

/// 食事と運動を登録し、何をどれだけ登録したかを読み上げる。
///
/// 決まった始まりは「Hey Siri、カロナビで」。食事か運動かは言葉から判別する。
/// 名寄せの自信が高いときは確認せず登録し、「ささみ100gを登録しました」と読む。
/// 自信が低いときだけ「でいいですね」と確認してから登録する。
/// 「さっきの登録を取り消して」で、直前の1件を取り消す。
/// どちらとも取れない言葉は、食事か運動かを確認する。
/// 「Hey Siri、カロナビに登録」では、先に食事か運動かを聞き、そのあと食品か種目を聞く。
/// 「カロナビで登録」「カロナビで記録」も同じ。答えた自由文は今までの名寄せへ渡す。
/// 「Hey Siri、カロナビで、食事にささみを300グラム。」
/// 「Hey Siri、カロナビで、運動にジョギングを30分。」
/// 食事だけの言い方と運動だけの言い方も残す。フレーズのパラメータは1つだけ、型は AppEntity。
/// 食品名と量は、その1つの言葉から今までどおり分ける。
///
/// 確認が必要なときだけ「いいえ」や無言で書かない。自信が高いときは、その場で書く。
/// 食事と運動のテンプレート名でも登録する。未課金は登録しない。公開食品は扱わない。
/// `openAppWhenRun` は false。判定と書き込みは App Group だけで、アプリが閉じていても Siri が実行する。
/// 名寄せの順は Dart の `pickSiriMatches` と同じ。同じ食品の生・ゆでは聞かず代表にする。部位や種類が分かれて長いときだけ聞き返す。2〜3件の別食品は読み上げる。0件は言い直したあと、検索語を残してアプリを開く。
/// ショートカットのアイコンは後で差し替える。今はプレースホルダー。
enum SiriVoiceStore {
  static let catalogKey = "siriVoiceCatalog"
  static let pendingKey = "siriVoicePending"
  static let openSearchKey = "siriVoiceOpenSearch"
  static let continueSearchKey = "siriVoiceContinueSearch"
  static let lastCommitKey = "siriVoiceLastCommit"

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
  var asksNarrow: Bool = false
  var narrowRound: Int = 0
  var narrowAnimal: String?
  var narrowCut: String?
  var narrowCook: String?
  var narrowKind: String?
  var narrowQuery: String?
  var narrowFoods: [[String: Any]] = []
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
    var confident: Bool = false
    var label: String = ""
  }

  enum CommitStep {
    case speak(String)
    case confirm(dialog: String, report: String)
  }

  /// 自信が高いときはここで書く。確認が要るときは、はいのあとに `commitConfirmed` する。
  static func commitStep(_ plan: Plan) -> CommitStep {
    if plan.asksConfirmation && !plan.records.isEmpty {
      let report = plan.label.isEmpty ? "登録しました" : registeredSpeech(plan.label)
      return .confirm(dialog: plan.spoken, report: report)
    }
    if plan.confident && !plan.records.isEmpty {
      commitAll(plan.records)
      rememberLast(plan)
      SiriAnalytics.finished(status: "registered", stopReason: "committed", itemsCount: plan.records.count)
      return .speak(plan.spoken)
    }
    return .speak(plan.spoken)
  }

  static func commitConfirmed(_ plan: Plan) {
    commitAll(plan.records)
    rememberLast(plan)
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
    if undoUtterance(source) {
      return undoLast()
    }
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
    let savedHits = rankLocalFoods(
      foods().filter { $0["source"] as? String == "saved_food" },
      name: name
    )
    let templateHits = rankTemplates(mealTemplates(), name: name)
    let templates: [[String: Any]]
    let foods: [[String: Any]]
    if !savedHits.isEmpty {
      templates = []
      foods = savedHits
    } else if !templateHits.isEmpty {
      templates = templateHits
      foods = []
    } else {
      templates = []
      foods = await rankUnsavedFoods(name)
    }
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
    if foods.count > 1 {
      let traits = utteranceTraits(name)
      if !isObvious(foods) || traitsConflict(foods[0], traits) {
        return presentFoods(
          foods,
          name: name,
          quantityText: quantityText,
          traits: traits,
          rounds: 0,
          query: foodSearchQuery(name, traits)
        )
      }
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
      return stop(
        "こちらはカロナビ+の機能です",
        status: "blocked",
        reason: "unpaid"
      )
    }
    if ownerUserId().isEmpty {
      return stop("ログインしてください", status: "blocked", reason: "signed_out")
    }
    return nil
  }

  private static func stop(
    _ spoken: String,
    status: String = "stopped",
    reason: String = "other"
  ) -> Plan {
    SiriAnalytics.finished(status: status, stopReason: reason)
    return Plan(spoken: spoken, asksConfirmation: false, record: nil)
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

  /// nil は通信失敗。空配列は、検索はできたが該当が無い。
  private static func officialFoodRows(query: String) async -> [[String: Any]]? {
    guard let url = rpcURL("search_official_foods") else {
      return []
    }
    return await postRpc(url, body: [
      "p_query": String(query.prefix(64)),
      "p_limit": 30,
    ], bearer: anonBearer())
  }

  private static func publicFoodRows(query: String) async -> [[String: Any]]? {
    guard let url = rpcURL("search_public_foods") else {
      return []
    }
    let token = (catalog()["supabaseAccessToken"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if token.isEmpty {
      return []
    }
    return await postRpc(url, body: [
      "p_query": String(query.prefix(64)),
      "p_limit": 30,
    ], bearer: token)
  }

  private static func rpcURL(_ name: String) -> URL? {
    let json = catalog()
    guard json["officialFoodsEnabled"] as? Bool == true,
          let base = json["supabaseUrl"] as? String, !base.isEmpty,
          catalog()["supabaseAnonKey"] as? String != nil
    else {
      return nil
    }
    return URL(string: "\(base)/rest/v1/rpc/\(name)")
  }

  private static func anonBearer() -> String {
    catalog()["supabaseAnonKey"] as? String ?? ""
  }

  private static func postRpc(
    _ url: URL,
    body: [String: Any],
    bearer: String
  ) async -> [[String: Any]]? {
    let apiKey = anonBearer()
    if apiKey.isEmpty || bearer.isEmpty {
      return []
    }
    var request = URLRequest(url: url, timeoutInterval: 8)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    guard
      let (data, response) = try? await URLSession.shared.data(for: request),
      let http = response as? HTTPURLResponse,
      http.statusCode == 200,
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return nil
    }
    return rows
  }

  /// 助詞を除いた言い方も成分表へ投げる。SQL の並びを sqlOrder で残す。
  /// 2文字以下は完全一致だけを残し、「ささ」で「ささみ」を採らない。
  private static func officialFoods(query: String) async -> [[String: Any]]? {
    var merged: [String: [String: Any]] = [:]
    var sequence = 0
    var sawFailure = false
    for variant in queryVariants(query) {
      guard let rows = await officialFoodRows(query: variant) else {
        sawFailure = true
        continue
      }
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
    if sawFailure && merged.isEmpty {
      return nil
    }
    return merged.values.sorted(by: hitPrecedes)
  }

  private static func publicFoods(query: String) async -> [[String: Any]]? {
    var merged: [String: [String: Any]] = [:]
    var sequence = 0
    var sawFailure = false
    for variant in queryVariants(query) {
      guard let rows = await publicFoodRows(query: variant) else {
        sawFailure = true
        continue
      }
      for row in rows {
        guard var food = publicFood(row), let id = food["id"] as? String else {
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
    if sawFailure && merged.isEmpty {
      return nil
    }
    return merged.values.sorted(by: hitPrecedes)
  }

  private static func publicFood(_ row: [String: Any]) -> [String: Any]? {
    let name = row["name"] as? String ?? ""
    let unit = (row["unit_type"] as? String ?? "g").lowercased()
    guard unit == "g" || unit == "ml" || unit == "piece" || unit == "serving" else {
      return nil
    }
    let foodId = row["food_id"] as? String ?? ""
    let owner = row["user_id"] as? String ?? ""
    if foodId.isEmpty || owner.isEmpty || name.isEmpty {
      return nil
    }
    var food: [String: Any] = [
      "id": "\(owner):\(foodId)",
      "speakName": name,
      "keys": [normalize(name)],
      "baseAmount": row["base_amount"] as? NSNumber ?? 100,
      "unit": unit,
      "source": "saved_food",
      "savedFoodId": foodId,
      "sourceOwnerUserId": owner,
      "matchRank": jsonInt(row["match_rank"]) ?? 9,
      "isCandidate": (jsonInt(row["match_rank"]) ?? 0) >= 3,
      "candidateRank": jsonInt(row["match_rank"]) ?? 100,
      "priority": 100,
      "aliasMatched": false,
    ]
    if let version = row["version"] as? NSNumber { food["version"] = version }
    if let kcal = row["kcal_per_base"] as? NSNumber { food["kcalPerBase"] = kcal }
    if let protein = row["protein_per_base"] as? NSNumber { food["proteinPerBase"] = protein }
    if let fat = row["fat_per_base"] as? NSNumber { food["fatPerBase"] = fat }
    if let carb = row["carb_per_base"] as? NSNumber { food["carbPerBase"] = carb }
    return food
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

  private static func registeredSpeech(_ label: String) -> String {
    "\(label)を登録しました"
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

  private static func undoUtterance(_ raw: String) -> Bool {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let punctuation = CharacterSet(charactersIn: " 。．.！!？?、,")
    text = String(text.unicodeScalars.filter { !punctuation.contains($0) })
    if text.hasPrefix("HeySiri") {
      text = String(text.dropFirst("HeySiri".count))
    } else if text.hasPrefix("heySiri") {
      text = String(text.dropFirst("heySiri".count))
    }
    if text.hasPrefix("カロナビで") {
      text = String(text.dropFirst("カロナビで".count))
    }
    if text.hasPrefix("食事に") {
      text = String(text.dropFirst("食事に".count))
    } else if text.hasPrefix("運動に") {
      text = String(text.dropFirst("運動に".count))
    }
    if text.hasSuffix("ください") {
      text = String(text.dropLast("ください".count))
    } else if text.hasSuffix("です") {
      text = String(text.dropLast("です".count))
    } else if text.hasSuffix("くれ") {
      text = String(text.dropLast("くれ".count))
    }
    let phrases: Set<String> = [
      "今登録したやつ消して",
      "今登録したやつくして",
      "今登録したもの消して",
      "今登録したものを消して",
      "さっきの登録を取り消して",
      "さっきの登録取り消して",
      "直前の登録を取り消して",
      "直前の登録取り消して",
      "今の登録を取り消して",
      "今の登録取り消して",
      "登録を取り消して",
      "登録取り消して",
      "取り消して",
      "取り消し",
      "元に戻して",
      "さっきの消して",
      "今の消して",
      "今登録したやつ削除して",
      "さっきの登録を削除して",
      "さっきの登録削除して",
    ]
    if phrases.contains(text) {
      return true
    }
    let removes = text.contains("取り消") || text.contains("消して") || text.contains("削除")
    let aboutLast = text.contains("登録") || text.contains("さっき") || text.contains("直前")
    return removes && aboutLast && text.count <= 24
  }

  private struct LastCommit {
    var ids: [String]
    var label: String
    var intake: Double
    var burn: Double
  }

  private static func readLastCommit() -> LastCommit? {
    guard
      let raw = defaults?.string(forKey: lastCommitKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    let ids = json["ids"] as? [String] ?? []
    let label = (json["label"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if ids.isEmpty || label.isEmpty {
      return nil
    }
    return LastCommit(
      ids: ids,
      label: label,
      intake: LockScreenMealStore.number(json["intakeKcal"]),
      burn: LockScreenMealStore.number(json["burnKcal"])
    )
  }

  private static func rememberLast(_ plan: Plan) {
    let ids = plan.records.compactMap { $0["id"] as? String }
    let label = plan.label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !ids.isEmpty, !label.isEmpty else { return }
    let payload: [String: Any] = [
      "ids": ids,
      "label": label,
      "intakeKcal": plan.intakeKcal,
      "burnKcal": plan.burnKcal,
    ]
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let raw = String(data: data, encoding: .utf8)
    else {
      return
    }
    defaults?.set(raw, forKey: lastCommitKey)
  }

  /// 直前の1件を消す。未取り込みなら待ち行列から除き、取り込み済みなら削除印を残す。
  private static func undoLast() -> Plan {
    guard let last = readLastCommit() else {
      SiriAnalytics.finished(status: "cancelled", stopReason: "nothing_to_undo")
      return Plan(spoken: "取り消す登録がありません", asksConfirmation: false)
    }
    var pending = readPendingArray()
    let idSet = Set(last.ids)
    pending.removeAll { record in
      guard let id = record["id"] as? String else { return false }
      return idSet.contains(id)
    }
    let owner = ownerUserId()
    let loggedAt = LockScreenMealStore.formatLoggedAt(Date())
    for target in last.ids {
      pending.append([
        "kind": "undo",
        "id": UUID().uuidString,
        "ownerUserId": owner,
        "targetId": target,
        "loggedAt": loggedAt,
      ])
    }
    guard JSONSerialization.isValidJSONObject(pending) else {
      return Plan(spoken: "取り消す登録がありません", asksConfirmation: false)
    }
    writePendingArray(pending)
    if last.intake != 0 || last.burn != 0 {
      LockScreenMealStore.applyFigures(intakeDelta: -last.intake, burnDelta: -last.burn)
    }
    defaults?.removeObject(forKey: lastCommitKey)
    SiriAnalytics.finished(status: "undo", stopReason: "undo")
    return Plan(
      spoken: "\(last.label)の登録を取り消しました",
      asksConfirmation: false
    )
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
      let saved = rankLocalFoods(
        foods().filter { $0["source"] as? String == "saved_food" },
        name: name
      )
      if !saved.isEmpty {
        consider(saved, choiceKind: "food", suffix: "")
      } else {
        let templates = rankTemplates(mealTemplates(), name: name)
        if !templates.isEmpty {
          consider(templates, choiceKind: "mealTemplate", suffix: "（テンプレート）")
        } else {
          consider(await rankUnsavedFoods(name), choiceKind: "food", suffix: "")
        }
      }
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
    assumeUnit: Bool,
    confident: Bool = true
  ) -> Plan {
    let speakName = food["speakName"] as? String ?? ""
    let unit = food["unit"] as? String ?? "g"
    let amount = parsed ?? (assumeUnit ? parseQuantity(quantityText + foodUnitSuffix(unit)) : nil)
    guard let amount else {
      return Plan(
        spoken: foodAmountQuestion(unit),
        asksConfirmation: false,
        asksAmount: true,
        confident: confident,
        record: food,
        pendingName: speakName,
        pendingQuantity: quantityText
      )
    }
    guard foodUnitFits(unit, spoken: amount.unit) else {
      return stop("\(speakName)は\(foodUnitLabel(unit))で指定してください")
    }
    let record = foodRecord(food, amount: amount.amount)
    let label = "\(speakName)\(formatQuantity(amount))"
    return Plan(
      spoken: confident ? registeredSpeech(label) : "\(label)の食事でいいですね",
      asksConfirmation: !confident,
      confident: confident,
      label: label,
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
    let label = "\(speakName)\(formatQuantity(amount))"
    return Plan(
      spoken: registeredSpeech(label),
      asksConfirmation: false,
      confident: true,
      label: label,
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
      spoken: registeredSpeech(speakName),
      asksConfirmation: false,
      confident: true,
      label: speakName,
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
      spoken: registeredSpeech(speakName),
      asksConfirmation: false,
      confident: true,
      label: speakName,
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
    return confirmFood(
      stored,
      quantityText: text,
      parsed: nil,
      assumeUnit: true,
      confident: plan.confident
    )
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
    SiriAnalytics.finished(status: "not_found", stopReason: "rescue")
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

  @available(iOS 16.0, *)
  static func resolveNarrow(_ plan: Plan, text: String) async -> Plan {
    guard plan.asksNarrow else { return plan }
    let reply = spokenFoodReply(text)
    if reply.cancel {
      return stop("登録しません")
    }
    let quantity = plan.pendingQuantity ?? ""
    let spokenName = plan.pendingName ?? ""
    if reply.unknown {
      let pool = plan.narrowFoods
      guard let food = representativeFood(pool, spokenKind: plan.narrowKind) else {
        return rescue(spokenName)
      }
      return confirmFood(
        food,
        quantityText: quantity,
        parsed: parseQuantity(quantity),
        assumeUnit: false,
        confident: false
      )
    }
    var traits = FoodTraits(
      animal: plan.narrowAnimal,
      cut: plan.narrowCut,
      cook: plan.narrowCook,
      kind: plan.narrowKind
    )
    traits = traits.merged(reply.traits)
    let query = foodSearchQuery(plan.narrowQuery ?? spokenName, traits)
    var pool = plan.narrowFoods
    if let fetched = await officialFoods(query: query), !fetched.isEmpty {
      pool = fetched
    } else {
      let stem = dropCookWords(query)
      if stem != query, let fetched = await officialFoods(query: stem), !fetched.isEmpty {
        pool = fetched
      }
    }
    return presentFoods(
      pool,
      name: spokenName,
      quantityText: quantity,
      traits: traits,
      rounds: plan.narrowRound,
      query: query
    )
  }

  private struct FoodTraits {
    var animal: String?
    var cut: String?
    var cook: String?
    var kind: String?

    func merged(_ newer: FoodTraits) -> FoodTraits {
      FoodTraits(
        animal: newer.animal ?? animal,
        cut: newer.cut ?? cut,
        cook: newer.cook ?? cook,
        kind: newer.kind ?? kind
      )
    }
  }

  private struct SpokenReply {
    var traits = FoodTraits()
    var cancel = false
    var unknown = false
  }

  private static func presentFoods(
    _ foods: [[String: Any]],
    name: String,
    quantityText: String,
    traits: FoodTraits,
    rounds: Int,
    query: String
  ) -> Plan {
    let pool = applyTraitFilters(foods, traits)
    if pool.isEmpty {
      return rescue(name, kind: "food")
    }
    let groups = identityGroups(pool)
    if pool.count == 1 || groups.count == 1 {
      guard let food = representativeFood(pool, spokenKind: traits.kind) else {
        return rescue(name, kind: "food")
      }
      return confirmFood(food, quantityText: quantityText, parsed: parseQuantity(quantityText), assumeUnit: false)
    }
    if pool.count <= 3 {
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: pool.map { choice($0, kind: "food", suffix: "") }
      )
    }
    let group = majorityGroup(pool)
    if groups.count <= 3 {
      let picks = groups.compactMap { representativeFood($0, spokenKind: traits.kind) }
      return choicePlan(
        name: name,
        quantityText: quantityText,
        choices: picks.map { choice($0, kind: "food", suffix: "") }
      )
    }
    let axis = nextFoodAxis(pool, traits, group)
    if axis == nil || rounds >= 3 {
      guard let food = representativeFood(pool, spokenKind: traits.kind) else {
        return rescue(name, kind: "food")
      }
      return confirmFood(
        food,
        quantityText: quantityText,
        parsed: parseQuantity(quantityText),
        assumeUnit: false,
        confident: false
      )
    }
    return Plan(
      spoken: foodQuestion(axis ?? "kind", group),
      asksConfirmation: false,
      asksNarrow: true,
      pendingName: name,
      pendingQuantity: quantityText,
      narrowRound: rounds + 1,
      narrowAnimal: traits.animal,
      narrowCut: traits.cut,
      narrowCook: traits.cook,
      narrowKind: traits.kind,
      narrowQuery: query,
      narrowFoods: pool
    )
  }

  private static func traitsConflict(_ food: [String: Any], _ traits: FoodTraits) -> Bool {
    let found = traitsOfFood(food)
    if let cook = traits.cook, found.cook != cook { return true }
    if let cut = traits.cut, found.cut != cut { return true }
    return false
  }

  private static func identityKey(_ food: [String: Any]) -> String {
    let traits = traitsOfFood(food)
    let code = food["officialFoodCode"] as? String ?? food["id"] as? String
    let group = code.flatMap { $0.count >= 2 ? String($0.prefix(2)) : nil }
    if let cut = traits.cut, group == "11" || traits.animal != nil {
      return "cut:\(traits.animal ?? ""):\(cut)"
    }
    return "core:\(coreFoodName(food["speakName"] as? String ?? ""))"
  }

  private static func coreFoodName(_ speakName: String) -> String {
    var text = speakName.replacingOccurrences(
      of: "（[^）]*）",
      with: "",
      options: .regularExpression
    )
    let drop = [
      "皮下脂肪なし", "脂身つき", "脂身", "皮なし", "皮つき", "赤肉",
      "乳用肥育牛", "輸入牛", "和牛", "若鶏", "若どり", "にわとり",
      "大型種肉", "中型種肉", "大型種", "中型種", "養殖", "副品目", "主品目", "結球葉",
      "から揚げ", "唐揚げ", "天ぷら", "てんぷら", "ソテー", "フライ", "水煮",
      "焼き", "ゆで", "茹で", "蒸し", "生",
    ]
    for word in drop {
      text = text.replacingOccurrences(of: word, with: "")
    }
    text = text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    return text.isEmpty ? speakName : text
  }

  private static func sameFoodFamily(_ a: String, _ b: String) -> Bool {
    if a == b { return true }
    if a.hasPrefix("cut:") || b.hasPrefix("cut:") { return false }
    let left = a.hasPrefix("core:") ? String(a.dropFirst(5)) : a
    let right = b.hasPrefix("core:") ? String(b.dropFirst(5)) : b
    if left.count < 2 || right.count < 2 { return false }
    return left.contains(right) || right.contains(left)
  }

  private static func identityGroups(_ foods: [[String: Any]]) -> [[[String: Any]]] {
    var keyed: [String: [[String: Any]]] = [:]
    var order: [String] = []
    for food in foods {
      let key = identityKey(food)
      if let matched = order.first(where: { sameFoodFamily($0, key) }) {
        keyed[matched, default: []].append(food)
      } else {
        order.append(key)
        keyed[key] = [food]
      }
    }
    return order.compactMap { keyed[$0] }
  }

  private static func nextFoodAxis(
    _ foods: [[String: Any]],
    _ traits: FoodTraits,
    _ group: String?
  ) -> String? {
    let animals = Set(foods.compactMap { traitsOfFood($0).animal })
    let cuts = Set(foods.compactMap { traitsOfFood($0).cut })
    if group == "11" || !animals.isEmpty {
      if animals.count >= 2 && traits.animal == nil { return "animal" }
      if cuts.count >= 2 && traits.cut == nil { return "cut" }
      return nil
    }
    if kindClusters(foods).count >= 2 && traits.kind == nil { return "kind" }
    return nil
  }

  private static func foodQuestion(_ axis: String, _ group: String?) -> String {
    switch axis {
    case "animal":
      return "牛、豚、鶏のどれですか？"
    case "cut":
      return "どの部位ですか？"
    case "kind":
      switch group {
      case "10": return "何の魚ですか？"
      case "06": return "何の野菜ですか？"
      case "07": return "何の果物ですか？"
      default: return "種類はどれですか？"
      }
    case "cook":
      if group == "06" || group == "07" { return "生かゆでですか？" }
      return "生、焼き、ゆで、揚げのどれですか？"
    default:
      return "どれにしますか？"
    }
  }

  private static func representativeFood(
    _ foods: [[String: Any]],
    spokenKind: String?
  ) -> [String: Any]? {
    guard !foods.isEmpty else { return nil }
    return foods.enumerated().min { left, right in
      let score = representativeScore(left.element, spokenKind: spokenKind)
        - representativeScore(right.element, spokenKind: spokenKind)
      if score != 0 { return score < 0 }
      return left.offset < right.offset
    }?.element
  }

  private static func representativeScore(_ food: [String: Any], spokenKind: String?) -> Int {
    let name = food["speakName"] as? String ?? ""
    var score = 0
    if name.contains("脂身（") { score += 40 }
    for word in ["新巻き", "塩ざけ", "塩さけ", "イクラ", "すじこ", "めふん", "削り節", "缶詰", "くん製", "スモーク"] {
      if name.contains(word) { score += 12 }
    }
    if name.contains("副品目") || name.contains("親・") || name.contains("（親") { score += 8 }
    if name.contains("輸入") || name.contains("乳用") { score += 6 }
    if name.contains("和牛") || name.contains("若鶏") || name.contains("若どり") { score -= 10 }
    if name.contains("皮なし") { score -= 2 }
    if name.contains("皮つき") { score += 2 }
    if let spokenKind, let kind = traitsOfFood(food).kind {
      let spoken = foldKana(normalize(spokenKind))
      let foodKind = foldKana(normalize(kind))
      if foodKind == spoken || kind == spokenKind {
        score -= 8
      } else if foodKind.contains(spoken) || kind.contains(spokenKind) {
        score += 4
      }
    }
    return score
  }

  private static func applyTraitFilters(
    _ foods: [[String: Any]],
    _ want: FoodTraits
  ) -> [[String: Any]] {
    var pool = foods
    if let animal = want.animal {
      let next = pool.filter { traitsOfFood($0).animal == animal }
      if !next.isEmpty { pool = next }
    }
    if let cut = want.cut {
      let next = pool.filter { cutMatches(traitsOfFood($0).cut, cut) }
      if !next.isEmpty { pool = next }
    }
    if let kind = want.kind {
      let next = pool.filter { kindMatches(traitsOfFood($0).kind, kind) }
      if !next.isEmpty { pool = next }
    }
    if let cook = want.cook {
      let next = pool.filter { traitsOfFood($0).cook == cook }
      if !next.isEmpty { pool = next }
    }
    return pool
  }

  private static func traitsOfFood(_ food: [String: Any]) -> FoodTraits {
    let speak = food["speakName"] as? String ?? ""
    let official = food["officialFoodName"] as? String ?? ""
    let code = food["officialFoodCode"] as? String ?? food["id"] as? String
    return traitsFromFoodName("\(speak) \(official)", foodCode: code)
  }

  private static func utteranceTraits(_ name: String) -> FoodTraits {
    let compact = compactFoodText(name)
    if compact.isEmpty || broadFoodWords.contains(compact) {
      return FoodTraits(animal: animalOf(compact, group: nil))
    }
    let animal = animalOf(compact, group: nil)
    let cook = cookOf(compact)
    let stripped = dropCookWords(compact)
    let cut = cutOf(stripped, allowThigh: animal != nil || ["もも", "腿", "モモ"].contains(stripped))
    return FoodTraits(
      animal: animal,
      cut: cut,
      cook: cook,
      kind: utteranceKind(compact, animal: animal, cut: cut)
    )
  }

  private static func spokenFoodReply(_ raw: String) -> SpokenReply {
    var compact = compactFoodText(raw)
    for suffix in ["です", "だよ", "だね", "かも", "かな", "やつ", "もの", "の"] {
      if compact.hasSuffix(suffix), compact.count > suffix.count {
        compact = String(compact.dropLast(suffix.count))
      }
    }
    if cancelFoodWords.contains(compact) {
      return SpokenReply(cancel: true)
    }
    if unknownFoodWords.contains(compact) {
      return SpokenReply(unknown: true)
    }
    let cook = cookOf(compact) ?? spokenCook(compact)
    let animal = animalOf(compact, group: nil) ?? spokenAnimal(compact)
    let cut = cutOf(compact, allowThigh: true)
    if animal != nil || cut != nil || cook != nil {
      return SpokenReply(traits: FoodTraits(animal: animal, cut: cut, cook: cook))
    }
    return SpokenReply(traits: FoodTraits(kind: compact))
  }

  private static func foodSearchQuery(_ original: String, _ traits: FoodTraits) -> String {
    if let animal = traits.animal, let cut = traits.cut,
       let animalWord = animalSearchWord[animal], let cutWord = cutSearchWord[cut] {
      return animalWord + cutWord
    }
    if let kind = traits.kind, traits.animal == nil {
      let compact = compactFoodText(original)
      if broadFoodWords.contains(compact) || !compact.contains(kind) {
        return kind
      }
    }
    let dropped = dropCookWords(original)
    return dropped.isEmpty ? compactFoodText(original) : dropped
  }

  private static func dropCookWords(_ raw: String) -> String {
    var text = compactFoodText(raw)
    let suffixes = [
      "のから揚げ", "から揚げ", "の唐揚げ", "唐揚げ", "の天ぷら", "天ぷら",
      "のてんぷら", "てんぷら", "のフライ", "フライ", "の揚げ", "揚げ",
      "のからあげ", "からあげ", "の焼き", "焼き", "焼いた", "の焼", "焼",
      "のやき", "やいた", "やき", "のゆで", "ゆでた", "ゆで", "の茹で", "茹で",
      "の水煮", "水煮", "の蒸し", "蒸し", "のむし", "むし", "のソテー", "ソテー",
      "の生", "生",
    ]
    var changed = true
    while changed {
      changed = false
      for suffix in suffixes where text.hasSuffix(suffix) && text.count > suffix.count {
        text = String(text.dropLast(suffix.count))
        changed = true
        break
      }
    }
    while text.hasSuffix("の"), text.count > 1 {
      text = String(text.dropLast(1))
    }
    return text
  }

  private static func traitsFromFoodName(_ name: String, foodCode: String?) -> FoodTraits {
    let group = foodCode.flatMap { $0.count >= 2 ? String($0.prefix(2)) : nil }
    let animal = animalOf(name, group: group)
    return FoodTraits(
      animal: animal,
      cut: cutOf(name, allowThigh: animal != nil || group == "11"),
      cook: cookOf(name),
      kind: kindOf(name)
    )
  }

  private static func animalOf(_ name: String, group: String?) -> String? {
    if hasAny(name, ["和牛", "牛肉", "うし", "牛", "ぎゅうにく", "ぎゅう"]) { return "beef" }
    if hasAny(name, ["豚肉", "ぶたにく", "ぶた", "豚"]) { return "pork" }
    if hasAny(name, ["鶏肉", "とりにく", "にわとり", "若鶏", "若どり", "わかどり", "鶏"]) {
      return "chicken"
    }
    if group == "11", hasAny(name, ["とり"]) { return "chicken" }
    return nil
  }

  private static func spokenAnimal(_ compact: String) -> String? {
    switch compact {
    case "牛", "牛肉", "ぎゅう", "ぎゅうにく": return "beef"
    case "豚", "豚肉", "ぶた", "ぶたにく": return "pork"
    case "鶏", "鶏肉", "とり", "とりにく", "チキン": return "chicken"
    default: return nil
    }
  }

  private static func cookOf(_ name: String) -> String? {
    let rules: [(String, [String])] = [
      ("fried", ["から揚げ", "からあげ", "唐揚げ", "唐揚", "天ぷら", "てんぷら", "フライ", "ふらい", "揚げ", "あげ"]),
      ("grilled", ["ソテー", "そて", "焼き", "焼", "やき", "やいた", "焼いた"]),
      ("boiled", ["水煮", "ゆで", "茹で", "ゆでた", "茹でた"]),
      ("steamed", ["蒸し", "むし", "蒸した"]),
      ("raw", ["生", "なま"]),
    ]
    let tokens = foodTokens(name)
    for rule in rules {
      for word in rule.1 where cookMarked(name, tokens, word) {
        return rule.0
      }
    }
    return nil
  }

  private static func spokenCook(_ compact: String) -> String? {
    if ["焼いた", "焼いて", "やいた", "やいて", "グリル", "ぐりる"].contains(compact) { return "grilled" }
    if ["ゆでた", "茹でた", "煮た", "にた"].contains(compact) { return "boiled" }
    if ["揚げた", "あげた", "からあげ", "から揚げた"].contains(compact) { return "fried" }
    if ["蒸した", "むした"].contains(compact) { return "steamed" }
    if ["生で", "なまで"].contains(compact) { return "raw" }
    return nil
  }

  private static func cookMarked(_ name: String, _ tokens: [String], _ word: String) -> Bool {
    if tokens.contains(word) { return true }
    if name.hasSuffix(word) || name.hasSuffix("の\(word)") { return true }
    if word == "生" || word == "焼" || word == "なま" {
      return name.contains("（\(word)") || name.contains("・\(word)")
    }
    return name.contains("（\(word)") || name.contains("・\(word)") || name.contains(" \(word)")
  }

  private static func cutOf(_ name: String, allowThigh: Bool) -> String? {
    let patterns: [(String, String)] = [
      ("ひき肉", "hiki"), ("ひきにく", "hiki"), ("挽肉", "hiki"), ("ミンチ", "hiki"), ("みんち", "hiki"),
      ("ささみ", "sasami"), ("ササミ", "sasami"),
      ("かたロース", "katarosu"), ("肩ロース", "katarosu"), ("かたろす", "katarosu"),
      ("リブロース", "ribu"), ("りぶろす", "ribu"),
      ("サーロイン", "sirloin"), ("さーろいん", "sirloin"), ("さろいん", "sirloin"),
      ("そともも", "momo"), ("うちもも", "momo"),
      ("ロース", "rosu"), ("ろす", "rosu"),
      ("ばら", "bara"), ("バラ", "bara"),
      ("むね", "mune"), ("胸", "mune"),
      ("もも", "momo"), ("モモ", "momo"), ("腿", "momo"),
      ("ひれ", "hire"), ("ヒレ", "hire"), ("フィレ", "hire"),
      ("ランプ", "ranpu"), ("らんぷ", "ranpu"),
      ("手羽", "teba"), ("てば", "teba"),
      ("かた", "kata"), ("肩", "kata"),
      ("すね", "sune"),
    ]
    let normalized = normalize(name)
    for pattern in patterns {
      if !allowThigh && pattern.1 == "momo" { continue }
      for source in [name, normalized] {
        guard let range = source.range(of: pattern.0) else { continue }
        if (pattern.0 == "もも" || pattern.0 == "モモ"),
           let before = source[..<range.lowerBound].last,
           String(before) == "す" {
          continue
        }
        return pattern.1
      }
    }
    return nil
  }

  private static func cutMatches(_ foodCut: String?, _ spokenCut: String) -> Bool {
    guard let foodCut else { return false }
    if foodCut == spokenCut { return true }
    if spokenCut == "rosu" && ["katarosu", "ribu", "rosu"].contains(foodCut) { return true }
    if spokenCut == "kata" && ["kata", "katarosu"].contains(foodCut) { return true }
    return false
  }

  private static func kindOf(_ name: String) -> String? {
    var stripped = name
    if let regex = try? NSRegularExpression(pattern: "（[^）]*）|＜[^＞]*＞") {
      stripped = regex.stringByReplacingMatches(
        in: stripped,
        range: NSRange(stripped.startIndex..., in: stripped),
        withTemplate: " "
      )
    }
    stripped = stripped.replacingOccurrences(of: "　", with: " ").trimmingCharacters(in: .whitespaces)
    if stripped.isEmpty { return name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name }
    var head = stripped.split(separator: " ").first.map(String.init) ?? stripped
    let words = ["ひき肉", "ひきにく", "ささみ", "かたロース", "リブロース", "サーロイン", "そともも", "うちもも", "ロース", "ばら", "むね", "もも", "ひれ", "ランプ", "手羽", "かた", "すね"]
    for word in words { head = head.replacingOccurrences(of: word, with: "") }
    head = head.trimmingCharacters(in: .whitespaces)
    return head.isEmpty ? String(stripped.split(separator: " ").first ?? "") : head
  }

  private static func utteranceKind(_ compact: String, animal: String?, cut: String?) -> String? {
    if broadFoodWords.contains(compact) { return nil }
    var rest = dropCookWords(compact)
    for word in ["牛肉", "豚肉", "鶏肉", "和牛", "牛", "豚", "鶏"] {
      rest = rest.replacingOccurrences(of: word, with: "")
    }
    for word in ["ひき肉", "ささみ", "かたロース", "リブロース", "サーロイン", "ロース", "ばら", "むね", "もも", "ひれ", "かた"] {
      rest = rest.replacingOccurrences(of: word, with: "")
    }
    rest = rest.replacingOccurrences(of: "[のをはがにでとや]", with: "", options: .regularExpression)
    if rest.isEmpty || broadFoodWords.contains(rest) { return nil }
    if animal != nil && cut != nil && rest.count <= 1 { return nil }
    return rest
  }

  private static func kindMatches(_ foodKind: String?, _ spoken: String) -> Bool {
    guard let foodKind, !foodKind.isEmpty, !spoken.isEmpty else { return false }
    let food = foldKana(normalize(foodKind))
    let want = foldKana(normalize(spoken))
    let foodRaw = foldKana(foodKind)
    let wantRaw = foldKana(spoken)
    return food.contains(want) || want.contains(food) || foodRaw.contains(wantRaw) || wantRaw.contains(foodRaw)
  }

  private static func kindClusters(_ foods: [[String: Any]]) -> [String] {
    var kinds: [String] = []
    for food in foods {
      guard let kind = traitsOfFood(food).kind, !kind.isEmpty else { continue }
      let folded = foldKana(normalize(kind))
      let key = folded.isEmpty ? foldKana(kind) : folded
      if key.isEmpty { continue }
      if kinds.contains(where: { $0.contains(key) || key.contains($0) }) { continue }
      kinds.append(key)
    }
    return kinds
  }

  private static func majorityGroup(_ foods: [[String: Any]]) -> String? {
    var counts: [String: Int] = [:]
    for food in foods {
      let code = (food["officialFoodCode"] as? String) ?? (food["id"] as? String) ?? ""
      guard code.count >= 2 else { continue }
      let group = String(code.prefix(2))
      counts[group, default: 0] += 1
    }
    return counts.max { $0.value < $1.value }?.key
  }

  private static func foldKana(_ text: String) -> String {
    let from = Array("がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ")
    let to = Array("かきくけこさしすせそたちつてとはひふへほはひふへほ")
    return String(text.map { char in
      if let at = from.firstIndex(of: char) { return to[at] }
      return char
    })
  }

  private static func hasAny(_ name: String, _ words: [String]) -> Bool {
    let normalized = normalize(name)
    return words.contains { name.contains($0) || normalized.contains($0) }
  }

  private static func foodTokens(_ name: String) -> [String] {
    name
      .replacingOccurrences(of: "（", with: " ")
      .replacingOccurrences(of: "）", with: " ")
      .replacingOccurrences(of: "・", with: " ")
      .replacingOccurrences(of: "　", with: " ")
      .split(separator: " ")
      .map(String.init)
  }

  private static func compactFoodText(_ raw: String) -> String {
    raw
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
      .replacingOccurrences(of: "[。．.！!？?、,]", with: "", options: .regularExpression)
  }

  private static let broadFoodWords: Set<String> = [
    "牛肉", "豚肉", "鶏肉", "魚", "肉", "野菜", "果物", "さかな",
    "ぎゅうにく", "ぶたにく", "とりにく", "やさい", "くだもの",
  ]
  private static let cancelFoodWords: Set<String> = [
    "やめる", "やめて", "やめ", "やめた", "キャンセル", "きゃんせる", "中止", "止めて", "もういい", "登録しない",
  ]
  private static let unknownFoodWords: Set<String> = [
    "わからない", "わかんない", "分からない", "分かんない", "しらない", "知らない",
    "なんでも", "なんでもいい", "何でも", "何でもいい", "どれでも", "どれでもいい",
    "適当", "おすすめ", "おすすめで", "普通", "ふつう", "いつもの",
  ]
  private static let animalSearchWord = ["beef": "牛", "pork": "豚", "chicken": "鶏"]
  private static let cutSearchWord = [
    "momo": "もも", "mune": "むね", "bara": "ばら", "rosu": "ロース", "katarosu": "かたロース",
    "ribu": "リブロース", "sirloin": "サーロイン", "hiki": "ひき肉", "sasami": "ささみ",
    "kata": "かた", "hire": "ひれ", "ranpu": "ランプ", "sune": "すね", "teba": "手羽",
  ]

  private static func rankFoods(_ name: String) async -> [[String: Any]] {
    let savedHits = rankLocalFoods(
      foods().filter { $0["source"] as? String == "saved_food" },
      name: name
    )
    if !savedHits.isEmpty {
      return savedHits
    }
    return await rankUnsavedFoods(name)
  }

  /// 保存済みの次。手元の成分表、食品成分表、公開食品。通信失敗時は空。
  private static func rankUnsavedFoods(_ name: String) async -> [[String: Any]] {
    let localOfficial = rankLocalFoods(
      foods().filter { $0["source"] as? String == "mext_sfct" },
      name: name
    )
    if !localOfficial.isEmpty {
      return localOfficial
    }
    guard var official = await officialFoods(query: name) else {
      return []
    }
    if official.isEmpty {
      let stem = dropCookWords(name)
      if stem != name, let again = await officialFoods(query: stem) {
        official = again
      }
    }
    if !official.isEmpty {
      return official
    }
    guard let published = await publicFoods(query: name) else {
      return []
    }
    return published
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
    let direct = rankExercisesExact(name)
    if !direct.isEmpty {
      return direct
    }
    let stem = exerciseStem(name)
    if stem == name {
      return direct
    }
    return rankExercisesExact(stem)
  }

  /// 「散歩した」「筋トレして」の語尾。食品名には掛けない。
  private static func exerciseStem(_ name: String) -> String {
    let suffixes = ["しました", "やって", "やった", "して", "した"]
    for suffix in suffixes {
      if name.hasSuffix(suffix), name.count > suffix.count {
        return String(name.dropLast(suffix.count))
      }
    }
    return name
  }

  private static func rankExercisesExact(_ name: String) -> [[String: Any]] {
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
  static var description = IntentDescription("食品名と量を登録し、何を登録したかを読み上げます。直前の1件は取り消せます。")
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

  @Parameter(title: "絞り込み")
  var narrowReply: String?

  @Parameter(title: "絞り込み2")
  var narrowReply2: String?

  @Parameter(title: "絞り込み3")
  var narrowReply3: String?

  init() {
    self.foodName = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    SiriAnalytics.started(intent: "log_food", hasParameter: !foodName.text.isEmpty)
    if SiriVoiceStore.consumeContinueSearch() {
      SiriAnalytics.finished(status: "continued", stopReason: "open_app", continued: true)
      return .result(dialog: "アプリで検索します")
    }
    let spoken = try promptedFoodName()
    var plan = await SiriVoiceStore.planFood(name: spoken, quantity: "")
    var retried = false
    while true {
      if plan.asksNarrow {
        plan = await SiriVoiceStore.resolveNarrow(plan, text: try await nextNarrow(plan))
        continue
      }
      if plan.asksKind {
        SiriAnalytics.prompt(kind: "disambiguation")
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
        SiriAnalytics.prompt(kind: "disambiguation")
        let picked = try await $choice.requestDisambiguation(
          among: options,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
      }
      if plan.asksAmount {
        SiriAnalytics.prompt(kind: "value")
        let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = SiriVoiceStore.resolveAmount(plan, text: text)
      }
      if plan.asksRetry {
        if retried {
          SiriVoiceStore.rememberSearch(kind: "food", query: plan.searchQuery ?? spoken)
          SiriAnalytics.finished(status: "continued", stopReason: "needs_app", continued: true)
          throw needsToContinueInForegroundError()
        }
        retried = true
        SiriAnalytics.prompt(kind: "value")
        let again = try await $retryReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = await SiriVoiceStore.planFood(name: again, quantity: "")
        continue
      }
      break
    }
    switch SiriVoiceStore.commitStep(plan) {
    case .speak(let text):
      return .result(dialog: IntentDialog(stringLiteral: text))
    case .confirm(let dialog, let report):
      SiriAnalytics.prompt(kind: "confirmation")
      try await requestConfirmation(
        result: .result(dialog: IntentDialog(stringLiteral: dialog))
      )
      SiriVoiceStore.commitConfirmed(plan)
      return .result(dialog: IntentDialog(stringLiteral: report))
    }
  }

  private func nextNarrow(_ plan: SiriVoiceStore.Plan) async throws -> String {
    let dialog = IntentDialog(stringLiteral: plan.spoken)
    switch plan.narrowRound {
    case 2:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply2.requestValue(dialog)
    case 3:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply3.requestValue(dialog)
    default:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply.requestValue(dialog)
    }
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
  static var description = IntentDescription("種目と量を登録し、何を登録したかを読み上げます。直前の1件は取り消せます。")
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

  @Parameter(title: "絞り込み")
  var narrowReply: String?

  @Parameter(title: "絞り込み2")
  var narrowReply2: String?

  @Parameter(title: "絞り込み3")
  var narrowReply3: String?

  init() {
    self.activityName = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    SiriAnalytics.started(intent: "log_exercise", hasParameter: !activityName.text.isEmpty)
    if SiriVoiceStore.consumeContinueSearch() {
      SiriAnalytics.finished(status: "continued", stopReason: "open_app", continued: true)
      return .result(dialog: "アプリで検索します")
    }
    let spoken = try promptedActivityName()
    var plan = await SiriVoiceStore.planExercise(name: spoken, quantity: "")
    var retried = false
    while true {
    if plan.asksNarrow {
      plan = await SiriVoiceStore.resolveNarrow(plan, text: try await nextNarrow(plan))
      continue
    }
    if plan.asksKind {
      SiriAnalytics.prompt(kind: "disambiguation")
      let picked = try await $kind.requestDisambiguation(
        among: SiriSpokenKind.allCases,
        dialog: IntentDialog(stringLiteral: plan.spoken)
      )
      plan = await SiriVoiceStore.resolveKind(plan, kind: picked)
    }
    if plan.asksChoice {
      let options = SiriChoiceEntity.list(plan.choices)
      SiriAnalytics.prompt(kind: "disambiguation")
      let picked = try await $choice.requestDisambiguation(
        among: options,
        dialog: IntentDialog(stringLiteral: plan.spoken)
      )
      plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
    }
    if plan.asksAmount {
      SiriAnalytics.prompt(kind: "value")
      let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
      plan = SiriVoiceStore.resolveAmount(plan, text: text)
    }
    if plan.asksRetry {
      if retried {
        SiriVoiceStore.rememberSearch(
          kind: "exercise",
          query: plan.searchQuery ?? spoken
        )
        SiriAnalytics.finished(status: "continued", stopReason: "needs_app", continued: true)
        throw needsToContinueInForegroundError()
      }
      retried = true
      SiriAnalytics.prompt(kind: "value")
      let again = try await $retryReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
      plan = await SiriVoiceStore.planExercise(name: again, quantity: "")
      continue
    }
    break
    }
    switch SiriVoiceStore.commitStep(plan) {
    case .speak(let text):
      return .result(dialog: IntentDialog(stringLiteral: text))
    case .confirm(let dialog, let report):
      SiriAnalytics.prompt(kind: "confirmation")
      try await requestConfirmation(
        result: .result(dialog: IntentDialog(stringLiteral: dialog))
      )
      SiriVoiceStore.commitConfirmed(plan)
      return .result(dialog: IntentDialog(stringLiteral: report))
    }
  }

  private func nextNarrow(_ plan: SiriVoiceStore.Plan) async throws -> String {
    let dialog = IntentDialog(stringLiteral: plan.spoken)
    switch plan.narrowRound {
    case 2:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply2.requestValue(dialog)
    case 3:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply3.requestValue(dialog)
    default:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply.requestValue(dialog)
    }
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
  static var description = IntentDescription("話した内容が食事か運動かを判別して登録し、何を登録したかを読み上げます。直前の1件は取り消せます。")
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

  @Parameter(title: "絞り込み")
  var narrowReply: String?

  @Parameter(title: "絞り込み2")
  var narrowReply2: String?

  @Parameter(title: "絞り込み3")
  var narrowReply3: String?

  /// 「カロナビに登録」で種類のあとに聞く自由文。未指定のまま始め、先に聞かない。
  @Parameter(title: "答え")
  var entryReply: String?

  init() {
    self.utterance = SiriSpokenText(id: "", text: "")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    SiriAnalytics.started(intent: "log_utterance", hasParameter: !utterance.text.isEmpty)
    if SiriVoiceStore.consumeContinueSearch() {
      SiriAnalytics.finished(status: "continued", stopReason: "open_app", continued: true)
      return .result(dialog: "アプリで検索します")
    }
    let routed = try await routedEntry()
    let spoken = routed.text
    let forced = routed.kind
    var plan = routed.plan
    var retried = false
    while true {
      if plan.asksNarrow {
        plan = await SiriVoiceStore.resolveNarrow(plan, text: try await nextNarrow(plan))
        continue
      }
      if plan.asksKind {
        SiriAnalytics.prompt(kind: "disambiguation")
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
        SiriAnalytics.prompt(kind: "disambiguation")
        let picked = try await $choice.requestDisambiguation(
          among: options,
          dialog: IntentDialog(stringLiteral: plan.spoken)
        )
        plan = await SiriVoiceStore.resolveChoice(plan, id: picked.id)
      }
      if plan.asksAmount {
        SiriAnalytics.prompt(kind: "value")
        let text = try await $amountReply.requestValue(IntentDialog(stringLiteral: plan.spoken))
        plan = SiriVoiceStore.resolveAmount(plan, text: text)
      }
      if plan.asksRetry {
        if retried {
          SiriVoiceStore.rememberSearch(
            kind: plan.searchKind,
            query: plan.searchQuery ?? spoken
          )
          SiriAnalytics.finished(status: "continued", stopReason: "needs_app", continued: true)
          throw needsToContinueInForegroundError()
        }
        retried = true
        SiriAnalytics.prompt(kind: "value")
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
    switch SiriVoiceStore.commitStep(plan) {
    case .speak(let text):
      return .result(dialog: IntentDialog(stringLiteral: text))
    case .confirm(let dialog, let report):
      SiriAnalytics.prompt(kind: "confirmation")
      try await requestConfirmation(
        result: .result(dialog: IntentDialog(stringLiteral: dialog))
      )
      SiriVoiceStore.commitConfirmed(plan)
      return .result(dialog: IntentDialog(stringLiteral: report))
    }
  }

  private func nextNarrow(_ plan: SiriVoiceStore.Plan) async throws -> String {
    let dialog = IntentDialog(stringLiteral: plan.spoken)
    switch plan.narrowRound {
    case 2:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply2.requestValue(dialog)
    case 3:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply3.requestValue(dialog)
    default:
      SiriAnalytics.prompt(kind: "value")
      return try await $narrowReply.requestValue(dialog)
    }
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
      SiriAnalytics.prompt(kind: "disambiguation")
      picked = try await $kind.requestDisambiguation(
        among: SiriSpokenKind.allCases,
        dialog: IntentDialog(stringLiteral: "食事ですか、運動ですか？")
      )
    }
    let text: String
    if picked == .meal {
      SiriAnalytics.prompt(kind: "value")
      text = try await $entryReply.requestValue(IntentDialog(stringLiteral: "何を食べましたか？"))
      return (text, picked, await SiriVoiceStore.planFood(name: text, quantity: ""))
    }
    SiriAnalytics.prompt(kind: "value")
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
