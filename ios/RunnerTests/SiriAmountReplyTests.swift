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

  func testAcceptedTranscriptKeepsABareNumber() {
    XCTAssertEqual(SiriAmountReply.acceptedTranscript("150"), "150")
    XCTAssertEqual(SiriAmountReply.acceptedTranscript("１５０"), "１５０")
    XCTAssertEqual(SiriAmountReply.acceptedTranscript("150.5"), "150.5")
    XCTAssertEqual(SiriAmountReply.acceptedTranscript(" 150グラム "), "150グラム")
    XCTAssertNil(SiriAmountReply.acceptedTranscript("  "))
    XCTAssertNil(SiriAmountReply.acceptedTranscript(""))
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

  func testDialogueStopsAfterTheRoundCapAndTheNextConversationStartsOver() {
    let defaults = UserDefaults(suiteName: "siri-amount-reply-tests")!
    defaults.removePersistentDomain(forName: "siri-amount-reply-tests")
    let start = Date().timeIntervalSince1970
    for round in 1...SiriDialogueLimit.maxRounds {
      XCTAssertTrue(
        SiriDialogueLimit.allow(defaults: defaults, now: start + Double(round)),
        "round \(round)"
      )
    }
    XCTAssertFalse(
      SiriDialogueLimit.allow(
        defaults: defaults,
        now: start + Double(SiriDialogueLimit.maxRounds + 1)
      )
    )
    XCTAssertFalse(SiriDialogueLimit.exitSpeech.isEmpty)
    XCTAssertNotEqual(SiriDialogueLimit.exitSpeech, gramQuestion)
    XCTAssertTrue(
      SiriDialogueLimit.allow(
        defaults: defaults,
        now: start + Double(SiriDialogueLimit.maxRounds + 2)
      )
    )
  }

  func testDialogueRoundResetsAfterAPause() {
    let defaults = UserDefaults(suiteName: "siri-amount-reply-stale")!
    defaults.removePersistentDomain(forName: "siri-amount-reply-stale")
    let now = Date().timeIntervalSince1970
    XCTAssertEqual(SiriDialogueLimit.notePrompt(defaults: defaults, now: now), 1)
    XCTAssertEqual(SiriDialogueLimit.notePrompt(defaults: defaults, now: now + 10), 2)
    let later = now + 10 + SiriDialogueLimit.staleSeconds + 1
    XCTAssertEqual(SiriDialogueLimit.notePrompt(defaults: defaults, now: later), 1)
  }
}
