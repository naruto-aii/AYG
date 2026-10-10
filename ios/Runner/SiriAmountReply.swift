import Foundation

/// 「何gですか？」への答え。
///
/// ビルド11で同じ質問が続くのは、`resolveAmount` の中ではない。
/// 届いた文字列は、量が取れれば登録になり、取れなければ
/// 「量を聞き取れませんでした。もう一度、最初から言ってください」で終わる。
/// 数字だけの「150」も、文字列として届いていれば 150g になる。
/// 同じ「何gですか？」が残るのは、`requestValue` がその文字列を返さなかったときだけ。
///
/// 食品名の自由文を独自の型で受けたときの無限ループとは別。あれは空文字で初期化した非Optionalを
/// `needsValueError` で聞き直したため、やり直しのたびに空のまま同じ質問に戻っていた。
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

  /// 検索文字列をそのまま受けたときに、量の答えとして残す言葉。空は捨てる。
  static func acceptedTranscript(_ raw: String) -> String? {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
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

/// 質問の回数。`perform()` がやり直されても、同じ会話のあいだは増やす。
enum SiriDialogueLimit {
  static let maxRounds = 32
  static let exitSpeech = "質問が続いたので、登録を中断しました。もう一度、最初から言ってください"
  static let staleSeconds: TimeInterval = 180
  private static let roundKey = "siriVoiceDialogueRound"
  private static let atKey = "siriVoiceDialogueAt"

  static func notePrompt(defaults: UserDefaults, now: TimeInterval) -> Int {
    let last = defaults.double(forKey: atKey)
    var round = defaults.integer(forKey: roundKey)
    if last <= 0 || now - last > staleSeconds {
      round = 0
    }
    round += 1
    defaults.set(round, forKey: roundKey)
    defaults.set(now, forKey: atKey)
    return round
  }

  /// 上限まで数える。超えた回は false を返し、回数を消す。次の会話は1から。
  static func allow(defaults: UserDefaults, now: TimeInterval) -> Bool {
    let round = notePrompt(defaults: defaults, now: now)
    if round > maxRounds {
      reset(defaults: defaults)
      return false
    }
    return true
  }

  static func reset(defaults: UserDefaults) {
    defaults.removeObject(forKey: roundKey)
    defaults.removeObject(forKey: atKey)
  }
}
