import Foundation

/// 「何gですか？」への答え。
///
/// グラムなどの聞き返しは、単位を持たない `Double`。届いた数値はそのまま使う。
/// 150 を 0.15 にも 150000 にもしない。換算は、単位つきの測定値パラメータがすること。
/// ここからは質問を返さない。
///
/// 何分の聞き返しは `Measurement<UnitDuration>`。単位が無ければ分。
/// 届いた測定値は `converted(to: .minutes)` で分にしてから、範囲を見る。
/// 最初の発話に「1時間」が含まれるときは、これまでどおり `hoursAsMinutes` を使う。
///
/// ビルド11の `String` は、届いた「150」を 150g にできる。同じ質問が残るのは、
/// その文字列が `requestValue` から戻らなかったときだけ。
enum SiriAmountReply {
  struct Parsed: Equatable {
    var amount: Double
    var unit: String
  }

  /// 数字と小数点だけ。全角数字も含む。漢数字や単位は含まない。
  /// ビルド11で質問が繰り返された答えは、この形だけ。
  static func isDigitOnly(_ utterance: String) -> Bool {
    let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return trimmed.range(
      of: #"^[0-9０-９]+(?:[.．][0-9０-９]+)?$"#,
      options: .regularExpression
    ) != nil
  }

  /// 届いた発話を量にする。単位が無ければ、聞いた単位を足す。
  static func parse(text: String, assumedSuffix: String) -> Parsed? {
    parsePrepared(prepare(text), assumedSuffix: assumedSuffix)
  }

  static func prepare(_ raw: String) -> String {
    var text = stripSpokenTail(raw)
    text = normalizeNumerals(text)
    text = foldHiraganaBeforeUnit(text)
    text = foldBareHiraganaNumber(text)
    return text
  }

  static func parsePrepared(_ prepared: String, assumedSuffix: String) -> Parsed? {
    if let parsed = parseLeading(prepared) {
      return parsed
    }
    let suffix = assumedSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
    if suffix.isEmpty {
      return nil
    }
    return parseLeading(prepared + suffix)
  }

  static let unheardSpeech = "量を聞き取れませんでした。もう一度、最初から言ってください"
  static let gramQuestion = "何gですか？"

  /// ビルド11の `amountFromReply`。漢数字と全角数字だけを直し、語尾やひらがなは触らない。
  static func build11Amount(text: String, suffix: String) -> Parsed? {
    let normalized = normalizeNumerals(text)
    return parseLeading(normalized) ?? parseLeading(normalized + suffix)
  }

  enum Turn: Equatable {
    /// `requestValue` が戻らなかった。打ち切りの文には入らない。
    case askAgain(String)
    case recorded(Parsed)
    case stop(String)
  }

  /// ビルド11の量の1ターン。`delivered` が nil のときだけ、同じ質問が残る。
  static func build11Turn(question: String, suffix: String, delivered: String?) -> Turn {
    guard let delivered else {
      return .askAgain(question)
    }
    if let parsed = build11Amount(text: delivered, suffix: suffix) {
      return .recorded(parsed)
    }
    return .stop(unheardSpeech)
  }

  /// 発話を必ず受けたあとの1ターン。解析できなければ同じ質問には戻さない。
  static func resolvedTurn(suffix: String, utterance: String) -> Turn {
    if let parsed = parse(text: utterance, assumedSuffix: suffix) {
      return .recorded(parsed)
    }
    return .stop(unheardSpeech)
  }

  private static func stripSpokenTail(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trailing = try? NSRegularExpression(pattern: #"[。．.！!？?]+$"#) {
      let range = NSRange(text.startIndex..., in: text)
      text = trailing.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
    let tails = ["です", "だよ", "だね", "くらい", "ぐらい", "ほど", "かな"]
    var changed = true
    while changed {
      changed = false
      for tail in tails where text.hasSuffix(tail) && text.count > tail.count {
        text = String(text.dropLast(tail.count))
        changed = true
      }
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 全角数字と漢数字（〇〜九、十、百、千）を半角の数字にする。
  static func normalizeNumerals(_ text: String) -> String {
    let digits: [Character: Int] = [
      "〇": 0, "零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
      "六": 6, "七": 7, "八": 8, "九": 9,
    ]
    let units: [Character: Int] = ["十": 10, "百": 100, "千": 1000]
    var out = ""
    var total = 0
    var current = -1
    var inNumber = false
    func flush() {
      if inNumber {
        out += String(total + max(current, 0))
      }
      total = 0
      current = -1
      inNumber = false
    }
    for ch in text {
      if let wide = ch.unicodeScalars.first?.value, wide >= 0xFF10, wide <= 0xFF19, ch.unicodeScalars.count == 1 {
        flush()
        out.append(Character(UnicodeScalar(wide - 0xFF10 + 0x30)!))
        continue
      }
      if let digit = digits[ch] {
        inNumber = true
        current = (current < 0 ? 0 : current) * 10 + digit
        continue
      }
      if let unit = units[ch] {
        inNumber = true
        total += (current < 0 ? 1 : current) * unit
        current = -1
        continue
      }
      flush()
      out.append(ch)
    }
    flush()
    return out
  }

  private static let quantityUnits = [
    "ミリリットル", "キロメートル", "グラム", "分間", "食分",
    "ml", "mL", "ML", "ｍｌ", "km", "KM", "㎞", "キロ",
    "個", "こ", "コ", "食", "分", "回", "g", "G", "ｇ",
  ]

  private static func foldHiraganaBeforeUnit(_ text: String) -> String {
    var result = text
    for unit in quantityUnits {
      var from = result.startIndex
      while from < result.endIndex,
            let range = result.range(of: unit, range: from..<result.endIndex) {
        if let number = hiraganaNumberBefore(result, at: range.lowerBound) {
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

  private static func foldBareHiraganaNumber(_ text: String) -> String {
    let compact = text
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
    guard let value = parseHiraganaNumber(compact) else {
      return text
    }
    return String(value)
  }

  private static func hiraganaNumberBefore(
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
      if let value = parseHiraganaNumber(part) {
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

  private static func parseHiraganaNumber(_ text: String) -> Int? {
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

  private static func parseLeading(_ raw: String) -> Parsed? {
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
    return Parsed(amount: amount, unit: mapped)
  }
}

/// 聞き返しの単位。食品の `g` / `ml` / `piece` / `serving` と、運動の `durationMin` / `distanceKm`。
enum SiriAmountSlot: String, Equatable {
  case grams
  case milliliters
  case minutes
  case kilometers
  case count

  var suffix: String {
    switch self {
    case .grams: return "g"
    case .milliliters: return "ml"
    case .minutes: return "分"
    case .kilometers: return "km"
    case .count: return "個"
    }
  }

  /// 個と食分は同じ数値パラメータ。食分のときだけ接尾辞を変える。
  func suffix(foodUnit: String?) -> String {
    if self == .count && foodUnit == "serving" {
      return "食"
    }
    return suffix
  }

  static func from(unit: String?) -> SiriAmountSlot {
    switch unit {
    case "ml": return .milliliters
    case "distanceKm": return .kilometers
    case "durationMin": return .minutes
    case "piece", "serving": return .count
    default: return .grams
    }
  }
}

extension SiriAmountReply {
  /// `Double` が戻ったあとの1手。届いた数値を、質問の単位のまま登録する。
  /// 1000 倍もしない。0.001 倍もしない。同じ質問には戻さない。
  static func followUp(number: Double, suffix: String) -> Turn {
    guard number > 0, number < 100_000 else {
      return .stop(unheardSpeech)
    }
    guard let parsed = parse(text: canonical(number), assumedSuffix: suffix) else {
      return .stop(unheardSpeech)
    }
    return .recorded(parsed)
  }

  /// 聞き返しの測定値を分にする。秒で戻っても、時間で戻っても、分に換算してから範囲を見る。
  /// 0 以下、有限でない値、10万分以上は登録しない。
  static func minutes(from measurement: Measurement<UnitDuration>) -> Double? {
    let minutes = measurement.converted(to: .minutes).value
    guard minutes.isFinite, minutes > 0, minutes < 100_000 else {
      return nil
    }
    return minutes
  }

  /// ログに出す単位。食品名や種目名は含まない。
  static func durationUnitLabel(_ unit: UnitDuration) -> String {
    if unit == .hours { return "hr" }
    if unit == .minutes { return "min" }
    if unit == .seconds { return "s" }
    if unit == .milliseconds { return "ms" }
    if unit == .microseconds { return "us" }
    if unit == .nanoseconds { return "ns" }
    return unit.symbol
  }

  /// 最初の発話に時間の言葉があるとき。「1時間」は 60、「1」は 1、「30分」は 30。
  static func minutes(fromSpoken text: String) -> Double? {
    let prepared = prepare(text)
    if let minutes = hoursAsMinutes(prepared) {
      return minutes
    }
    guard let parsed = parsePrepared(prepared, assumedSuffix: "分"), parsed.unit == "minutes" else {
      return nil
    }
    return parsed.amount
  }

  /// 運動の時間の答え「1時間」「1時間半」「1時間30分」を分にする。
  static func hoursAsMinutes(_ text: String) -> Double? {
    let compact = text
      .replacingOccurrences(of: "[\\s。、,]", with: "", options: .regularExpression)
      .replacingOccurrences(of: "(です|くらい|ぐらい|ほど)$", with: "", options: .regularExpression)
    guard let regex = try? NSRegularExpression(
      pattern: #"^(\d+(?:\.\d+)?)時間(?:(半)|(\d+)分間?)?$"#
    ),
      let found = regex.firstMatch(in: compact, range: NSRange(compact.startIndex..., in: compact)),
      let hoursRange = Range(found.range(at: 1), in: compact),
      let hours = Double(compact[hoursRange])
    else {
      return nil
    }
    var minutes = hours * 60
    if Range(found.range(at: 2), in: compact) != nil {
      minutes += 30
    }
    if let extraRange = Range(found.range(at: 3), in: compact), let extra = Double(compact[extraRange]) {
      minutes += extra
    }
    return minutes > 0 ? minutes : nil
  }

  /// 150 は "150"。150.5 はそのまま。
  static func canonical(_ number: Double) -> String {
    if number == number.rounded(), abs(number) < Double(Int.max) {
      return String(Int(number.rounded()))
    }
    return String(number)
  }
}

/// 同じ質問文は2回まで。3回目は `requestValue` を呼ぶ前に止める。
/// 別の質問文は数えない。絞り込みのあとに量を聞いても、量の1回目のまま。
enum SiriQuestionLimit {
  static let maxAsks = 2
  static let exitSpeech = "同じ質問が続いたので、登録を中断しました。もう一度、最初から言ってください"
  static let staleSeconds: TimeInterval = 180
  /// 中断の直後に `perform()` がやり直されても、同じ質問は出さない。人がやり直す間隔では消す。
  static let reopenSeconds: TimeInterval = 5
  private static let countsKey = "siriQuestionCounts"
  private static let atKey = "siriQuestionAt"
  private static let closedKey = "siriQuestionClosed"

  static func allowAsk(question: String, defaults: UserDefaults, now: TimeInterval) -> Bool {
    let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
    let closed = defaults.double(forKey: closedKey)
    let last = defaults.double(forKey: atKey)
    var counts = load(defaults)
    if closed > 0 && now - closed >= reopenSeconds {
      counts = [:]
      defaults.removeObject(forKey: closedKey)
    } else if closed <= 0 && (last <= 0 || now - last > staleSeconds) {
      counts = [:]
    }
    let next = (counts[text] ?? 0) + 1
    counts[text] = next
    save(counts, defaults: defaults)
    defaults.set(now, forKey: atKey)
    return next <= maxAsks
  }

  static func asks(question: String, defaults: UserDefaults) -> Int {
    let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
    return load(defaults)[text] ?? 0
  }

  static func close(defaults: UserDefaults, now: TimeInterval) {
    defaults.set(now, forKey: closedKey)
  }

  static func reset(defaults: UserDefaults) {
    defaults.removeObject(forKey: countsKey)
    defaults.removeObject(forKey: atKey)
    defaults.removeObject(forKey: closedKey)
  }

  private static func load(_ defaults: UserDefaults) -> [String: Int] {
    guard let raw = defaults.string(forKey: countsKey),
          let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    var counts: [String: Int] = [:]
    for (key, value) in object {
      if let number = value as? Int {
        counts[key] = number
      } else if let number = value as? NSNumber {
        counts[key] = number.intValue
      }
    }
    return counts
  }

  private static func save(_ counts: [String: Int], defaults: UserDefaults) {
    guard JSONSerialization.isValidJSONObject(counts),
          let data = try? JSONSerialization.data(withJSONObject: counts),
          let raw = String(data: data, encoding: .utf8)
    else {
      return
    }
    defaults.set(raw, forKey: countsKey)
  }
}

/// 数値がすでに入っていれば質問しない。無いときだけ数える。3回目は request を呼ばない。
enum SiriAmountAsk {
  enum Outcome: Equatable {
    case number(Double)
    /// 何分の測定値。値と単位が両方入っている。
    case duration(Measurement<UnitDuration>)
    case stopRepeat
  }

  static func take(
    stored: Double?,
    question: String,
    defaults: UserDefaults,
    now: TimeInterval,
    request: () async throws -> Double
  ) async throws -> Outcome {
    if let stored {
      return .number(stored)
    }
    guard SiriQuestionLimit.allowAsk(question: question, defaults: defaults, now: now) else {
      return .stopRepeat
    }
    return .number(try await request())
  }

  /// 何分の測定値。すでに入っていれば質問しない。3回目は request を呼ばない。
  static func takeDuration(
    stored: Measurement<UnitDuration>?,
    question: String,
    defaults: UserDefaults,
    now: TimeInterval,
    request: () async throws -> Measurement<UnitDuration>
  ) async throws -> Outcome {
    if let stored {
      return .duration(stored)
    }
    guard SiriQuestionLimit.allowAsk(question: question, defaults: defaults, now: now) else {
      return .stopRepeat
    }
    return .duration(try await request())
  }
}
