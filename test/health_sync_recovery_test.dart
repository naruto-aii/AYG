import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/health_data_client.dart';
import 'package:ayg/repositories/health_read_error.dart';
import 'package:ayg/repositories/platform_health_repository.dart';
import 'package:ayg/screens/settings/settings_health_activity_screen.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/analytics/analytics_event.dart';
import 'package:ayg/services/health_sample_seen_store.dart';
import 'package:ayg/services/health_sync_result.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformHealthRepository reads', () {
    late IsarTestHarness harness;
    late _FakeHealth client;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      harness = await IsarTestHarness.create();
      client = _FakeHealth();
    });

    tearDown(() async {
      await harness.dispose();
    });

    PlatformHealthRepository repository() {
      return PlatformHealthRepository(
        health: client,
        weightRepository: harness.weightRepository,
        isar: harness.isar,
      );
    }

    test('one failed type does not blank the others', () async {
      client.responses[HealthDataType.ACTIVE_ENERGY_BURNED] = [
        _point(
          type: HealthDataType.ACTIVE_ENERGY_BURNED,
          unit: HealthDataUnit.KILOCALORIE,
          value: 180,
          at: DateTime(2026, 10, 19, 9),
        ),
      ];
      client.responses[HealthDataType.WEIGHT] = PlatformException(
        code: 'HEALTH_ERROR',
        message: 'do-not-store-this',
      );
      client.responses[HealthDataType.BIRTH_DATE] = StateError('ignored');

      final profile = await repository().fetchProfileData();

      expect(profile.activeEnergyBurnedKcal, 180);
      expect(profile.weightKg, isNull);
      expect(profile.birthDate, isNull);
      expect(profile.readFailed(HealthReadType.activeEnergy), isFalse);
      expect(profile.readFailed(HealthReadType.weight), isTrue);
      expect(profile.readFailed(HealthReadType.birthDate), isTrue);
      expect(
        profile.failures.map((failure) => failure.code),
        containsAll(['HEALTH_ERROR', 'StateError']),
      );
      expect(
        profile.failures.map((failure) => failure.code).join(' '),
        isNot(contains('do-not-store')),
      );
    });

    test('a successful empty energy read is 0 and not a failure', () async {
      final profile = await repository().fetchProfileData();

      expect(profile.activeEnergyBurnedKcal, 0);
      expect(profile.failures, isEmpty);
      expect(profile.receivedHealthSample, isFalse);
      expect(healthSyncResult(profile), 'success_zero');
      expect(
        healthSyncResultForInstall(profile, installHasSeenSample: false),
        'no_sample',
      );
    });

    test('a zero-calorie point counts as a real sample', () async {
      client.responses[HealthDataType.ACTIVE_ENERGY_BURNED] = [
        _point(
          type: HealthDataType.ACTIVE_ENERGY_BURNED,
          unit: HealthDataUnit.KILOCALORIE,
          value: 0,
          at: DateTime(2026, 10, 19, 9),
        ),
      ];

      final profile = await repository().fetchProfileData();

      expect(profile.activeEnergyBurnedKcal, 0);
      expect(profile.receivedHealthSample, isTrue);
      expect(
        healthSyncResultForInstall(profile, installHasSeenSample: false),
        'success_zero',
      );
    });

    test('a sheet error does not count as asked', () async {
      client.throwOnAuthorize = true;
      final repo = repository();

      expect(await repo.ensureReadAuthorization(allowPrompt: true), isFalse);
      expect(client.authorizationRequests, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(PlatformHealthRepository.readAuthorizationAskedKey),
        isNot(true),
      );

      client.throwOnAuthorize = false;
      expect(await repo.ensureReadAuthorization(allowPrompt: true), isTrue);
      expect(client.authorizationRequests, 2);
      expect(
        prefs.getBool(PlatformHealthRepository.readAuthorizationAskedKey),
        isTrue,
      );
    });

    test('a finished sheet is remembered even when it returns false', () async {
      client.authorizeResult = false;
      final repo = repository();

      expect(await repo.requestPermissions(), isFalse);
      expect(await repo.ensureReadAuthorization(allowPrompt: true), isFalse);
      expect(client.authorizationRequests, 1);
    });

    test('authorization not determined keeps a stable code', () async {
      client.responses[HealthDataType.ACTIVE_ENERGY_BURNED] = PlatformException(
        code: 'HEALTH_ERROR',
        message: 'Error getting health data: Authorization not determined',
      );

      final profile = await repository().fetchProfileData();

      expect(profile.readFailed(HealthReadType.activeEnergy), isTrue);
      expect(
        profile.failures.map((failure) => failure.code),
        contains('authorization_not_determined'),
      );
      expect(
        profile.failures.map((failure) => failure.code).join(' '),
        isNot(contains('Authorization')),
      );
    });

    test('asks once on this install and never from the background', () async {
      final repo = repository();

      await repo.ensureReadAuthorization(allowPrompt: false);
      expect(client.authorizationRequests, 0);
      expect(client.permissionChecks, 0);

      client.permissionStatus = null;
      await repo.ensureReadAuthorization(allowPrompt: true);
      expect(client.authorizationRequests, 1);

      client.permissionStatus = false;
      await repo.ensureReadAuthorization(allowPrompt: true);
      expect(client.authorizationRequests, 1);
      expect(client.permissionChecks, 1);
    });

    test('skips the sheet when hasPermissions is already true', () async {
      client.permissionStatus = true;
      final repo = repository();

      await repo.ensureReadAuthorization(allowPrompt: true);
      expect(client.authorizationRequests, 0);
      expect(client.permissionChecks, 1);

      await repo.ensureReadAuthorization(allowPrompt: true);
      expect(client.permissionChecks, 1);
    });

    test('error code keeps the class and drops the message', () {
      final code = healthReadErrorCode(
        PlatformException(code: 'FlutterHealth', message: 'private detail'),
      );
      expect(code, 'FlutterHealth');
    });
  });

  group('health refresh leaves recorded data alone', () {
    late IsarTestHarness harness;
    late MockHealthRepository health;
    late MemoryHealthSampleSeenStore samples;
    late AppController controller;
    late AnalyticsHarness analytics;

    setUp(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      harness = await IsarTestHarness.create();
      analytics = await AnalyticsHarness.open(isar: harness.isar);
      await analytics.service.grantConsent(surface: 'settings');
      health = MockHealthRepository(isAvailable: true);
      samples = MemoryHealthSampleSeenStore();
      controller = AppController(
        healthRepository: health,
        healthSampleSeen: samples,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
      );
      final profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.female,
        heightCm: 165,
        weightKg: 68,
      );
      controller.profile = profile;
      await harness.userRepository.saveProfile(profile);
      final goal = Goal(
        type: GoalType.lose,
        targetWeightKg: 60,
        targetDate: DateTime(2026, 12, 31),
      );
      controller.goal = goal;
      await harness.userRepository.saveGoal(goal);
      controller.nutritionSettings = const NutritionSettings(
        useHealthIntegration: true,
        activityLevel: ActivityLevel.moderate,
      );
      controller.healthSnapshot = HealthSnapshot(
        activeEnergyBurnedKcal: 400,
        weightKg: 68,
        weightMeasuredAt: DateTime(2026, 10, 1, 8),
      );
      await harness.settingsRepository.saveHealthSnapshot(
        controller.healthSnapshot,
      );
      await controller.addFood(
        FoodEntry(
          id: 'food-1',
          name: 'ご飯',
          kcalPerBase: 200,
          loggedAt: DateTime(2026, 10, 18, 12),
        ),
      );
      await controller.addExercise(
        ExerciseEntry(
          id: 'ex-1',
          name: '散歩',
          durationMin: 20,
          burnedKcal: 40,
          loggedAt: DateTime(2026, 10, 18, 7),
        ),
      );
      final pending = widgetExercisePendingWeight(
        pattern: const WidgetExercisePattern(
          itemId: 'widget-ex',
          activityId: 'pole_exercise',
          name: 'ポールエクササイズ',
          sortOrder: 0,
          durationMin: 20,
        ),
        id: 'widget-ex',
        loggedAt: DateTime(2026, 10, 18, 18),
      );
      expect(pending, isNotNull);
      await controller.addExercise(pending!);
      await harness.weightRepository.save(
        WeightEntry(
          id: 'manual-1',
          weightKg: 68,
          recordedAt: DateTime(2026, 10, 1, 8),
          source: WeightSource.manual,
        ),
      );
    });

    tearDown(() async {
      await analytics.service.settled;
      Analytics.onEmitForTest = null;
      Analytics.service = null;
      controller.dispose();
      await harness.dispose();
    });

    test(
      'a failed refresh does not blank the snapshot or rewrite records',
      () async {
        health.profileData = const HealthProfileData(
          failures: [
            HealthReadFailure(
              type: HealthReadType.activeEnergy,
              code: 'PlatformException',
            ),
            HealthReadFailure(
              type: HealthReadType.weight,
              code: 'PlatformException',
            ),
            HealthReadFailure(type: HealthReadType.workout, code: 'StateError'),
          ],
        );
        final before = await _records(harness);

        await controller.refreshHealthDataQuietly(trigger: 'launch');

        expect(health.ensureReadAuthorizationCalls, 1);
        expect(health.lastAllowPrompt, isTrue);
        expect(health.fetchProfileDataCalled, isTrue);
        expect(controller.healthSnapshot.activeEnergyBurnedKcal, 400);
        expect(controller.healthSnapshot.weightKg, 68);
        expect(controller.profile!.weightKg, 68);
        expect(controller.lastHealthSyncFailed, isTrue);
        final stored = await harness.settingsRepository.loadHealthSnapshot();
        expect(stored!.activeEnergyBurnedKcal, 400);
        expect(stored.weightKg, 68);
        expect(await _records(harness), before);

        await analytics.service.settled;
        final event = await _healthSyncEvent(analytics);
        expect(event['result'], 'failed');
        expect(event['trigger'], 'launch');
        expect(event.containsKey('active_energy_kcal'), isTrue);
        expect(event['active_energy_kcal'], isNull);
        final failures = event['failures'] as List;
        expect(failures, hasLength(3));
        expect(failures.first, {
          'type': 'ACTIVE_ENERGY_BURNED',
          'code': 'PlatformException',
        });
      },
    );

    test('background refresh does not ask for permission', () async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      health.profileData = const HealthProfileData(activeEnergyBurnedKcal: 10);

      await controller.refreshHealthDataQuietly(trigger: 'resume');

      expect(health.lastAllowPrompt, isFalse);
      expect(health.fetchProfileDataCalled, isTrue);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('a successful read updates only the fields that were read', () async {
      health.profileData = HealthProfileData(
        activeEnergyBurnedKcal: 120,
        weightKg: 70,
        weightMeasuredAt: DateTime(2026, 10, 18, 7),
      );
      final before = await _records(harness);

      final ok = await controller.resyncHealthData();

      expect(ok, isTrue);
      expect(controller.lastHealthSyncFailed, isFalse);
      expect(controller.healthSnapshot.activeEnergyBurnedKcal, 120);
      expect(controller.healthSnapshot.weightKg, 70);
      final after = await _records(harness);
      expect(after.foods, before.foods);
      expect(after.exercises, before.exercises);
      expect(after.goal, before.goal);
      expect(after.weights, contains(before.weights.single));
      final pending = after.exercises.singleWhere(
        (row) => row.startsWith('widget-ex|'),
      );
      expect(pending, contains('|0.0|widget_weight_pending|'));
    });

    test(
      'an empty read before any sample keeps the restored snapshot',
      () async {
        health.profileData = const HealthProfileData(activeEnergyBurnedKcal: 0);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          PlatformHealthRepository.readAuthorizationAskedKey,
          true,
        );
        await prefs.setBool('health_sample_seen', true);
        final before = await _records(harness);

        final ok = await controller.resyncHealthData();

        expect(ok, isFalse);
        expect(samples.seen, isFalse);
        expect(controller.lastHealthSyncFailed, isTrue);
        expect(controller.healthSnapshot.activeEnergyBurnedKcal, 400);
        expect(controller.healthSnapshot.weightKg, 68);
        expect(controller.profile!.weightKg, 68);
        expect(await _records(harness), before);
        final stored = await harness.settingsRepository.loadHealthSnapshot();
        expect(stored!.activeEnergyBurnedKcal, 400);
        expect(stored.weightKg, 68);
        await analytics.service.settled;
        final event = await _healthSyncEvent(analytics);
        expect(event['result'], 'no_sample');
        expect(event['active_energy_kcal'], 0);
        expect(event['failures'], isEmpty);
      },
    );

    test('zero energy after a real sample is success_zero', () async {
      samples.seen = true;
      health.profileData = const HealthProfileData(activeEnergyBurnedKcal: 0);
      final before = await _records(harness);

      final ok = await controller.resyncHealthData();

      expect(ok, isTrue);
      expect(controller.lastHealthSyncFailed, isFalse);
      expect(controller.healthSnapshot.activeEnergyBurnedKcal, 0);
      expect(controller.healthSnapshot.weightKg, isNull);
      expect(controller.profile!.weightKg, 68);
      expect(await _records(harness), before);
      await analytics.service.settled;
      final event = await _healthSyncEvent(analytics);
      expect(event['result'], 'success_zero');
      expect(event['active_energy_kcal'], 0);
      expect(event['failures'], isEmpty);
    });

    test('a thrown import is failed, not success_zero', () async {
      health.fetchError = StateError('do-not-store-this');

      await controller.refreshHealthDataQuietly(trigger: 'launch');
      expect(controller.lastHealthSyncFailed, isTrue);
      expect(controller.healthSnapshot.activeEnergyBurnedKcal, 400);
      expect(controller.healthSnapshot.weightKg, 68);
      await analytics.service.settled;
      final event = await _healthSyncEvent(analytics);
      expect(event['result'], 'failed');
      expect(event['active_energy_kcal'], isNull);
      final failures = event['failures'] as List;
      expect(failures, hasLength(2));
      expect(failures.map((failure) => (failure as Map)['code']).toSet(), {
        'StateError',
      });
      expect(failures.toString(), isNot(contains('do-not-store')));
    });

    test(
      'authorization not determined asks once, then only re-reads',
      () async {
        health.profileData = const HealthProfileData(
          failures: [
            HealthReadFailure(
              type: HealthReadType.activeEnergy,
              code: 'authorization_not_determined',
            ),
            HealthReadFailure(
              type: HealthReadType.weight,
              code: 'authorization_not_determined',
            ),
          ],
        );
        health.onRequestPermissions = () {
          health.profileData = const HealthProfileData(
            activeEnergyBurnedKcal: 30,
            sawHealthSample: true,
          );
        };

        await controller.refreshHealthDataQuietly(trigger: 'launch');

        expect(health.requestPermissionsCalled, isTrue);
        expect(health.fetchCount, 2);
        expect(controller.healthSnapshot.activeEnergyBurnedKcal, 30);
        expect(samples.seen, isTrue);

        health.requestPermissionsCalled = false;
        health.profileData = const HealthProfileData(
          failures: [
            HealthReadFailure(
              type: HealthReadType.activeEnergy,
              code: 'authorization_not_determined',
            ),
          ],
        );
        health.onRequestPermissions = null;

        await controller.refreshHealthDataQuietly(trigger: 'resume');

        expect(health.requestPermissionsCalled, isFalse);
        expect(health.fetchCount, 3);
      },
    );
  });

  test('the seen flag is a backup-excluded file, not preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('health-seen');
    final excluded = <String>[];
    final store = FileHealthSampleSeenStore(
      directory: () async => dir,
      excludeFromBackup: (path) async {
        excluded.add(path);
        return true;
      },
    );

    expect(await store.hasSeen(), isFalse);
    await store.markSeen();

    expect(await store.hasSeen(), isTrue);
    expect(excluded.single, endsWith('health_sample_seen'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    await dir.delete(recursive: true);
  });

  test('a failed backup exclusion does not keep the seen marker', () async {
    final dir = await Directory.systemTemp.createTemp('health-seen-fail');
    final store = FileHealthSampleSeenStore(
      directory: () async => dir,
      excludeFromBackup: (path) async => false,
    );

    await store.markSeen();

    expect(await store.hasSeen(), isFalse);
    expect(File('${dir.path}/health_sample_seen').existsSync(), isFalse);

    await File('${dir.path}/health_sample_seen').writeAsString('1');
    await store.markSeen();
    expect(await store.hasSeen(), isFalse);

    await dir.delete(recursive: true);
  });

  test('a thrown backup exclusion does not keep the seen marker', () async {
    final dir = await Directory.systemTemp.createTemp('health-seen-throw');
    final store = FileHealthSampleSeenStore(
      directory: () async => dir,
      excludeFromBackup: (path) async => throw StateError('exclude failed'),
    );

    await store.markSeen();

    expect(await store.hasSeen(), isFalse);
    expect(File('${dir.path}/health_sample_seen').existsSync(), isFalse);
    await dir.delete(recursive: true);
  });

  testWidgets('settings shows a quiet retry only after the last sync failed', (
    tester,
  ) async {
    final health = MockHealthRepository(
      isAvailable: true,
      profileData: const HealthProfileData(
        failures: [
          HealthReadFailure(
            type: HealthReadType.activeEnergy,
            code: 'PlatformException',
          ),
          HealthReadFailure(
            type: HealthReadType.weight,
            code: 'PlatformException',
          ),
        ],
      ),
    );
    final samples = MemoryHealthSampleSeenStore();
    final controller = AppController(
      healthRepository: health,
      healthSampleSeen: samples,
    );
    addTearDown(controller.dispose);
    controller.nutritionSettings = const NutritionSettings(
      useHealthIntegration: true,
      activityLevel: ActivityLevel.moderate,
    );
    controller.profile = UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.female,
      heightCm: 165,
      weightKg: 68,
    );
    await controller.resyncHealthData();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsHealthActivityScreen(
          controller: controller,
          healthRepository: health,
        ),
      ),
    );

    expect(find.text('活動・Health'), findsOneWidget);
    expect(find.text(healthRecoveryMessage), findsOneWidget);
    expect(find.text(healthRecoveryGuidance), findsOneWidget);
    expect(find.textContaining('プライバシー > アプリ > カロナビ'), findsOneWidget);
    expect(find.textContaining('設定 > ヘルスケア'), findsNothing);
    expect(find.text(healthRecoveryReread), findsOneWidget);
    expect(find.text('許可をやり直す'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    final fetchesBefore = health.fetchCount;
    await tester.tap(find.text(healthRecoveryReread));
    await tester.pumpAndSettle();

    expect(health.requestPermissionsCalled, isFalse);
    expect(health.fetchCount, greaterThan(fetchesBefore));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(healthRecoveryMessage), findsOneWidget);
  });

  testWidgets('settings hides the retry when the last sync did not fail', (
    tester,
  ) async {
    final health = MockHealthRepository(
      isAvailable: true,
      profileData: const HealthProfileData(activeEnergyBurnedKcal: 0),
    );
    final controller = AppController(
      healthRepository: health,
      healthSampleSeen: MemoryHealthSampleSeenStore(seen: true),
    );
    addTearDown(controller.dispose);
    controller.nutritionSettings = const NutritionSettings(
      useHealthIntegration: true,
      activityLevel: ActivityLevel.moderate,
    );
    await controller.resyncHealthData();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsHealthActivityScreen(
          controller: controller,
          healthRepository: health,
        ),
      ),
    );

    expect(find.text('活動・Health'), findsOneWidget);
    expect(find.text(healthRecoveryMessage), findsNothing);
    expect(find.text(healthRecoveryGuidance), findsNothing);
    expect(find.text(healthRecoveryReread), findsNothing);
  });
}

class _Records {
  const _Records({
    required this.foods,
    required this.exercises,
    required this.weights,
    required this.goal,
    required this.profileWeight,
  });

  final List<String> foods;
  final List<String> exercises;
  final List<String> weights;
  final String goal;
  final double? profileWeight;

  @override
  bool operator ==(Object other) {
    return other is _Records &&
        _same(foods, other.foods) &&
        _same(exercises, other.exercises) &&
        _same(weights, other.weights) &&
        goal == other.goal &&
        profileWeight == other.profileWeight;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(foods),
    Object.hashAll(exercises),
    Object.hashAll(weights),
    goal,
    profileWeight,
  );
}

bool _same(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  final a = [...left]..sort();
  final b = [...right]..sort();
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

Future<Map<String, Object?>> _healthSyncEvent(
  AnalyticsHarness analytics,
) async {
  final queued = await analytics.queue.all();
  for (final row in queued.reversed) {
    final event = AnalyticsEvent.decode(row.json);
    if (event.eventName == 'health_sync_result') {
      return event.props;
    }
  }
  fail('health_sync_result was not queued');
}

Future<_Records> _records(IsarTestHarness harness) async {
  final foods = await harness.foodRepository.loadAll();
  final exercises = await harness.exerciseRepository.loadAll();
  final weights = await harness.weightRepository.loadAll();
  final goal = await harness.userRepository.loadGoal();
  final profile = await harness.userRepository.loadProfile();
  return _Records(
    foods: [
      for (final entry in foods)
        '${entry.id}|${entry.name}|${entry.kcalPerBase}|${entry.loggedAt.toIso8601String()}',
    ],
    exercises: [
      for (final entry in exercises)
        '${entry.id}|${entry.name}|${entry.burnedKcal}|${entry.sourceKey}|${entry.durationMin}',
    ],
    weights: [
      for (final entry in weights)
        '${entry.id}|${entry.weightKg}|${entry.source.storageValue}|${entry.recordedAt.toIso8601String()}',
    ],
    goal:
        '${goal?.type.name}|${goal?.targetWeightKg}|${goal?.targetDate.toIso8601String()}|${goal?.goalPace.name}',
    profileWeight: profile?.weightKg,
  );
}

class _FakeHealth implements HealthDataClient {
  bool? permissionStatus;
  int permissionChecks = 0;
  int authorizationRequests = 0;
  bool throwOnAuthorize = false;
  bool authorizeResult = true;
  final Map<HealthDataType, Object> responses = {};

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final response = responses[types.single];
    if (response is List<HealthDataPoint>) {
      return response;
    }
    if (response != null) {
      throw response;
    }
    return const [];
  }

  @override
  Future<bool?> hasPermissions(List<HealthDataType> types) async {
    permissionChecks += 1;
    return permissionStatus;
  }

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) async {
    authorizationRequests += 1;
    if (throwOnAuthorize) {
      throw StateError('sheet failed');
    }
    return authorizeResult;
  }
}

HealthDataPoint _point({
  required HealthDataType type,
  required HealthDataUnit unit,
  required num value,
  required DateTime at,
}) {
  return HealthDataPoint(
    uuid: 'point',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: unit,
    dateFrom: at,
    dateTo: at,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'device',
    sourceId: 'source',
    sourceName: 'source',
  );
}
