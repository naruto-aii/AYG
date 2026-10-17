import 'dart:convert';

import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/services/exercise_calorie_calculator.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// Siri の運動は会話で選んだきつさを記録に残し、アプリの取り込みもそのきつさで計算する。
void main() {
  final loggedAt = DateTime(2026, 10, 8, 7, 0);
  const calculator = ExerciseCalorieCalculator();

  MetActivityDefinition activity(String id) => MetActivityCatalog.findById(id)!;

  MetIntensityOption hardest(MetActivityDefinition definition) {
    final options = [...definition.intensityOptions]
      ..sort((a, b) => a.met.compareTo(b.met));
    return options.last;
  }

  Map<String, Object?> pendingExercise({
    required String activityId,
    required double amount,
    required String unit,
    String? intensityId,
    String id = 'siri-ex-1',
  }) {
    return {
      'kind': 'exercise',
      'id': id,
      'ownerUserId': 'user-1',
      'loggedAt': '2026-10-08T07:00:00.000',
      'activityId': activityId,
      if (intensityId != null) 'intensityId': intensityId,
      'amount': amount,
      'quantityUnit': unit,
      'weightKg': 60.0,
    };
  }

  SiriVoiceImportPlan decode(List<Map<String, Object?>> rows) {
    return SiriVoiceCodec.decodePending(
      raw: jsonEncode(rows),
      ownerUserId: 'user-1',
      existingFoodIds: const {},
      existingExerciseIds: const {},
    );
  }

  test('the import uses the intensity chosen in the Siri conversation', () {
    final swim = activity('swim_lap');
    final chosen = hardest(swim);
    expect(chosen.id, isNot(swim.defaultIntensityId));

    final imported = decode([
      pendingExercise(
        activityId: 'swim_lap',
        amount: 30,
        unit: 'minutes',
        intensityId: chosen.id,
      ),
    ]);

    final entry = imported.exercises.single;
    final expected = calculator.estimate(
      met: chosen.met,
      weightKg: 60,
      durationMinutes: 30,
    )!;
    expect(entry.intensity, chosen.id);
    expect(entry.metValue, chosen.met);
    expect(entry.sourceKey, chosen.sourceKey);
    expect(entry.netKcal, closeTo(expected.netKcal, 0.001));
    expect(entry.grossKcal, closeTo(expected.grossKcal, 0.001));
    expect(entry.durationMin, 30);
  });

  test('an old record without an intensity falls back to the default', () {
    final swim = activity('swim_lap');
    final imported = decode([
      pendingExercise(activityId: 'swim_lap', amount: 30, unit: 'minutes'),
    ]);

    final entry = imported.exercises.single;
    expect(entry.intensity, swim.defaultIntensityId);
    expect(entry.metValue, swim.defaultMet);
    final expected = calculator.estimate(
      met: swim.defaultMet,
      weightKg: 60,
      durationMinutes: 30,
    )!;
    expect(entry.netKcal, closeTo(expected.netKcal, 0.001));
  });

  test('an intensity id that the activity does not have uses the default', () {
    final swim = activity('swim_lap');
    final imported = decode([
      pendingExercise(
        activityId: 'swim_lap',
        amount: 30,
        unit: 'minutes',
        intensityId: 'not-a-code',
      ),
    ]);
    expect(imported.exercises.single.intensity, swim.defaultIntensityId);
    expect(imported.exercises.single.metValue, swim.defaultMet);
  });

  test('a cycling distance uses the speed of the chosen intensity', () {
    final bike = activity('cycle_road');
    final chosen = hardest(bike);
    expect(chosen.referenceSpeedKmh, isNotNull);
    expect(chosen.referenceSpeedKmh, isNot(bike.referenceSpeedKmh));

    final imported = decode([
      pendingExercise(
        activityId: 'cycle_road',
        amount: 10,
        unit: 'kilometers',
        intensityId: chosen.id,
      ),
    ]);

    final entry = imported.exercises.single;
    final expected = calculator.estimateByDistanceSpeed(
      met: chosen.met,
      weightKg: 60,
      distanceKm: 10,
      speedKmh: chosen.referenceSpeedKmh!,
    )!;
    expect(entry.intensity, chosen.id);
    expect(entry.metValue, chosen.met);
    expect(entry.distanceKm, 10);
    expect(entry.netKcal, closeTo(expected.netKcal, 0.001));
    expect(
      entry.durationMin,
      ExerciseCalorieCalculator.companionDurationMin(
        distanceKm: 10,
        referenceSpeedKmh: chosen.referenceSpeedKmh,
      ),
    );
  });

  test('pending json keeps the intensity through encode and decode', () {
    final swim = activity('swim_lap');
    final chosen = hardest(swim);
    final built = buildSiriExerciseEntry(
      id: 'siri-ex-2',
      activityId: 'swim_lap',
      amount: 20,
      unit: SiriQuantityUnit.minutes,
      weightKg: 60,
      loggedAt: loggedAt,
      intensityId: chosen.id,
    )!;
    final raw = SiriVoiceCodec.encodePending(
      ownerUserId: 'user-1',
      exercise: built,
      weightKg: 60,
    );
    final row = (jsonDecode(raw) as List).single as Map;
    expect(row['intensityId'], chosen.id);

    final imported = SiriVoiceCodec.decodePending(
      raw: raw,
      ownerUserId: 'user-1',
      existingFoodIds: const {},
      existingExerciseIds: const {},
    );
    expect(imported.exercises.single.intensity, chosen.id);
    expect(imported.exercises.single.netKcal, closeTo(built.netKcal!, 0.001));
  });

  test('the Siri catalog lists each activity\'s intensities', () {
    final raw = SiriVoiceCodec.encodeCatalog(
      ownerUserId: 'user-1',
      weightKg: 60,
      officialFoodsEnabled: false,
      supabaseUrl: '',
      supabaseAnonKey: '',
      foods: const [],
      workoutTemplates: const [
        SiriWorkoutTemplate(
          id: 'work-1',
          speakName: '朝の運動',
          keys: ['朝の運動'],
          exercises: [
            SiriWorkoutTemplateExercise(
              activityId: 'swim_lap',
              minutes: 20,
              intensityId: '18292',
            ),
          ],
        ),
      ],
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final activities = (json['activities'] as List).cast<Map>();
    final swimJson = activities.firstWhere((row) => row['id'] == 'swim_lap');
    final swim = activity('swim_lap');
    expect(swimJson['defaultIntensityId'], swim.defaultIntensityId);
    final intensities = (swimJson['intensities'] as List).cast<Map>();
    expect(intensities, hasLength(swim.intensityOptions.length));
    expect(
      intensities.map((row) => row['label']).toList(),
      swim.intensityOptions.map((option) => option.label).toList(),
    );
    expect(
      intensities.map((row) => row['met']).toList(),
      swim.intensityOptions.map((option) => option.met).toList(),
    );

    final bikeJson = activities.firstWhere((row) => row['id'] == 'cycle_road');
    final bikeSpeeds = (bikeJson['intensities'] as List).cast<Map>().map(
      (row) => row['speedKmh'],
    );
    expect(bikeSpeeds.every((speed) => speed is num && speed > 0), isTrue);
    expect(
      bikeJson['referenceSpeedKmh'],
      activity('cycle_road').referenceSpeedKmh,
    );

    final template = (json['workoutTemplates'] as List).single as Map;
    final item = (template['exercises'] as List).single as Map;
    expect(item['intensityId'], '18292');
  });

  test('a workout template registers with its saved intensity', () {
    final swim = activity('swim_lap');
    final chosen = hardest(swim);
    final routine = SiriWorkoutTemplate(
      id: 'work-1',
      speakName: '朝の運動',
      keys: const ['朝の運動', 'あさのうんどう'],
      exercises: [
        SiriWorkoutTemplateExercise(
          activityId: 'swim_lap',
          minutes: 20,
          intensityId: chosen.id,
        ),
      ],
    );
    final plan = planSiriExercise(
      context: SiriVoiceContext(
        paid: true,
        ownerUserId: 'user-1',
        weightKg: 60,
        foods: const [],
        workoutTemplates: [routine],
      ),
      name: '朝の運動',
      quantity: '',
    );
    final saved = commitSiriVoice(
      plan: plan,
      answer: SiriAnswer.yes,
      loggedAt: loggedAt,
      ownerUserId: 'user-1',
      weightKg: 60,
      newId: () => 'id-1',
    );
    expect(saved.exercises.single.intensity, chosen.id);
    expect(saved.exercises.single.metValue, chosen.met);
  });
}
