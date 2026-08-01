@Tags(['integration'])
library;

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/contracts/saved_food_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' hide AuthUser;

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';
import 'supabase_saved_food_repository_integration_test.dart'
    show createAuthenticatedClient, isLocalSupabaseAvailable;

const _localUrl = 'http://127.0.0.1:54321';
const _serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

Future<void> syncControllerFoodEntries({
  required AppController controller,
  required FoodRepositoryBase foodRepository,
}) async {
  controller.foodEntries
    ..clear()
    ..addAll(await foodRepository.loadAll());
}

Future<void> simulateFoodEntriesPull({
  required SupabaseClient client,
  required String userId,
  required FoodRepositoryBase foodRepository,
}) async {
  final rows = await client.from('food_entries').select().eq('user_id', userId);
  await foodRepository.clearAll();
  if (rows.isEmpty) {
    return;
  }
  await foodRepository.saveAll(
    rows.map(FoodMasterRowMapper.foodEntryFromRow).toList(),
  );
}

FoodEntry sampleEntry({required String id}) {
  return FoodEntry(
    id: id,
    name: 'Delete Me',
    kcalPerUnit: 100,
    quantity: 1,
    loggedAt: DateTime.utc(2026, 7, 20, 12),
  );
}

SupabaseDataSyncRepository buildDataSync({
  required SupabaseClient client,
  required FoodRepositoryBase foodRepository,
}) {
  return SupabaseDataSyncRepository(
    userRepository: _NoopUserRepository(),
    settingsRepository: _NoopSettingsRepository(),
    foodRepository: foodRepository,
    exerciseRepository: _NoopExerciseRepository(),
    weightRepository: _NoopWeightRepository(),
    client: client,
  );
}

void main() {
  group('Supabase food entry delete integration', () {
    late SupabaseClient service;
    late bool supabaseAvailable;

    setUpAll(() async {
      supabaseAvailable = await isLocalSupabaseAvailable();
      if (!supabaseAvailable) {
        return;
      }
      service = SupabaseClient(_localUrl, _serviceKey);
    });

    test('deleteFoodEntry removes own row from Supabase', () async {
      if (!supabaseAvailable) {
        return;
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final client = await createAuthenticatedClient(
        service: service,
        email: 'integration-food-delete-$suffix@test.local',
        password: 'test-password-123',
      );
      final userId = client.auth.currentUser!.id;
      final entry = sampleEntry(id: 'entry-delete-$suffix');

      await client.from('food_entries').upsert(
        FoodMasterRowMapper.foodEntryToRow(entry, userId: userId),
        onConflict: 'user_id,entry_id',
      );

      final dataSync = buildDataSync(
        client: client,
        foodRepository: _NoopFoodRepository(),
      );

      await dataSync.deleteFoodEntry(userId: userId, entryId: entry.id);

      final rows = await client
          .from('food_entries')
          .select()
          .eq('user_id', userId)
          .eq('entry_id', entry.id);
      expect(rows, isEmpty);
    });

    test('deleteFoodEntry throws when row is missing', () async {
      if (!supabaseAvailable) {
        return;
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final client = await createAuthenticatedClient(
        service: service,
        email: 'integration-food-delete-missing-$suffix@test.local',
        password: 'test-password-123',
      );
      final userId = client.auth.currentUser!.id;

      final dataSync = buildDataSync(
        client: client,
        foodRepository: _NoopFoodRepository(),
      );

      await expectLater(
        dataSync.deleteFoodEntry(
          userId: userId,
          entryId: 'missing-entry-$suffix',
        ),
        throwsA(isA<SyncStepException>()),
      );
    });

    test('deleteFoodEntry throws for other users row (RLS)', () async {
      if (!supabaseAvailable) {
        return;
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-food-delete-owner-$suffix@test.local',
        password: 'test-password-123',
      );
      final attackerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-food-delete-attacker-$suffix@test.local',
        password: 'test-password-123',
      );
      final ownerId = ownerClient.auth.currentUser!.id;
      final attackerId = attackerClient.auth.currentUser!.id;
      final entry = sampleEntry(id: 'entry-other-$suffix');

      await ownerClient.from('food_entries').upsert(
        FoodMasterRowMapper.foodEntryToRow(entry, userId: ownerId),
        onConflict: 'user_id,entry_id',
      );

      final attackerSync = buildDataSync(
        client: attackerClient,
        foodRepository: _NoopFoodRepository(),
      );

      await expectLater(
        attackerSync.deleteFoodEntry(
          userId: attackerId,
          entryId: entry.id,
        ),
        throwsA(isA<SyncStepException>()),
      );

      final rows = await ownerClient
          .from('food_entries')
          .select()
          .eq('user_id', ownerId)
          .eq('entry_id', entry.id);
      expect(rows, hasLength(1));
    });

    group('AppController.deleteFood with Supabase', () {
      late _InMemoryFoodRepository foodRepository;

      setUp(() {
        foodRepository = _InMemoryFoodRepository();
      });

      Future<AppController> buildController({
        required SupabaseClient client,
        required AuthUser user,
      }) async {
        final dataSync = buildDataSync(
          client: client,
          foodRepository: foodRepository,
        );
        final controller = AppController(
          healthRepository: MockHealthRepository(isAvailable: false),
          authenticationRepository: MockAuthenticationRepository(
            currentUser: user,
          ),
          dataSyncRepository: dataSync,
          userRepository: _NoopUserRepository(),
          settingsRepository: _NoopSettingsRepository(),
          foodRepository: foodRepository,
          exerciseRepository: _NoopExerciseRepository(),
          weightRepository: _NoopWeightRepository(),
          savedFoodRepository: _NoopSavedFoodRepository(),
        );
        controller.profile = UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 170,
          weightKg: 70,
        );
        controller.goal = Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: DateTime(2026, 12, 31),
        );
        controller.nutritionSettings = const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        );
        return controller;
      }

      test('deletes locally and stays deleted after remote pull', () async {
        if (!supabaseAvailable) {
          return;
        }

        final suffix = DateTime.now().microsecondsSinceEpoch;
        final client = await createAuthenticatedClient(
          service: service,
          email: 'integration-controller-delete-$suffix@test.local',
          password: 'test-password-123',
        );
        final user = client.auth.currentUser!;
        final entry = sampleEntry(id: 'entry-controller-$suffix');

        await client.from('food_entries').upsert(
          FoodMasterRowMapper.foodEntryToRow(entry, userId: user.id),
          onConflict: 'user_id,entry_id',
        );

        final controller = await buildController(
          client: client,
          user: AuthUser(id: user.id, email: user.email ?? ''),
        );
        addTearDown(controller.dispose);

        await simulateFoodEntriesPull(
          client: client,
          userId: user.id,
          foodRepository: foodRepository,
        );
        await syncControllerFoodEntries(
          controller: controller,
          foodRepository: foodRepository,
        );
        expect(controller.foodEntries.map((item) => item.id), contains(entry.id));

        await controller.deleteFood(entry.id);
        expect(controller.foodEntries.where((item) => item.id == entry.id), isEmpty);

        await simulateFoodEntriesPull(
          client: client,
          userId: user.id,
          foodRepository: foodRepository,
        );
        await syncControllerFoodEntries(
          controller: controller,
          foodRepository: foodRepository,
        );
        expect(controller.foodEntries.where((item) => item.id == entry.id), isEmpty);
      });

      test('keeps local entry when remote delete finds no row', () async {
        if (!supabaseAvailable) {
          return;
        }

        final suffix = DateTime.now().microsecondsSinceEpoch;
        final client = await createAuthenticatedClient(
          service: service,
          email: 'integration-controller-keep-$suffix@test.local',
          password: 'test-password-123',
        );
        final user = client.auth.currentUser!;
        final entry = sampleEntry(id: 'entry-keep-$suffix');

        final controller = await buildController(
          client: client,
          user: AuthUser(id: user.id, email: user.email ?? ''),
        );
        addTearDown(controller.dispose);

        await controller.addFood(entry);
        expect(controller.foodEntries, hasLength(1));

        await expectLater(
          controller.deleteFood('missing-$suffix'),
          throwsA(isA<SyncStepException>()),
        );

        expect(controller.foodEntries, hasLength(1));
        final persisted = await foodRepository.loadAll();
        expect(persisted.map((item) => item.id), contains(entry.id));
      });
    });
  });
}

class _InMemoryFoodRepository implements FoodRepositoryBase {
  final List<FoodEntry> _entries = [];

  @override
  Future<void> clearAll() async => _entries.clear();

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<List<FoodEntry>> loadAll() async => List<FoodEntry>.from(_entries);

  @override
  Future<void> save(FoodEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }
}

class _NoopSavedFoodRepository implements SavedFoodRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopUserRepository implements UserRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSettingsRepository implements SettingsRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopFoodRepository implements FoodRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopExerciseRepository implements ExerciseRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopWeightRepository implements WeightRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
