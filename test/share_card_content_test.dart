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

  test('meal text keeps the gap, the balance, the tagline, and the link', () {
    final card = buildMealShareCard(
      summary: summary(exercise: 320),
      day: day,
    );
    expect(card.headline, '1,820');
    expect(card.detail, '目標まであと 180kcal');
    expect(card.message, '''
今日の食事は1,820 kcalで、目標まであと180kcalです。
たんぱく質32%、脂質29%、炭水化物39%です。
${AppStrings.loginTagline}
$shareDownloadUrl''');
    expect(card.message, isNot(contains('運動で')));
    expect(card.message, isNot(contains('320')));
    expect(card.message, isNot(contains('kg')));
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
    );
    expect(card.detail, contains('超えています'));
    expect(card.macros, isNull);
    expect(card.message, contains('200kcal超えています'));
    expect(card.message, contains(AppStrings.loginTagline));
    expect(card.message, contains(shareDownloadUrl));
    expect(card.message, isNot(contains('たんぱく質')));
  });
}
