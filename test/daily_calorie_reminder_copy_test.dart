import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/services/daily_calorie_reminder_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('running distance uses the catalog factor of 1 kcal per kg per km', () {
    expect(MetActivityCatalog.findById('running')?.netKcalPerKgKm, 1.0);
  });

  test('no meal and no exercise uses the registration message', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 0,
        exerciseCount: 0,
        goalFoodTargetKcal: 1800,
        intakeKcal: 400,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      DailyCalorieReminderCopy.noRecords,
    );
    expect(
      DailyCalorieReminderCopy.noRecords,
      '今日の食事、運動が登録されてません！今のうちに登録しましょう！',
    );
  });

  test('alcohol alone does not count as a meal or an exercise', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 0,
        exerciseCount: 0,
        goalFoodTargetKcal: 1800,
        intakeKcal: 250,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      DailyCalorieReminderCopy.noRecords,
    );
  });

  test('remaining kcal uses the home ring rounding', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 1,
        exerciseCount: 0,
        goalFoodTargetKcal: 2000,
        intakeKcal: 500,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      '今日あと1500kcal食べられます！',
    );
    expect(DailyCalorieReminderCopy.roundKcal(10.5), 11);
    expect(DailyCalorieReminderCopy.roundKcal(10.4), 10);
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 1,
        exerciseCount: 0,
        goalFoodTargetKcal: 100,
        intakeKcal: 89.5,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      '今日あと11kcal食べられます！',
    );
  });

  test('zero remaining still says how much is left', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 1,
        exerciseCount: 0,
        goalFoodTargetKcal: 500,
        intakeKcal: 500,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 55,
      ),
      '今日あと0kcal食べられます！',
    );
  });

  test('exercise without a meal uses the remaining message', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 0,
        exerciseCount: 1,
        goalFoodTargetKcal: 1800,
        intakeKcal: 0,
        exerciseNetKcal: 200,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      '今日あと2000kcal食べられます！',
    );
  });

  test('health excess is part of the remaining kcal', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 2,
        exerciseCount: 0,
        goalFoodTargetKcal: 2000,
        intakeKcal: 1800,
        exerciseNetKcal: 0,
        healthExcessKcal: 100,
        weightKg: 60,
      ),
      '今日あと300kcal食べられます！',
    );
  });

  test('overage distance follows the running model and one decimal', () {
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 1,
        exerciseCount: 0,
        goalFoodTargetKcal: 500,
        intakeKcal: 680,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 70,
      ),
      '今日は180kcalオーバーしてます！2.6kmランニングすればチャラにできますよ！',
    );
  });

  test('positive excess never shows less than 0.1 km', () {
    expect(
      DailyCalorieReminderCopy.runningKilometers(excessKcal: 1, weightKg: 60),
      '0.1',
    );
    expect(
      DailyCalorieReminderCopy.build(
        mealCount: 1,
        exerciseCount: 0,
        goalFoodTargetKcal: 100,
        intakeKcal: 101,
        exerciseNetKcal: 0,
        healthExcessKcal: 0,
        weightKg: 60,
      ),
      '今日は1kcalオーバーしてます！0.1kmランニングすればチャラにできますよ！',
    );
  });

  test('missing weight uses the 60 kg fallback for distance only', () {
    expect(
      DailyCalorieReminderCopy.runningKilometers(excessKcal: 60, weightKg: 0),
      '1.0',
    );
    expect(DailyCalorieReminderCopy.fallbackWeightKg, 60);
  });

  test('a meal logged after the previous inputs changes the sentence', () {
    const before = 0;
    final first = DailyCalorieReminderCopy.build(
      mealCount: before,
      exerciseCount: 0,
      goalFoodTargetKcal: 1800,
      intakeKcal: 0,
      exerciseNetKcal: 0,
      healthExcessKcal: 0,
      weightKg: 62,
    );
    final afterMeal = DailyCalorieReminderCopy.build(
      mealCount: 1,
      exerciseCount: 0,
      goalFoodTargetKcal: 1800,
      intakeKcal: 450,
      exerciseNetKcal: 0,
      healthExcessKcal: 0,
      weightKg: 62,
    );
    expect(first, DailyCalorieReminderCopy.noRecords);
    expect(afterMeal, '今日あと1350kcal食べられます！');
  });

  test('denied permission is not asked again and does not upload a token', () {
    expect(
      dailyReminderShouldRequest(status: 'denied', requestIfNeeded: true),
      isFalse,
    );
    expect(dailyReminderShouldUploadToken('denied'), isFalse);
    expect(
      dailyReminderShouldRequest(
        status: 'notDetermined',
        requestIfNeeded: false,
      ),
      isFalse,
    );
    expect(
      dailyReminderShouldRequest(
        status: 'notDetermined',
        requestIfNeeded: true,
      ),
      isTrue,
    );
    expect(dailyReminderShouldUploadToken('authorized'), isTrue);
  });
}
