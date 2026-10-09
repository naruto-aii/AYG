import 'dart:convert';
import 'dart:io';

import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a free user memo is saved locally and sent intact', () async {
    SharedPreferences.setMockInitialValues({});
    final foods = _Foods();
    final exercises = _Exercises();
    final pending = PendingRecordStore();
    final http = _Capture();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: http,
    );
    addTearDown(client.dispose);
    final sync = SupabaseDataSyncRepository(
      userRepository: _Users(),
      settingsRepository: _Settings(),
      foodRepository: foods,
      exerciseRepository: exercises,
      alcoholRepository: _Alcohols(),
      weightRepository: _Weights(),
      pendingRecords: pending,
      client: client,
    );
    final controller = AppController(
      subscriptionRepository: UnavailableSubscriptionRepository(),
      foodRepository: foods,
      exerciseRepository: exercises,
      pendingRecords: pending,
      dataSyncRepository: sync,
    );
    addTearDown(controller.dispose);
    expect(controller.subscriptionRepository.isPlusActive, isFalse);

    const foodId = 'food-free';
    controller.foodEntries.add(
      FoodEntry(
        id: foodId,
        name: 'ささみ',
        kcalPerBase: 100,
        baseAmount: 100,
        loggedAt: DateTime(2026, 10, 8, 12),
      ),
    );
    expect(
      await controller.updateFoodMemo(
        controller.foodEntries.single,
        ' 少し多かったから明日は150 ',
      ),
      isTrue,
    );
    expect(controller.foodEntries.single.memo, '少し多かったから明日は150');
    expect((await foods.loadAll()).single.memo, '少し多かったから明日は150');
    expect(
      await pending.preferLocalIds(PendingRecordKind.food),
      contains(foodId),
    );

    await controller.addExercise(
      ExerciseEntry(
        id: 'exercise-free',
        name: '歩行',
        durationMin: 20,
        burnedKcal: 80,
        notes: ' 雨 ',
        loggedAt: DateTime(2026, 10, 8, 12),
      ),
    );
    expect(controller.exerciseEntries.single.notes, '雨');
    expect((await exercises.loadAll()).single.notes, '雨');
    expect(
      await pending.preferLocalIds(PendingRecordKind.exercise),
      contains('exercise-free'),
    );

    await sync.pushLocalToRemote('user-free');

    final foodPayload = http.bodyContaining('food_entries');
    final exercisePayload = http.bodyContaining('exercise_entries');
    expect(foodPayload, contains('"memo":"少し多かったから明日は150"'));
    expect(foodPayload, contains('"entry_id":"food-free"'));
    expect(exercisePayload, contains('"notes":"雨"'));
    expect(exercisePayload, contains('"entry_id":"exercise-free"'));
    expect(await pending.preferLocalIds(PendingRecordKind.food), isEmpty);
    expect(await pending.preferLocalIds(PendingRecordKind.exercise), isEmpty);
  });

  test('server rules do not reject or strip notes for a free user', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final sql = [
      for (final file in migrations) file.readAsStringSync(),
    ].join('\n');

    final memoComments = RegExp(
      r"comment on column public\.food_entries\.memo is\s+'([^']*)'",
    ).allMatches(sql).map((match) => match.group(1)!).toList();
    expect(memoComments, isNotEmpty);
    expect(memoComments.last, 'その食事へのメモ。空は保存しない。無料でもカロナビ+でも書ける。');
    expect(memoComments.last, isNot(contains('カロナビ+が無い')));

    final noteComments = RegExp(
      r"comment on column public\.exercise_entries\.notes is\s+'([^']*)'",
    ).allMatches(sql).map((match) => match.group(1)!).toList();
    expect(noteComments.single, contains('無料でもカロナビ+でも書ける'));

    expect(sql.contains('new.memo'), isFalse);
    expect(sql.contains('new.notes'), isFalse);
    for (final file in migrations) {
      final text = file.readAsStringSync();
      final gatesFoodMemo = RegExp(
        'food_entries[\\s\\S]{0,180}memo[\\s\\S]{0,180}calonavi_plus_entitlements|'
        'calonavi_plus_entitlements[\\s\\S]{0,180}memo[\\s\\S]{0,180}food_entries',
      ).hasMatch(text);
      final gatesExerciseNotes = RegExp(
        'exercise_entries[\\s\\S]{0,180}notes[\\s\\S]{0,180}calonavi_plus_entitlements|'
        'calonavi_plus_entitlements[\\s\\S]{0,180}notes[\\s\\S]{0,180}exercise_entries',
      ).hasMatch(text);
      expect(gatesFoodMemo, isFalse, reason: file.path);
      expect(gatesExerciseNotes, isFalse, reason: file.path);
    }

    final policies = RegExp(
      r'create policy\s+"[^"]+"\s+on public\.(?:food_entries|exercise_entries)\b[\s\S]*?;',
    ).allMatches(sql);
    expect(policies, isNotEmpty);
    for (final policy in policies) {
      expect(policy.group(0), contains('auth.uid()'));
      expect(policy.group(0), isNot(contains('calonavi_plus')));
      expect(policy.group(0), isNot(contains('memo')));
      expect(policy.group(0), isNot(contains('notes')));
    }

    final functions = Directory('supabase/functions')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts'));
    for (final file in functions) {
      final text = file.readAsStringSync();
      final touchesRecordNotes = text.contains('food_entries') &&
          text.contains('memo');
      final stripsExerciseNotes = text.contains('exercise_entries') &&
          text.contains('notes');
      expect(touchesRecordNotes, isFalse, reason: file.path);
      expect(stripsExerciseNotes, isFalse, reason: file.path);
    }
  });
}

class _Capture extends BaseClient {
  final bodies = <String>[];

  String bodyContaining(String table) {
    return bodies.firstWhere((body) => body.contains(table));
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request is Request) {
      bodies.add('${request.url.path}\n${request.body}');
    }
    return StreamedResponse(
      Stream<List<int>>.value(utf8.encode('[]')),
      201,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }

  @override
  void close() {}
}

class _Foods implements FoodRepositoryBase {
  final entries = <FoodEntry>[];

  @override
  Future<void> clearAll() async => entries.clear();

  @override
  Future<void> delete(String entryId) async =>
      entries.removeWhere((entry) => entry.id == entryId);

  @override
  Future<List<FoodEntry>> loadAll() async => List.of(entries);

  @override
  Future<void> save(FoodEntry entry) async {
    entries.removeWhere((item) => item.id == entry.id);
    entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> next) async {
    entries
      ..clear()
      ..addAll(next);
  }
}

class _Exercises implements ExerciseRepositoryBase {
  final entries = <ExerciseEntry>[];

  @override
  Future<void> clearAll() async => entries.clear();

  @override
  Future<void> delete(String entryId) async =>
      entries.removeWhere((entry) => entry.id == entryId);

  @override
  Future<List<ExerciseEntry>> loadAll() async => List.of(entries);

  @override
  Future<void> save(ExerciseEntry entry) async {
    entries.removeWhere((item) => item.id == entry.id);
    entries.add(entry);
  }

  @override
  Future<void> saveAll(List<ExerciseEntry> next) async {
    entries
      ..clear()
      ..addAll(next);
  }
}

class _Alcohols implements AlcoholRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<List<AlcoholEntry>> loadAll() async => const [];

  @override
  Future<void> save(AlcoholEntry entry) async {}

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {}
}

class _Weights implements WeightRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async => null;

  @override
  Future<List<WeightEntry>> loadAll() async => const [];

  @override
  Future<List<WeightRecord>> loadWeightRecords() async => const [];

  @override
  Future<void> save(WeightEntry entry) async {}

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {}
}

class _Users implements UserRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<UserProfile?> loadProfile() async => null;

  @override
  Future<void> saveGoal(Goal goal) async {}

  @override
  Future<void> saveProfile(UserProfile profile) async {}
}

class _Settings implements SettingsRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<AppSettings> loadAppSettings() async => const AppSettings();

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {}

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {}
}
