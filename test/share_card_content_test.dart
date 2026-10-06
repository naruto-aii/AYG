import 'package:ayg/models/daily_summary.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/services/share_card_content.dart';
import 'package:ayg/services/share_links.dart';
import 'package:ayg/services/usage_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 6);

  DailySummary summary({
    double intake = 1820,
    double remaining = 180,
    double target = 2000,
    double protein = 25,
    double fat = 10,
    double carb = 30,
    double exercise = 0,
    bool overage = false,
    double overageKcal = 0,
  }) {
    return DailySummary(
      targetKcal: target,
      remainingKcal: remaining,
      targetProteinG: 80,
      targetFatG: 50,
      targetCarbG: 200,
      intakeKcal: intake,
      intakeProteinG: protein,
      intakeFatG: fat,
      intakeCarbG: carb,
      exerciseBurnKcal: exercise,
      isCalorieOverage: overage,
      calorieOverageKcal: overageKcal,
    );
  }

  test('macro percentages use energy and add up to 100', () {
    final balance = macroEnergyBalance(proteinG: 25, fatG: 10, carbG: 30);
    expect(balance, isNotNull);
    expect(balance!.protein, 32);
    expect(balance.fat, 29);
    expect(balance.carb, 39);
    expect(balance.protein + balance.fat + balance.carb, 100);
    expect(macroEnergyBalance(proteinG: 0, fatG: 0, carbG: 0), isNull);
  });

  test('meal text keeps the gap, the balance, and the link', () {
    final card = buildMealShareCard(
      summary: summary(exercise: 320),
      day: day,
      format: ShareCardFormat.story,
    );
    expect(card.headline, '1,820');
    expect(card.detail, '目標まであと 180kcal');
    expect(card.extra, '運動で 320kcal');
    expect(card.message, contains('1,820 kcal'));
    expect(card.message, contains('あと180kcal'));
    expect(card.message, contains('320kcal'));
    expect(card.message, contains('たんぱく質32%'));
    expect(card.message, contains(shareDownloadUrl));
    expect(card.message, isNot(contains('kg')));
    expect(shareScreenAction(card.kind).action, UsageScreenAction.shareMeal);
  });

  test('an overage is stated instead of a remaining calorie', () {
    final card = buildMealShareCard(
      summary: summary(
        intake: 2400,
        remaining: -200,
        overage: true,
        overageKcal: 200,
        protein: 0,
        fat: 0,
        carb: 0,
      ),
      day: day,
      format: ShareCardFormat.square,
    );
    expect(card.detail, contains('超えています'));
    expect(card.message, contains('200kcal超えています'));
    expect(card.macros, isNull);
    expect(card.message, contains(shareDownloadUrl));
  });

  test('streak counts recorded days and skips a health-only weight', () {
    final today = DateTime(2026, 10, 6, 12);
    final days = {
      DateTime(2026, 10, 6),
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 4),
    };
    expect(recordingStreakLength(days, today), 3);
    expect(
      recordingStreakLength({
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 4),
      }, today),
      2,
    );
    expect(recordingStreakLength({DateTime(2026, 10, 4)}, today), 0);

    final streak = currentRecordingStreakDays(
      foodLoggedAts: [DateTime(2026, 10, 6, 8)],
      exerciseLoggedAts: const [],
      alcoholConsumedAts: const [],
      weightEntries: [
        WeightEntry(
          id: 'health',
          weightKg: 70,
          recordedAt: DateTime(2026, 10, 5, 7),
          source: WeightSource.health,
        ),
      ],
      now: today,
    );
    expect(streak, 1);

    final card = buildStreakShareCard(
      days: 7,
      day: day,
      format: ShareCardFormat.square,
    );
    expect(card.headline, '7');
    expect(card.message, contains('7日連続'));
    expect(card.message, contains(shareDownloadUrl));
    expect(card.message, isNot(contains('kg')));
    expect(shareScreenAction(card.kind).screen, UsageScreen.home);
  });

  test('weight share can hide the numbers in both the card and the text', () {
    const weights = [80.0, 79.2, 78.4];
    final shown = buildWeightShareCard(
      periodLabel: '1ヶ月',
      weightsKg: weights,
      privacy: WeightPrivacy.shown,
      day: day,
      format: ShareCardFormat.square,
    );
    expect(shown.headline, '1.6');
    expect(shown.detail, '1ヶ月で減りました');
    expect(shown.trend, weights);
    expect(shown.message, contains('1.6kg減りました'));
    expect(shown.message, isNot(contains('80')));
    expect(shown.message, isNot(contains('78.4')));
    expect(shown.message, contains(shareDownloadUrl));

    final blurred = buildWeightShareCard(
      periodLabel: '1ヶ月',
      weightsKg: weights,
      privacy: WeightPrivacy.blurred,
      day: day,
      format: ShareCardFormat.story,
    );
    expect(blurred.privacy, WeightPrivacy.blurred);
    expect(blurred.message, isNot(contains('1.6')));
    expect(blurred.message, isNot(contains('kg')));
    expect(RegExp(r'\d').hasMatch(blurred.message), isFalse);

    final hidden = buildWeightShareCard(
      periodLabel: '1ヶ月',
      weightsKg: weights,
      privacy: WeightPrivacy.hidden,
      day: day,
      format: ShareCardFormat.square,
    );
    expect(hidden.headline, '非公開');
    expect(hidden.trend, isNull);
    expect(hidden.unit, isEmpty);
    expect(RegExp(r'\d').hasMatch(hidden.message), isFalse);
    expect(hidden.message, contains(shareDownloadUrl));
    expect(
      shareScreenAction(hidden.kind).action,
      UsageScreenAction.shareWeight,
    );
  });
}
