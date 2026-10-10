#if canImport(SiriAmountReply)
@testable import SiriAmountReply
#endif
import XCTest

/// ビルド11で「何gですか？」に「150」と答えると、同じ質問が戻り、登録されない。
/// 「150グラム」は登録される。
///
/// ここで実行して証明すること:
/// 1. ビルド11の解析は、「150」が文字列として届けば 150g にする。解析の失敗が無限ループの原因ではない。
/// 2. 届けば、解析できない答えは同じ質問ではなく打ち切りの文になる。この分岐は同じ質問を返さない。
/// 3. 同じ「何gですか？」が残るのは、答えが1つも届かなかったときだけ。
/// 4. 繰り返された答えは数字だけ。その形は、届いていれば登録されていた。
/// 5. 届いたあとの解析は「150」を1回で 150g にする。質問の回数には上限がある。
final class SiriAmountReplyTests: XCTestCase {
  private let gramQuestion = SiriAmountReply.gramQuestion

  func testBuild11RecordsABareNumberWhenTheStringArrives() {
    let phrases = ["150", "１５０", "150.0", "百五十"]
    for phrase in phrases {
      let parsed = SiriAmountReply.build11Amount(text: phrase, suffix: "g")
      XCTAssertEqual(parsed?.amount, 150, phrase)
      XCTAssertEqual(parsed?.unit, "grams", phrase)
    }
  }

  func testBuild11RecordsUnitPhrasesThatAlreadyWork() {
    let phrases = ["150グラム", "150g", "150ｇ", "百五十グラム"]
    for phrase in phrases {
      let parsed = SiriAmountReply.build11Amount(text: phrase, suffix: "g")
      XCTAssertEqual(parsed?.amount, 150, phrase)
      XCTAssertEqual(parsed?.unit, "grams", phrase)
    }
  }

  func testBuild11RecordsBareMinutesForExercise() {
    let parsed = SiriAmountReply.build11Amount(text: "30", suffix: "分")
    XCTAssertEqual(parsed?.amount, 30)
    XCTAssertEqual(parsed?.unit, "minutes")
    let kanji = SiriAmountReply.build11Amount(text: "三十分", suffix: "分")
    XCTAssertEqual(kanji?.amount, 30)
    XCTAssertEqual(kanji?.unit, "minutes")
  }

  func testDeliveredReplyNeverKeepsTheGramQuestion() {
    let phrases = [
      "150", "１５０", "150.5", "150グラム", "150g", "百五十", "百五十グラム",
      "ひゃくごじゅう", "たくさん", "150です",
    ]
    for phrase in phrases {
      let turn = SiriAmountReply.build11Turn(
        question: gramQuestion,
        suffix: "g",
        delivered: phrase
      )
      if case .askAgain = turn {
        XCTFail("届いた答えが同じ質問に残った: \(phrase)")
      }
    }
  }

  func testDeliveredBareNumberIsRecordedInsteadOfAskedAgain() {
    let turn = SiriAmountReply.build11Turn(
      question: gramQuestion,
      suffix: "g",
      delivered: "150"
    )
    XCTAssertEqual(turn, .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams")))
  }

  func testDeliveredUnitPhraseIsRecorded() {
    let turn = SiriAmountReply.build11Turn(
      question: gramQuestion,
      suffix: "g",
      delivered: "150グラム"
    )
    XCTAssertEqual(turn, .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams")))
  }

  func testDeliveredKanjiNumberIsRecorded() {
    let turn = SiriAmountReply.build11Turn(
      question: gramQuestion,
      suffix: "g",
      delivered: "百五十"
    )
    XCTAssertEqual(turn, .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams")))
  }

  func testUnparseableDeliveryStopsInsteadOfAskingAgain() {
    let turn = SiriAmountReply.build11Turn(
      question: gramQuestion,
      suffix: "g",
      delivered: "たくさん"
    )
    XCTAssertEqual(turn, .stop(SiriAmountReply.unheardSpeech))
    XCTAssertNotEqual(SiriAmountReply.unheardSpeech, gramQuestion)
  }

  func testHiraganaWithoutAUnitStopsOnceOnBuild11() {
    XCTAssertNil(SiriAmountReply.build11Amount(text: "ひゃくごじゅう", suffix: "g"))
    let turn = SiriAmountReply.build11Turn(
      question: gramQuestion,
      suffix: "g",
      delivered: "ひゃくごじゅう"
    )
    XCTAssertEqual(turn, .stop(SiriAmountReply.unheardSpeech))
  }

  /// 同じ質問が5回残るのは、答えが一度も届かないときだけ。
  func testSameQuestionRemainsOnlyWhenNothingIsDelivered() {
    var question = gramQuestion
    for _ in 0..<5 {
      let turn = SiriAmountReply.build11Turn(question: question, suffix: "g", delivered: nil)
      guard case .askAgain(let again) = turn else {
        return XCTFail("届いていない答えが登録か打ち切りになった: \(turn)")
      }
      XCTAssertEqual(again, gramQuestion)
      question = again
    }
  }

  /// CEOが繰り返した「150」は数字だけ。届いていれば 150g になっていた。
  /// 「150グラム」「百五十」は数字だけではないので、ビルド11でも登録される。
  func testLoopingRepliesAreDigitOnlyAndWouldHaveBeenRecorded() {
    let looping = ["150", "１５０", "150.5"]
    for phrase in looping {
      XCTAssertTrue(SiriAmountReply.isDigitOnly(phrase), phrase)
      let turn = SiriAmountReply.build11Turn(
        question: gramQuestion,
        suffix: "g",
        delivered: phrase
      )
      guard case .recorded(let parsed) = turn else {
        return XCTFail("数字だけの答えが登録にならなかった: \(phrase) \(turn)")
      }
      XCTAssertEqual(parsed.unit, "grams", phrase)
      XCTAssertEqual(parsed.amount, phrase == "150.5" ? 150.5 : 150, phrase)
    }
    let notDigitOnly = ["150グラム", "150g", "百五十", "百五十グラム", "ひゃくごじゅう"]
    for phrase in notDigitOnly {
      XCTAssertFalse(SiriAmountReply.isDigitOnly(phrase), phrase)
    }
  }

  func testReturnedNumberUsesTheQuestionUnitInOneStep() {
    let cases: [(Double, String, Double, String)] = [
      (150, "g", 150, "grams"),
      (150.5, "g", 150.5, "grams"),
      (30, "分", 30, "minutes"),
      (5, "km", 5, "kilometers"),
      (200, "ml", 200, "milliliters"),
      (2, "個", 2, "piece"),
      (1, "食", 1, "serving"),
    ]
    for item in cases {
      let turn = SiriAmountReply.followUp(number: item.0, suffix: item.1)
      guard case .recorded(let parsed) = turn else {
        return XCTFail("数値が同じ質問に戻った: \(item) \(turn)")
      }
      XCTAssertEqual(parsed.amount, item.2, item.1)
      XCTAssertEqual(parsed.unit, item.3, item.1)
    }
  }

  func testReturnedNumberDoesNotAskForTheUnit() {
    let turn = SiriAmountReply.followUp(number: 150, suffix: "g")
    if case .askAgain = turn {
      XCTFail("150 のあとに単位を聞き直した")
    }
    XCTAssertEqual(turn, .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams")))
    XCTAssertNotEqual(SiriAmountReply.unheardSpeech, gramQuestion)
  }

  func testUnitPhrasesStillParseWhenTheWordsArrive() {
    let grams = SiriAmountReply.parse(text: "150グラム", assumedSuffix: "g")
    XCTAssertEqual(grams?.amount, 150)
    XCTAssertEqual(grams?.unit, "grams")
    let minutes = SiriAmountReply.parse(text: "30分", assumedSuffix: "分")
    XCTAssertEqual(minutes?.amount, 30)
    XCTAssertEqual(minutes?.unit, "minutes")
    let kilometers = SiriAmountReply.parse(text: "5キロ", assumedSuffix: "km")
    XCTAssertEqual(kilometers?.amount, 5)
    XCTAssertEqual(kilometers?.unit, "kilometers")
    let kanji = SiriAmountReply.parse(text: "百五十", assumedSuffix: "g")
    XCTAssertEqual(kanji?.amount, 150)
    XCTAssertEqual(kanji?.unit, "grams")
  }

  func testAmountSlotFollowsTheQuestionUnit() {
    XCTAssertEqual(SiriAmountSlot.from(unit: "g"), .grams)
    XCTAssertEqual(SiriAmountSlot.from(unit: nil), .grams)
    XCTAssertEqual(SiriAmountSlot.from(unit: "ml"), .milliliters)
    XCTAssertEqual(SiriAmountSlot.from(unit: "durationMin"), .minutes)
    XCTAssertEqual(SiriAmountSlot.from(unit: "distanceKm"), .kilometers)
    XCTAssertEqual(SiriAmountSlot.from(unit: "piece"), .count)
    XCTAssertEqual(SiriAmountSlot.from(unit: "serving"), .count)
    XCTAssertEqual(SiriAmountSlot.grams.suffix, "g")
    XCTAssertEqual(SiriAmountSlot.minutes.suffix, "分")
    XCTAssertEqual(SiriAmountSlot.kilometers.suffix, "km")
    XCTAssertEqual(SiriAmountSlot.count.suffix(foodUnit: "piece"), "個")
    XCTAssertEqual(SiriAmountSlot.count.suffix(foodUnit: "serving"), "食")
  }

  func testStoredNumberDoesNotAsk() async throws {
    let defaults = freshDefaults("siri-stored-number")
    var calls = 0
    let outcome = try await SiriAmountAsk.take(
      stored: 150,
      question: gramQuestion,
      defaults: defaults,
      now: 1
    ) {
      calls += 1
      return 1
    }
    XCTAssertEqual(outcome, .number(150))
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(SiriQuestionLimit.asks(question: gramQuestion, defaults: defaults), 0)
  }

  func testThirdIdenticalQuestionDoesNotCallRequest() async throws {
    let defaults = freshDefaults("siri-third-ask")
    let now = Date().timeIntervalSince1970
    for _ in 0..<2 {
      let outcome = try await SiriAmountAsk.take(
        stored: nil,
        question: gramQuestion,
        defaults: defaults,
        now: now
      ) { 150 }
      XCTAssertEqual(outcome, .number(150))
    }
    var calls = 0
    let third = try await SiriAmountAsk.take(
      stored: nil,
      question: gramQuestion,
      defaults: defaults,
      now: now + 1
    ) {
      calls += 1
      return 150
    }
    XCTAssertEqual(third, .stopRepeat)
    XCTAssertEqual(calls, 0)
    XCTAssertNotEqual(SiriQuestionLimit.exitSpeech, gramQuestion)
    SiriQuestionLimit.close(defaults: defaults, now: now + 1)
    var again = 0
    let restarted = try await SiriAmountAsk.take(
      stored: nil,
      question: gramQuestion,
      defaults: defaults,
      now: now + 2
    ) {
      again += 1
      return 150
    }
    XCTAssertEqual(restarted, .stopRepeat)
    XCTAssertEqual(again, 0)
    let reopened = try await SiriAmountAsk.take(
      stored: nil,
      question: gramQuestion,
      defaults: defaults,
      now: now + 2 + SiriQuestionLimit.reopenSeconds
    ) { 150 }
    XCTAssertEqual(reopened, .number(150))
  }

  func testDifferentQuestionsDoNotShareTheCap() {
    let defaults = freshDefaults("siri-different-questions")
    let now = Date().timeIntervalSince1970
    let questions = [
      "どの部位ですか？",
      "食事ですか、運動ですか？",
      "何を食べましたか？",
      "何gですか？",
      "何mlですか？",
      "何個ですか？",
      "何分ですか？",
      "何キロですか？",
      "でいいですね",
    ]
    for question in questions {
      XCTAssertTrue(
        SiriQuestionLimit.allowAsk(question: question, defaults: defaults, now: now),
        question
      )
    }
    XCTAssertTrue(
      SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: now + 1)
    )
    XCTAssertFalse(
      SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: now + 2)
    )
    XCTAssertTrue(
      SiriQuestionLimit.allowAsk(question: "何分ですか？", defaults: defaults, now: now + 3)
    )
  }

  func testResolvedBareNumberRecordsOnTheFirstReply() {
    let turn = SiriAmountReply.resolvedTurn(suffix: "g", utterance: "150")
    XCTAssertEqual(turn, .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams")))
  }

  func testResolvedParserStillAcceptsThePhrasesBuild11Accepted() {
    let phrases = ["150", "１５０", "150.0", "百五十", "150グラム", "150g", "150ｇ", "百五十グラム", "三十分"]
    for phrase in phrases {
      let suffix = phrase == "三十分" ? "分" : "g"
      let legacy = SiriAmountReply.build11Amount(text: phrase, suffix: suffix)
      let updated = SiriAmountReply.parse(text: phrase, assumedSuffix: suffix)
      XCTAssertEqual(updated?.amount, legacy?.amount, phrase)
      XCTAssertEqual(updated?.unit, legacy?.unit, phrase)
      XCTAssertNotNil(updated, phrase)
    }
  }

  func testResolvedParserAcceptsHiraganaAndPoliteTails() {
    let phrases = ["ひゃくごじゅう", "ひゃくごじゅうグラム", "150グラムです", "150です"]
    for phrase in phrases {
      let parsed = SiriAmountReply.parse(text: phrase, assumedSuffix: "g")
      XCTAssertEqual(parsed?.amount, 150, phrase)
      XCTAssertEqual(parsed?.unit, "grams", phrase)
    }
  }

  func testResolvedUnparseableReplyStops() {
    let turn = SiriAmountReply.resolvedTurn(suffix: "g", utterance: "たくさん")
    XCTAssertEqual(turn, .stop(SiriAmountReply.unheardSpeech))
  }

  func testHourPhrasesStayIntactForTheExerciseParser() {
    XCTAssertEqual(SiriAmountReply.prepare("1時間半"), "1時間半")
    XCTAssertEqual(SiriAmountReply.prepare("1時間30分"), "1時間30分")
    XCTAssertEqual(SiriAmountReply.prepare("1時間です"), "1時間")
  }

  /// 数値の 1 は 1分。時間の言葉が残っているときだけ 60 と 90 になる。
  func testHourPhrasesBecomeMinutesAndBareOneDoesNot() {
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間"), 60)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間です"), 60)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間半"), 90)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間30分"), 90)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間30分間"), 90)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "30"), 30)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "30分"), 30)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1"), 1)
    XCTAssertEqual(
      SiriAmountReply.followUp(number: 1, suffix: "分"),
      .recorded(SiriAmountReply.Parsed(amount: 1, unit: "minutes"))
    )
    XCTAssertNil(SiriAmountReply.minutes(fromSpoken: "5キロ"))
    XCTAssertTrue(SiriAmountSlot.minutes.keepsSpokenWords)
    XCTAssertFalse(SiriAmountSlot.grams.keepsSpokenWords)
  }

  /// 戻った数値は倍率を掛けない。150 は 150 のまま。0.15 を 150 にもしない。
  func testReturnedNumberIsNotScaled() {
    XCTAssertEqual(
      SiriAmountReply.followUp(number: 150, suffix: "g"),
      .recorded(SiriAmountReply.Parsed(amount: 150, unit: "grams"))
    )
    XCTAssertEqual(
      SiriAmountReply.followUp(number: 0.15, suffix: "g"),
      .recorded(SiriAmountReply.Parsed(amount: 0.15, unit: "grams"))
    )
    XCTAssertEqual(SiriAmountReply.canonical(150), "150")
    XCTAssertEqual(SiriAmountReply.canonical(0.15), "0.15")
    XCTAssertNotEqual(SiriAmountReply.canonical(150), "0.15")
    XCTAssertNotEqual(SiriAmountReply.canonical(150), "150000")
  }

  func testStoredHourPhraseDoesNotAskAgain() async throws {
    let defaults = freshDefaults("siri-stored-hour")
    var calls = 0
    let outcome = try await SiriAmountAsk.takeText(
      stored: "1時間半",
      question: "何分ですか？",
      defaults: defaults,
      now: 1
    ) {
      calls += 1
      return "1"
    }
    XCTAssertEqual(outcome, .spoken("1時間半"))
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(SiriAmountReply.minutes(fromSpoken: "1時間半"), 90)
  }

  func testOtherUnitsUseTheQuestionSuffix() {
    XCTAssertEqual(
      SiriAmountReply.build11Amount(text: "200", suffix: "ml")?.unit,
      "milliliters"
    )
    XCTAssertEqual(
      SiriAmountReply.build11Amount(text: "2", suffix: "個")?.unit,
      "piece"
    )
    XCTAssertEqual(
      SiriAmountReply.build11Amount(text: "1", suffix: "食")?.unit,
      "serving"
    )
    XCTAssertEqual(
      SiriAmountReply.build11Amount(text: "5", suffix: "km")?.unit,
      "kilometers"
    )
  }

  func testSameQuestionResetsAfterAPauseAndAfterEnd() {
    let defaults = freshDefaults("siri-amount-reply-stale")
    let now = Date().timeIntervalSince1970
    XCTAssertTrue(SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: now))
    XCTAssertTrue(SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: now + 10))
    XCTAssertFalse(SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: now + 11))
    let later = now + 11 + SiriQuestionLimit.staleSeconds + 1
    XCTAssertTrue(SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: later))
    SiriQuestionLimit.reset(defaults: defaults)
    XCTAssertTrue(SiriQuestionLimit.allowAsk(question: gramQuestion, defaults: defaults, now: later + 1))
    XCTAssertEqual(SiriQuestionLimit.asks(question: gramQuestion, defaults: defaults), 1)
  }

  private func freshDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }
}
