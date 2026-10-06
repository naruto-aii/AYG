import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/daily_summary.dart';
import 'package:ayg/services/share_card_content.dart';
import 'package:ayg/services/share_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 6);

  DailySummary summary({
    double intake = 1820,
    double remaining = 180,
    double target = 2000,
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
      intakeProteinG: 25,
      intakeFatG: 10,
      intakeCarbG: 30,
      exerciseBurnKcal: exercise,
      isCalorieOverage: overage,
      calorieOverageKcal: overageKcal,
    );
  }

  test('meal text states intake against the goal, then the tagline and link', () {
    final card = buildMealShareCard(
      summary: summary(exercise: 320),
      day: day,
    );
    expect(card.eyebrow, '今日の摂取カロリー');
    expect(card.figure, '1,820 / 2,000');
    expect(card.progress, closeTo(1820 / 2000, 0.0001));
    expect(card.isOverage, isFalse);
    expect(card.message, '''
今日は目標2,000kcalのうち1,820kcalを摂りました。
${AppStrings.loginTagline}
$shareDownloadUrl''');
    expect(card.message.split('\n'), hasLength(3));
    expect(card.message, isNot(contains('たんぱく質')));
    expect(card.message, isNot(contains('目標まで')));
    expect(card.message, isNot(contains('320')));
    expect(card.message, isNot(contains('kg')));
  });

  test('an overage fills the ring and still uses the same sentence', () {
    final card = buildMealShareCard(
      summary: summary(
        intake: 2400,
        remaining: -200,
        overage: true,
        overageKcal: 200,
      ),
      day: day,
    );
    expect(card.figure, '2,400 / 2,000');
    expect(card.progress, 1);
    expect(card.isOverage, isTrue);
    expect(
      card.message,
      startsWith('今日は目標2,000kcalのうち2,400kcalを摂りました。'),
    );
    expect(card.message, contains(AppStrings.loginTagline));
    expect(card.message, contains(shareDownloadUrl));
    expect(card.message, isNot(contains('たんぱく質')));
  });
}
