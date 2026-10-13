import 'dart:async';

import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/local_write_guard.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/layout/active_tab_listenable_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('single-entry saves do not reload every table', () async {
    final foods = _Foods();
    final exercises = _Exercises();
    final alcohols = _Alcohols();
    final weights = _Weights();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      foodRepository: foods,
      exerciseRepository: exercises,
      alcoholRepository: alcohols,
      weightRepository: weights,
    );
    addTearDown(controller.dispose);

    await controller.addFood(_food('meal', DateTime(2026, 10, 1, 8)));
    await controller.updateFood(_food('meal', DateTime(2026, 10, 1, 9)));
    await controller.addExercise(_exercise('run', DateTime(2026, 10, 1, 10)));
    await controller.addAlcohol(_alcohol('beer', DateTime(2026, 10, 1, 11)));
    await controller.recordManualWeight(
      70,
      recordedAt: DateTime(2026, 10, 1, 7),
    );

    expect(foods.loadAllCalls, 0);
    expect(exercises.loadAllCalls, 0);
    expect(alcohols.loadAllCalls, 0);
    expect(weights.loadAllCalls, 0);
    expect(controller.foodEntries.single.loggedAt.hour, 9);
    expect(controller.exerciseEntries.single.id, 'run');
    expect(controller.alcoholEntries.single.id, 'beer');
    expect(controller.weightEntries.single.weightKg, 70);

    await controller.deleteFood('meal');
    await controller.deleteExercise('run');
    await controller.deleteAlcohol('beer');
    await controller.deleteWeightEntry('missing');
    expect(foods.loadAllCalls, 0);
    expect(exercises.loadAllCalls, 0);
    expect(alcohols.loadAllCalls, 0);
    expect(weights.loadAllCalls, 0);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    expect(controller.alcoholEntries, isEmpty);
  });

  test('a second full sync waits until the one in flight finishes', () async {
    final sync = _GatedSync();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'user@example.com'),
      ),
      dataSyncRepository: sync,
      exerciseRepository: _Exercises(),
    );
    addTearDown(controller.dispose);
    await controller.handleAuthenticatedSession();
    sync.pushes = 0;

    final gate = Completer<void>();
    sync.gate = gate;
    await controller.addExercise(_exercise('run', DateTime(2026, 10, 1, 10)));
    expect(sync.pushes, 1);

    await controller.addExercise(_exercise('walk', DateTime(2026, 10, 1, 11)));
    expect(sync.pushes, 1);

    gate.complete();
    await Future<void>.value();
    await Future<void>.value();
    expect(sync.pushes, 2);
    expect(controller.exerciseEntries.map((entry) => entry.id), [
      'walk',
      'run',
    ]);
  });

  testWidgets('a hidden tab does not rebuild when the controller notifies', (
    tester,
  ) async {
    final listenable = ChangeNotifier();
    addTearDown(listenable.dispose);
    var builds = 0;

    await tester.pumpWidget(
      ShellTabActive(
        active: false,
        child: ActiveTabListenableBuilder(
          listenable: listenable,
          builder: (context) {
            builds++;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(builds, 1);

    listenable.notifyListeners();
    await tester.pump();
    expect(builds, 1);

    await tester.pumpWidget(
      ShellTabActive(
        active: true,
        child: ActiveTabListenableBuilder(
          listenable: listenable,
          builder: (context) {
            builds++;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(builds, 2);

    listenable.notifyListeners();
    await tester.pump();
    expect(builds, 3);
  });
}

FoodEntry _food(String id, DateTime loggedAt) {
  return FoodEntry(
    id: id,
    name: id,
    kcalPerBase: 100,
    baseAmount: 100,
    consumedAmount: 100,
    loggedAt: loggedAt,
  );
}

ExerciseEntry _exercise(String id, DateTime loggedAt) {
  return ExerciseEntry(
    id: id,
    name: id,
    durationMin: 30,
    burnedKcal: 100,
    loggedAt: loggedAt,
  );
}

AlcoholEntry _alcohol(String id, DateTime consumedAt) {
  return AlcoholEntry(
    id: id,
    beverageName: id,
    amount: 350,
    unit: 'ml',
    alcoholPercentage: 5,
    totalCalories: 150,
    pureAlcoholGrams: 14,
    alcoholCalories: 98,
    consumedAt: consumedAt,
  );
}

class _GatedSync extends MockDataSyncRepository {
  Completer<void>? gate;
  int pushes = 0;

  @override
  Future<void> pushLocalToRemote(
    String userId, {
    LocalWriteGuard? mayWrite,
  }) async {
    pushes++;
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }
}

class _Foods implements FoodRepositoryBase {
  int loadAllCalls = 0;
  final List<FoodEntry> saved = [];

  @override
  Future<void> save(FoodEntry entry) async {
    saved.removeWhere((item) => item.id == entry.id);
    saved.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    loadAllCalls++;
    throw StateError('loadAll');
  }

  @override
  Future<void> delete(String entryId) async {
    saved.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    saved.clear();
  }
}

class _Exercises implements ExerciseRepositoryBase {
  int loadAllCalls = 0;

  @override
  Future<void> save(ExerciseEntry entry) async {}

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {}

  @override
  Future<List<ExerciseEntry>> loadAll() async {
    loadAllCalls++;
    throw StateError('loadAll');
  }

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<void> clearAll() async {}
}

class _Alcohols implements AlcoholRepositoryBase {
  int loadAllCalls = 0;

  @override
  Future<void> save(AlcoholEntry entry) async {}

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {}

  @override
  Future<List<AlcoholEntry>> loadAll() async {
    loadAllCalls++;
    throw StateError('loadAll');
  }

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<void> clearAll() async {}
}

class _Weights implements WeightRepositoryBase {
  int loadAllCalls = 0;

  @override
  Future<void> save(WeightEntry entry) async {}

  @override
  Future<List<WeightEntry>> loadAll() async {
    loadAllCalls++;
    throw StateError('loadAll');
  }

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async => null;

  @override
  Future<List<WeightRecord>> loadWeightRecords() async => const [];

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {}
}
