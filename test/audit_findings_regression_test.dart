import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/database/entity_mapper.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/exercise_calculation_source.dart';
import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/exercise_quantity_unit.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/screens/settings/settings_goal_screen.dart';
import 'package:ayg/screens/weight/weight_record_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/exercise_duration.dart';
import 'package:ayg/services/health_exercise_credit.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/recent_foods.dart';
import 'package:ayg/services/remaining_calorie_service.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/utils/kcal_display.dart';
import 'package:ayg/utils/nutrition_format.dart';
import 'package:ayg/utils/record_clock.dart';
import 'package:ayg/utils/recorded_number.dart';
import 'package:ayg/utils/saved_food_base_serving_format.dart';
import 'package:ayg/widgets/food/macro_nutrition_input_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weight = 60.0;
  final loggedAt = DateTime(2026, 10, 4, 12);
  final siriContext = SiriVoiceContext(
    paid: true,
    ownerUserId: 'owner',
    foods: const [],
    weightKg: weight,
  );

  group('recorded numbers stay exact', () {
    test('formatRecordedNumber keeps decimals that toStringAsFixed would lose', () {
      expect(formatRecordedNumber(70.14), '70.14');
      expect(formatRecordedNumber(165.4), '165.4');
      expect(double.parse(formatRecordedNumber(71)), 71);
      expect(double.parse(formatRecordedNumber(70.14)), 70.14);
    });

    test('loaded food macros are not rounded in the field', () {
      final macros = MacroNutritionInputController();
      addTearDown(macros.dispose);
      macros.initializeFromNullable(
        kcal: 165.4,
        protein: 12.34,
        fat: 8.1,
        carb: 20.25,
      );
      expect(macros.parseOptional(MacroField.kcal), 165.4);
      expect(macros.parseOptional(MacroField.protein), 12.34);
      expect(macros.parseOptional(MacroField.fat), 8.1);
      expect(macros.parseOptional(MacroField.carb), 20.25);
      expect(macros.kcalController.text, '165.4');
    });

    test('food, exercise, weight, goal, and alcohol survive local and sync', () {
      final food = FoodEntry(
        id: 'food-1',
        name: 'ヨーグルト',
        kcalPerBase: 165.4,
        proteinPerBase: 12.34,
        fatPerBase: 8.1,
        carbPerBase: 20.25,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 45,
        loggedAt: loggedAt,
      );
      final foodEntity = EntityMapper.fromFoodEntryEntity(
        EntityMapper.toFoodEntryEntity(food),
      );
      final foodRow = FoodMasterRowMapper.foodEntryToRow(food, userId: 'u1');
      final foodRemote = FoodMasterRowMapper.foodEntryFromRow(foodRow);
      for (final restored in [foodEntity, foodRemote]) {
        expect(restored.kcalPerBase, 165.4);
        expect(restored.proteinPerBase, 12.34);
        expect(restored.fatPerBase, 8.1);
        expect(restored.carbPerBase, 20.25);
        expect(restored.baseAmount, 100);
        expect(restored.consumedAmount, 45);
        expect(restored.totalKcal, food.totalKcal);
      }

      final exercise = ExerciseEntry(
        id: 'ex-1',
        name: 'ジョギング',
        durationMin: 1,
        burnedKcal: 300,
        loggedAt: loggedAt,
        category: ExerciseCategory.aerobic,
        activityId: 'jogging',
        distanceKm: 5.25,
        grossKcal: 300,
        netKcal: 300,
        weightKgSnapshot: 70.14,
        calculationSource: ExerciseCalculationSource.metEstimate,
      );
      final exerciseEntity = EntityMapper.fromExerciseEntryEntity(
        EntityMapper.toExerciseEntryEntity(exercise),
      );
      final exerciseRemote = ExerciseEntryRowMapper.fromRow(
        ExerciseEntryRowMapper.toRow(exercise, userId: 'u1'),
      );
      for (final restored in [exerciseEntity, exerciseRemote]) {
        expect(restored.distanceKm, 5.25);
        expect(restored.grossKcal, 300);
        expect(restored.netKcal, 300);
        expect(restored.weightKgSnapshot, 70.14);
        expect(restored.durationMin, 1);
        expect(restored.burnedKcal, 300);
      }

      final body = WeightEntry(
        id: 'w-1',
        weightKg: 70.14,
        recordedAt: loggedAt,
        source: WeightSource.manual,
      );
      final weightEntity = EntityMapper.fromWeightEntryEntity(
        EntityMapper.toWeightEntryEntity(body),
      );
      expect(weightEntity.weightKg, 70.14);
      expect(encodeRecordTimestamp(body.recordedAt), isNotEmpty);

      final goal = Goal(
        type: GoalType.maintain,
        targetWeightKg: 70.14,
        targetDate: DateTime(2026, 12, 1),
      );
      final goalEntity = EntityMapper.fromGoalEntity(
        EntityMapper.toGoalEntity(goal),
      );
      expect(goalEntity.targetWeightKg, 70.14);

      final settings = NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
        calorieTargetMode: CalorieTargetMode.manual,
        manualTargetKcal: 1658.5,
        manualProteinG: 100.25,
        manualFatG: 50.5,
        manualCarbG: 200.75,
      );
      final settingsEntity = EntityMapper.fromNutritionSettingsEntity(
        EntityMapper.toNutritionSettingsEntity(settings),
      );
      expect(settingsEntity.manualTargetKcal, 1658.5);
      expect(settingsEntity.manualProteinG, 100.25);
      expect(settingsEntity.manualFatG, 50.5);
      expect(settingsEntity.manualCarbG, 200.75);

      final drink = AlcoholEntry(
        id: 'a-1',
        beverageName: 'ビール',
        amount: 350.5,
        unit: 'ml',
        alcoholPercentage: 5.5,
        totalCalories: 142.8,
        pureAlcoholGrams: 15.25,
        alcoholCalories: 106.75,
        consumedAt: loggedAt,
      );
      final drinkEntity = EntityMapper.fromAlcoholEntryEntity(
        EntityMapper.toAlcoholEntryEntity(drink),
      );
      final drinkRemote = FoodMasterRowMapper.alcoholEntryFromRow(
        FoodMasterRowMapper.alcoholEntryToRow(drink, userId: 'u1'),
      );
      for (final restored in [drinkEntity, drinkRemote]) {
        expect(restored.amount, 350.5);
        expect(restored.alcoholPercentage, 5.5);
        expect(restored.totalCalories, 142.8);
        expect(restored.pureAlcoholGrams, 15.25);
        expect(restored.alcoholCalories, 106.75);
      }
    });
  });

  group('display and barcode and photo', () {
    test('150 with 1食分 is 150食分', () {
      expect(
        SavedFoodBaseServingFormat.joinQuantityAndUnit(150, '1食分'),
        '150食分',
      );
      expect(
        SavedFoodBaseServingFormat.joinQuantityAndUnit(1, '1食分'),
        '1食分',
      );
      final entry = FoodEntry(
        id: 'f',
        name: '弁当',
        kcalPerBase: 500,
        baseAmount: 1,
        unitType: FoodUnitType.serving,
        consumedAmount: 150,
        loggedAt: loggedAt,
      );
      expect(formatFoodAmount(entry), '150食分');
    });

    test('photo 2人前 is two servings and keeps the confirmed total', () {
      final entry = foodEntryFromPhotoMeal(
        id: 'photo',
        name: 'カレー',
        amountText: '2人前',
        kcal: 640.5,
        proteinG: 22.5,
        fatG: 18.2,
        carbG: 80.4,
        loggedAt: loggedAt,
      );
      expect(entry.unitType, FoodUnitType.serving);
      expect(entry.baseAmount, 2);
      expect(entry.consumedAmount, 2);
      expect(entry.totalKcal, 640.5);
      expect(formatFoodAmount(entry), '2食分');
    });

    test('barcode 45g uses per-100g nutrition, not one serving', () {
      expect(OpenFoodFactsService.packageGramsOf('45 g'), 45);
      expect(OpenFoodFactsService.packageGramsOf('45g'), 45);
      expect(OpenFoodFactsService.packageGramsOf('0.045 kg'), 45);
      final parsed = OpenFoodFactsService.parseProductResponse({
        'product': {
          'product_name': 'バー',
          'quantity': '45 g',
          'nutriments': {'energy-kcal_100g': 292},
        },
      });
      expect(parsed!.packageGrams, 45);
      expect(parsed.kcalPerUnit, 292);
      final amount = BarcodeFoodAmount.fromPackage(parsed.packageGrams);
      expect(amount.baseGrams, 100);
      expect(amount.consumedGrams, 45);
      final total = 292 * amount.consumedGrams / amount.baseGrams;
      expect(total, 131.4);
      expect(
        BarcodeFoodAmount.fromPackage(null).consumedGrams,
        100,
      );
    });

    test('day total is the sum of rounded rows', () {
      final foods = [
        FoodEntry(
          id: 'a',
          name: 'a',
          kcalPerBase: 10.4,
          loggedAt: loggedAt,
        ),
        FoodEntry(
          id: 'b',
          name: 'b',
          kcalPerBase: 10.4,
          loggedAt: loggedAt,
        ),
      ];
      expect(displayedIntakeKcal(foods: foods, alcohol: const []), 20);
      expect(formatNullableNutrient(10.4), '10');
      expect(formatNullableNutrient(10.6), '11');
      expect((10.4 + 10.4).round(), 21);
      final exercise = ExerciseEntry(
        id: 'e',
        name: '水泳',
        durationMin: 30,
        burnedKcal: 10.6,
        loggedAt: loggedAt,
        netKcal: 10.6,
      );
      expect(
        displayedBurnKcal(exercises: [exercise], healthExcessKcal: 10.6),
        22,
      );
    });
  });

  group('health credit and coach and weight', () {
    ExerciseEntry manual({
      required String id,
      required DateTime at,
      required int minutes,
      double net = 100,
      String activityId = 'swim_lap',
      double? distanceKm,
    }) {
      return ExerciseEntry(
        id: id,
        name: id,
        durationMin: minutes,
        burnedKcal: net,
        loggedAt: at,
        activityId: activityId,
        distanceKm: distanceKm,
        netKcal: net,
      );
    }

    test('health energy drops only overlapping manuals', () {
      const credit = HealthExerciseCredit();
      final day = DateTime(2026, 10, 4, 12);
      final workout = HealthWorkoutRecord(
        id: 'hw',
        activityType: 'running',
        startTime: DateTime(2026, 10, 4, 8),
        endTime: DateTime(2026, 10, 4, 9),
      );
      final overlap = manual(
        id: 'in',
        at: DateTime(2026, 10, 4, 8, 30),
        minutes: 20,
      );
      final outside = manual(
        id: 'out',
        at: DateTime(2026, 10, 4, 18),
        minutes: 30,
        net: 80,
      );
      final jog = manual(
        id: 'jog',
        at: DateTime(2026, 10, 4, 8, 15),
        minutes: 1,
        net: 300,
        activityId: 'jogging',
        distanceKm: 5,
      );
      final jogLater = manual(
        id: 'jog-later',
        at: DateTime(2026, 10, 4, 19),
        minutes: 1,
        net: 200,
        activityId: 'jogging',
        distanceKm: 4,
      );
      expect(distanceDurationIsPlaceholder(jog), isTrue);

      final withHealth = credit.creditedManualNetKcal(
        healthActiveEnergyPresent: true,
        dayExercises: [overlap, outside, jog, jogLater],
        healthWorkouts: [workout],
      );
      expect(withHealth, 280);

      final noEnergy = credit.creditedManualNetKcal(
        healthActiveEnergyPresent: false,
        dayExercises: [overlap, outside],
        healthWorkouts: [workout],
      );
      expect(noEnergy, 180);

      final noWorkouts = credit.creditedManualNetKcal(
        healthActiveEnergyPresent: true,
        dayExercises: [overlap, outside],
        healthWorkouts: const [],
      );
      expect(noWorkouts, 180);
    });

    test('remaining uses the same overlap rule', () {
      const service = RemainingCalorieService();
      final day = DateTime(2026, 10, 4);
      final breakdown = service.calculateBreakdown(
        baseDailyFoodTargetKcal: 2000,
        foodEntries: const [],
        alcoholEntries: const [],
        exerciseEntries: [
          ExerciseEntry(
            id: 'in',
            name: '水泳',
            durationMin: 30,
            burnedKcal: 100,
            loggedAt: DateTime(2026, 10, 4, 8, 15),
            netKcal: 100,
          ),
          ExerciseEntry(
            id: 'out',
            name: '水泳',
            durationMin: 30,
            burnedKcal: 40,
            loggedAt: DateTime(2026, 10, 4, 20),
            netKcal: 40,
          ),
        ],
        selectedDay: day,
        healthActivityExcessKcal: 250,
        healthActiveEnergyPresent: true,
        healthWorkouts: [
          HealthWorkoutRecord(
            id: 'hw',
            activityType: 'swim',
            startTime: DateTime(2026, 10, 4, 8),
            endTime: DateTime(2026, 10, 4, 9),
          ),
        ],
      );
      expect(breakdown.exerciseNetKcal, 40);
      expect(breakdown.healthActivityExcessKcal, 250);
    });

    test('jogging with a placeholder minute is coached in kilometers', () {
      final proposal = buildCoachExerciseProposal(
        overageKcal: 400,
        weightKg: 60,
        exercises: [
          ExerciseEntry(
            id: 'jog',
            name: 'ジョギング',
            durationMin: 1,
            burnedKcal: 300,
            loggedAt: DateTime(2026, 10, 3, 12),
            activityId: 'jogging',
            distanceKm: 5,
            netKcal: 300,
            grossKcal: 300,
          ),
        ],
        now: DateTime(2026, 10, 4, 12),
      );
      expect(proposal, isNotNull);
      expect(proposal!.unit, CoachExerciseUnit.kilometers);
      expect(proposal.amount, 6.7);
      expect(proposal.message, contains('ジョギング6.7km'));
      expect(proposal.message, contains('約402kcal'));
      expect(proposal.message, isNot(contains('分')));
      final saved = coachExerciseEntry(
        proposal: proposal,
        amount: proposal.amount!,
        weightKg: 60,
        id: 'today',
        loggedAt: loggedAt,
      );
      expect(saved!.distanceKm, 6.7);
      expect(saved.durationMin, 1);
      expect(saved.netKcal, 402);
    });

    test('latest weight record beats the profile for exercise math', () {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.female,
        heightCm: 160,
        weightKg: 55,
      );
      controller.weightEntries.add(
        WeightEntry(
          id: 'latest',
          weightKg: 70.14,
          recordedAt: DateTime.now().subtract(const Duration(hours: 2)),
          source: WeightSource.manual,
        ),
      );
      expect(controller.exerciseWeightKg, 70.14);
    });
  });

  group('every activity uses its calculation unit', () {
    test('form prompt, Siri, widget, and coach follow the catalog unit', () {
      final mismatches = <String>[];
      expect(MetActivityCatalog.activities, isNotEmpty);
      var reps = 0;
      for (final activity in MetActivityCatalog.activities) {
        final prompt = exerciseQuantityPrompt(activity.quantityUnit);
        final expectedPrompt = switch (activity.quantityUnit) {
          ExerciseQuantityUnit.distanceKm => '距離（km）',
          ExerciseQuantityUnit.durationMin => '実施時間（分）',
          ExerciseQuantityUnit.reps => '回数',
        };
        if (prompt != expectedPrompt) {
          mismatches.add('${activity.id} prompt $prompt');
        }
        if (activity.quantityUnit == ExerciseQuantityUnit.reps) {
          reps++;
        }

        final siriReady = activity.searchable &&
            !activity.requiresManualKcal &&
            activity.quantityUnit != ExerciseQuantityUnit.reps;
        if (!siriReady) {
          expect(
            buildSiriExerciseEntry(
              id: activity.id,
              activityId: activity.id,
              amount: 30,
              unit: SiriQuantityUnit.minutes,
              weightKg: weight,
              loggedAt: loggedAt,
            ),
            isNull,
            reason: activity.id,
          );
          expect(
            widgetExerciseEntry(
              pattern: WidgetExercisePattern(
                itemId: activity.id,
                activityId: activity.id,
                name: activity.displayName,
                sortOrder: 0,
                durationMin: 30,
              ),
              weightKg: weight,
              id: activity.id,
              loggedAt: loggedAt,
            ),
            activity.requiresManualKcal ? isNull : isNotNull,
            reason: activity.id,
          );
          expect(
            coachExerciseEntry(
              proposal: CoachExerciseProposal(
                message: 'test',
                activityId: activity.id,
                amount: 20,
                unit: CoachExerciseUnit.minutes,
              ),
              amount: 20,
              weightKg: weight,
              id: activity.id,
              loggedAt: loggedAt,
            ),
            isNull,
            reason: activity.id,
          );
          continue;
        }

        if (activity.quantityUnit == ExerciseQuantityUnit.distanceKm) {
          final asked = _speak(activity, '30分', siriContext);
          if (asked.status != SiriVoiceStatus.needsAmount ||
              !asked.spoken.contains('何km')) {
            mismatches.add(
              '${activity.id} siri-minutes ${asked.status} ${asked.spoken}',
            );
          } else {
            final answered = resolveSiriAmount(
              context: siriContext,
              plan: asked,
              amountText: '5',
            );
            if (answered.quantity?.unit != SiriQuantityUnit.kilometers ||
                answered.quantity?.amount != 5) {
              mismatches.add('${activity.id} siri-answer $answered');
            }
          }
          final built = buildSiriExerciseEntry(
            id: activity.id,
            activityId: activity.id,
            amount: 5,
            unit: SiriQuantityUnit.kilometers,
            weightKg: weight,
            loggedAt: loggedAt,
          );
          if (built?.distanceKm != 5) {
            mismatches.add('${activity.id} siri-distance ${built?.distanceKm}');
          }
          final minutesOnly = buildSiriExerciseEntry(
            id: activity.id,
            activityId: activity.id,
            amount: 30,
            unit: SiriQuantityUnit.minutes,
            weightKg: weight,
            loggedAt: loggedAt,
          );
          if (minutesOnly != null) {
            mismatches.add('${activity.id} siri accepted minutes');
          }
          final widgetEntry = widgetExerciseEntry(
            pattern: WidgetExercisePattern(
              itemId: activity.id,
              activityId: activity.id,
              name: activity.displayName,
              sortOrder: 0,
              distanceKm: 3.5,
            ),
            weightKg: weight,
            id: activity.id,
            loggedAt: loggedAt,
          );
          if (widgetEntry?.distanceKm != 3.5) {
            mismatches.add('${activity.id} widget distance');
          }
          final coached = coachExerciseEntry(
            proposal: CoachExerciseProposal(
              message: 'test',
              activityId: activity.id,
              amount: 3.5,
              unit: CoachExerciseUnit.kilometers,
            ),
            amount: 3.5,
            weightKg: weight,
            id: activity.id,
            loggedAt: loggedAt,
          );
          if (coached?.distanceKm != 3.5) {
            mismatches.add('${activity.id} coach km');
          }
          final minuteCoach = coachExerciseEntry(
            proposal: CoachExerciseProposal(
              message: 'test',
              activityId: activity.id,
              amount: 30,
              unit: CoachExerciseUnit.minutes,
              paceKmh: activity.referenceSpeedKmh,
            ),
            amount: 30,
            weightKg: weight,
            id: activity.id,
            loggedAt: loggedAt,
          );
          if (activity.referenceSpeedKmh == null && minuteCoach != null) {
            mismatches.add('${activity.id} coach invented a duration');
          }
        } else {
          final planned = _speak(activity, '30分', siriContext);
          if (planned.status != SiriVoiceStatus.ready ||
              planned.quantity?.unit != SiriQuantityUnit.minutes ||
              planned.quantity?.amount != 30) {
            mismatches.add(
              '${activity.id} siri-min ${planned.status} ${planned.spoken}',
            );
          }
          final wrong = _speak(activity, '3km', siriContext);
          if (wrong.status != SiriVoiceStatus.unsupportedAmount) {
            mismatches.add('${activity.id} siri-km ${wrong.status}');
          }
          final built = buildSiriExerciseEntry(
            id: activity.id,
            activityId: activity.id,
            amount: 30,
            unit: SiriQuantityUnit.minutes,
            weightKg: weight,
            loggedAt: loggedAt,
          );
          if (built == null || built.durationMin != 30 || built.distanceKm != null) {
            mismatches.add('${activity.id} siri duration');
          }
          final widgetEntry = widgetExerciseEntry(
            pattern: WidgetExercisePattern(
              itemId: activity.id,
              activityId: activity.id,
              name: activity.displayName,
              sortOrder: 0,
              durationMin: 25,
            ),
            weightKg: weight,
            id: activity.id,
            loggedAt: loggedAt,
          );
          if (widgetEntry == null ||
              widgetEntry.durationMin != 25 ||
              widgetEntry.distanceKm != null) {
            mismatches.add('${activity.id} widget minutes');
          }
          if (activity.lifestyleIncluded) {
            if (built!.netKcal != 0 || widgetEntry!.netKcal != 0) {
              mismatches.add('${activity.id} lifestyle kcal');
            }
            expect(
              coachExerciseEntry(
                proposal: CoachExerciseProposal(
                  message: 'test',
                  activityId: activity.id,
                  amount: 20,
                  unit: CoachExerciseUnit.minutes,
                ),
                amount: 20,
                weightKg: weight,
                id: activity.id,
                loggedAt: loggedAt,
              ),
              isNull,
              reason: activity.id,
            );
          } else {
            final coached = coachExerciseEntry(
              proposal: CoachExerciseProposal(
                message: 'test',
                activityId: activity.id,
                amount: 25,
                unit: CoachExerciseUnit.minutes,
                met: activity.defaultMet,
              ),
              amount: 25,
              weightKg: weight,
              id: activity.id,
              loggedAt: loggedAt,
            );
            if (coached == null ||
                coached.durationMin != 25 ||
                coached.distanceKm != null) {
              mismatches.add('${activity.id} coach minutes');
            }
          }
        }
      }
      expect(reps, 0, reason: 'catalog has no reps activities');
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });
  });

  group('screens keep recorded numbers', () {
    testWidgets('weight reopen and save keeps 70.14', (tester) async {
      final repo = _MemoryWeights();
      final controller = AppController(weightRepository: repo);
      addTearDown(controller.dispose);
      final entry = WeightEntry(
        id: 'w-screen',
        weightKg: 70.14,
        recordedAt: DateTime(2026, 10, 1, 8),
        source: WeightSource.manual,
      );
      controller.weightEntries.add(entry);

      await tester.pumpWidget(
        MaterialApp(
          home: WeightRecordScreen(controller: controller, entry: entry),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('70.14'), findsWidgets);

      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(controller.weightEntries.single.weightKg, 70.14);
      expect(repo.items.single.weightKg, 70.14);
    });

    testWidgets('goal reopen and save keeps weight and manual kcal', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70.14,
      );
      controller.goal = Goal(
        type: GoalType.maintain,
        targetWeightKg: 70.14,
        targetDate: DateTime(2027, 1, 1),
      );
      controller.nutritionSettings = const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
        calorieTargetMode: CalorieTargetMode.manual,
        manualTargetKcal: 1658.5,
        manualProteinG: 100.25,
        manualFatG: 50.5,
        manualCarbG: 200.75,
      );

      await tester.pumpWidget(
        MaterialApp(home: SettingsGoalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('70.14'), findsWidgets);
      expect(find.text('1658.5'), findsWidgets);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(controller.goal!.targetWeightKg, 70.14);
      expect(controller.nutritionSettings!.manualTargetKcal, 1658.5);
      expect(controller.nutritionSettings!.manualProteinG, 100.25);
      expect(controller.nutritionSettings!.manualFatG, 50.5);
      expect(controller.nutritionSettings!.manualCarbG, 200.75);
    });
  });
}

/// 表示名が記号で外れる種目は、別名のどれかで同じ種目に届くこと。
SiriVoicePlan _speak(
  MetActivityDefinition activity,
  String quantity,
  SiriVoiceContext context,
) {
  SiriVoicePlan? first;
  SiriVoicePlan? rejected;
  for (final raw in [activity.displayName, ...activity.aliases]) {
    final name = raw.trim();
    if (name.isEmpty) {
      continue;
    }
    final plan = planSiriExercise(
      context: context,
      name: name,
      quantity: quantity,
    );
    first ??= plan;
    if (plan.activityId == activity.id) {
      return plan;
    }
    if (plan.status == SiriVoiceStatus.unsupportedAmount && rejected == null) {
      rejected = plan;
    }
  }
  return rejected ?? first!;
}

class _MemoryWeights implements WeightRepositoryBase {
  final items = <WeightEntry>[];

  @override
  Future<void> clearAll() async => items.clear();

  @override
  Future<void> delete(String entryId) async {
    items.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async {
    if (items.isEmpty) {
      return null;
    }
    return items.last.weightKg;
  }

  @override
  Future<List<WeightEntry>> loadAll() async => List.of(items);

  @override
  Future<List<WeightRecord>> loadWeightRecords() async =>
      items.map(weightEntryToRecord).toList();

  @override
  Future<void> save(WeightEntry entry) async {
    items.removeWhere((item) => item.id == entry.id);
    items.add(entry);
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {
    await save(weightEntryFromRecord(record));
  }
}
