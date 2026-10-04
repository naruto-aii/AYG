import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/models/exercise_quantity_unit.dart';
import 'package:ayg/services/exercise_calorie_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ExerciseCalorieCalculator();

  test('running aliases all resolve to running only', () {
    const queries = ['走り', 'ランニング', 'らんにんぐ', 'らん', 'ラン', 'run', 'running'];
    for (final query in queries) {
      expect(MetActivityCatalog.search(query).map((activity) => activity.id), [
        'running',
      ], reason: query);
    }
  });

  test('other activities keep their own short names', () {
    expect(MetActivityCatalog.search('歩き').single.id, 'walk_brisk');
    expect(MetActivityCatalog.search('ジョグ').single.id, 'jogging');
    expect(MetActivityCatalog.search('バスケ').single.id, 'basketball');
    expect(MetActivityCatalog.search('soccer').single.id, 'soccer');
    expect(MetActivityCatalog.search('サッカー').single.id, 'soccer');
    expect(MetActivityCatalog.search('ヨガ').single.id, 'yoga');
    expect(MetActivityCatalog.search('ストレッチ').single.id, 'stretch');
    expect(MetActivityCatalog.search('掃除').single.id, 'cleaning');
    expect(MetActivityCatalog.search('家事').single.id, 'housework');
  });

  test(
    'blank query stays out of alias search and the list shows prepared activities',
    () {
      expect(MetActivityCatalog.search(''), isEmpty);
      expect(MetActivityCatalog.search('   '), isEmpty);
      final listed = MetActivityCatalog.listed.map((activity) => activity.id);
      expect(listed, contains('running'));
      expect(listed, contains('soccer'));
      expect(listed, isNot(contains('custom')));
      expect(
        listed.length,
        MetActivityCatalog.activities
            .where((activity) => activity.searchable)
            .length,
      );
    },
  );

  test('custom is outside alias search', () {
    expect(MetActivityCatalog.search('その他'), isEmpty);
    expect(MetActivityCatalog.search('手入力'), isEmpty);
    expect(MetActivityCatalog.findById('custom')?.searchable, isFalse);
  });

  test('every searchable activity has readings in each script', () {
    for (final activity in MetActivityCatalog.activities) {
      if (!activity.searchable) {
        continue;
      }
      final joined = activity.aliases.join(' ');
      expect(joined, contains(RegExp(r'[\u3041-\u3096]')), reason: activity.id);
      expect(joined, contains(RegExp(r'[\u30A1-\u30FA]')), reason: activity.id);
      expect(joined, contains(RegExp(r'[A-Za-z]')), reason: activity.id);
      expect(activity.aliases, contains(activity.displayName));
    }
  });

  test('short token らん stays on running', () {
    expect(MetActivityCatalog.search('らん').map((activity) => activity.id), [
      'running',
    ]);
    expect(MetActivityCatalog.search('水中ラン').single.id, 'water_jogging');
  });

  test('split names are separate activities', () {
    expect(MetActivityCatalog.findById('running')?.displayName, 'ランニング');
    expect(MetActivityCatalog.findById('jogging')?.displayName, 'ジョギング');
    expect(MetActivityCatalog.findById('yoga')?.displayName, 'ヨガ');
    expect(MetActivityCatalog.findById('stretch')?.displayName, 'ストレッチ');
    expect(MetActivityCatalog.findById('housework')?.displayName, '家事');
    expect(MetActivityCatalog.findById('cleaning')?.displayName, '掃除');
    expect(MetActivityCatalog.search('サッカー'), isNotEmpty);
    expect(MetActivityCatalog.findById('run_jog')?.id, 'running');
  });

  test('distance and rep formulas use published factors', () {
    final walk = calculator.estimateByDistanceFactor(
      weightKg: 70,
      distanceKm: 5,
      netKcalPerKgKm: 0.5,
    );
    expect(walk!.netKcal, closeTo(175, 0.001));

    final run = calculator.estimateByDistanceFactor(
      weightKg: 70,
      distanceKm: 5,
      netKcalPerKgKm: 1,
    );
    expect(run!.netKcal, closeTo(350, 0.001));

    final cycle = calculator.estimateByDistanceSpeed(
      met: 6.8,
      weightKg: 70,
      distanceKm: 10,
      speedKmh: 16.09344,
    );
    final minutes = 10 / 16.09344 * 60;
    final expectedNet = (6.8 - 1) * 3.5 * 70 / 200 * minutes;
    expect(cycle!.netKcal, closeTo(expectedNet, 0.001));

    final squat = calculator.estimate(
      met: 5,
      weightKg: 70,
      durationMinutes: 20,
    );
    final expectedSquat = (5 - 1) * 3.5 * 70 / 200 * 20;
    expect(squat!.netKcal, closeTo(expectedSquat, 0.001));
    expect(squat.calculationVersion, 'met-v1');
  });

  test('units follow the activity', () {
    expect(
      MetActivityCatalog.findById('walk_brisk')?.quantityUnit,
      ExerciseQuantityUnit.distanceKm,
    );
    expect(
      MetActivityCatalog.findById('running')?.quantityUnit,
      ExerciseQuantityUnit.distanceKm,
    );
    expect(
      MetActivityCatalog.findById('cycle_road')?.quantityUnit,
      ExerciseQuantityUnit.distanceKm,
    );
    expect(
      MetActivityCatalog.findById('soccer')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
    expect(
      MetActivityCatalog.findById('squat')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
    expect(MetActivityCatalog.findById('housework')?.lifestyleIncluded, isTrue);
    expect(MetActivityCatalog.findById('cleaning')?.lifestyleIncluded, isTrue);
    expect(MetActivityCatalog.findById('housework')?.calorieFormula, isNull);
    expect(MetActivityCatalog.findById('soccer')?.calorieFormula, isNotNull);
    expect(MetActivityCatalog.findById('soccer')?.requiresManualKcal, isFalse);
    expect(MetActivityCatalog.findById('squat')?.requiresManualKcal, isFalse);
    expect(MetActivityCatalog.findById('squat')?.calorieFormula, isNotNull);
    expect(
      MetActivityCatalog.findById('bench_press')?.requiresManualKcal,
      isFalse,
    );
    expect(
      MetActivityCatalog.findById('push_up')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
    expect(MetActivityCatalog.findById('custom')?.requiresManualKcal, isTrue);
    expect(
      MetActivityCatalog.findById('strength_general')?.requiresManualKcal,
      isTrue,
    );
    for (final activity in MetActivityCatalog.automaticCalorieActivities) {
      expect(activity.calorieFormula, isNotEmpty);
      expect(activity.requiresManualKcal, isFalse);
    }
  });

  test('search lists the 28 existing and 87 added activities', () {
    final searchable = MetActivityCatalog.activities.where(
      (activity) => activity.searchable,
    );
    expect(searchable, hasLength(115));
    expect(MetActivityCatalog.findById('run_jog')?.id, 'running');
    expect(
      MetActivityCatalog.findById('strength_machine')?.id,
      'strength_general',
    );
    expect(
      MetActivityCatalog.findById('strength_general')?.searchable,
      isFalse,
    );
  });

  test('intensities keep one option per MET and the compendium text', () {
    for (final activity in MetActivityCatalog.activities.where(
      (activity) => activity.searchable,
    )) {
      final mets = activity.intensityOptions.map((option) => option.met);
      expect(mets.toSet(), hasLength(mets.length), reason: activity.id);
      for (final option in activity.intensityOptions) {
        expect(option.sourceKey, startsWith('compendium_2024_'));
        expect(
          option.id,
          option.sourceKey.replaceFirst('compendium_2024_', ''),
        );
        expect(option.description, isNotEmpty);
        if (activity.lifestyleIncluded) {
          expect(activity.calorieFormula, isNull);
        } else {
          expect(activity.calorieFormula, contains(option.id));
          expect(activity.calorieFormula, contains(option.description));
        }
      }
    }

    final swim = MetActivityCatalog.findById('swim_lap')!;
    expect(swim.defaultIntensityId, '18292');
    expect(swim.intensityOptions.where((option) => option.met == 5.8), [
      swim.intensityById('18292'),
    ]);
    expect(swim.intensityById('18240'), isNull);

    final golf = MetActivityCatalog.findById('golf')!;
    expect(golf.intensityOptions.map((option) => option.met), [3.5, 4.3, 4.5]);
    expect(golf.intensityById('15255')?.met, 4.5);
    expect(golf.intensityById('15285'), isNull);

    final cycle = MetActivityCatalog.findById('cycle_road')!;
    expect(cycle.referenceSpeedKmh, 16.09344);
    expect(
      cycle.intensityById('01018')?.referenceSpeedKmh,
      closeTo(8.851392, 1e-9),
    );
    expect(
      cycle.intensityById('01040')?.referenceSpeedKmh,
      closeTo(22.530816, 1e-6),
    );
    expect(cycle.intensityById('01060'), isNull);

    expect(
      MetActivityCatalog.findById('race_walking')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
    expect(
      MetActivityCatalog.findById('nordic_walking')?.netKcalPerKgKm,
      isNull,
    );
    expect(
      MetActivityCatalog.findById('canoe')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
    expect(
      MetActivityCatalog.findById('ice_skating')?.quantityUnit,
      ExerciseQuantityUnit.durationMin,
    );
  });

  test('search words hit the reported activity and skip thin matches', () {
    expect(MetActivityCatalog.search('ビーチバレー').single.id, 'volleyball');
    expect(MetActivityCatalog.search('MTB').single.id, 'mountain_bike');
    expect(MetActivityCatalog.search('タバタ').single.id, 'hiit');
    expect(MetActivityCatalog.search('フィット').single.id, 'exergame');
    expect(MetActivityCatalog.search('ダンス').single.id, 'dance');
    expect(MetActivityCatalog.search('散歩').single.id, 'dog_walking');
    expect(MetActivityCatalog.search('ボート').map((activity) => activity.id), [
      'canoe',
      'rowing',
    ]);
    expect(MetActivityCatalog.search('パデル'), isEmpty);
    expect(MetActivityCatalog.search('ヒップホップ'), isEmpty);
    expect(MetActivityCatalog.search('リングフィット'), isEmpty);
    expect(MetActivityCatalog.search('料理'), isEmpty);
  });
}
