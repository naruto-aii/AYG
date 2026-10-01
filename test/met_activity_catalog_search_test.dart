import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/models/exercise_quantity_unit.dart';
import 'package:ayg/services/exercise_calorie_calculator.dart';
import 'package:ayg/utils/food_search_normalizer.dart';
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

  test('blank query stays out of alias search and the list shows prepared activities', () {
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
  });

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

  test('short token らん is not inside another activity alias', () {
    for (final activity in MetActivityCatalog.activities) {
      if (activity.id == 'running') {
        continue;
      }
      for (final alias in activity.aliases) {
        expect(
          FoodSearchNormalizer.normalize(alias).contains('らん'),
          isFalse,
          reason: '${activity.id} $alias',
        );
      }
    }
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

    final squat = calculator.estimateByReps(met: 5, weightKg: 70, reps: 15);
    final repMinutes = 15 * 4 / 60;
    final expectedSquat = (5 - 1) * 3.5 * 70 / 200 * repMinutes;
    expect(squat!.netKcal, closeTo(expectedSquat, 0.001));
    expect(squat.calculationVersion, 'exercise_reps_v1');
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
      ExerciseQuantityUnit.reps,
    );
    expect(MetActivityCatalog.findById('housework')?.lifestyleIncluded, isTrue);
    expect(MetActivityCatalog.findById('cleaning')?.lifestyleIncluded, isTrue);
    expect(MetActivityCatalog.findById('soccer')?.calorieFormula, isNotNull);
    expect(MetActivityCatalog.findById('soccer')?.requiresManualKcal, isFalse);
    expect(MetActivityCatalog.findById('squat')?.requiresManualKcal, isTrue);
    expect(MetActivityCatalog.findById('squat')?.calorieFormula, isNull);
    expect(
      MetActivityCatalog.findById('bench_press')?.requiresManualKcal,
      isTrue,
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
}
