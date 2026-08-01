@Tags(['integration'])
library;

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
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

AlcoholEntry sampleAlcoholEntry({required String id}) {
  return AlcoholEntry(
    id: id,
    beverageName: 'ビール',
    amount: 500,
    unit: 'ml',
    alcoholPercentage: 5,
    totalCalories: 200,
    pureAlcoholGrams: 20,
    alcoholCalories: 140,
    consumedAt: DateTime.utc(2026, 7, 20, 20),
  );
}

SupabaseDataSyncRepository buildDataSync({
  required SupabaseClient client,
  required AlcoholRepositoryBase alcoholRepository,
}) {
  return SupabaseDataSyncRepository(
    userRepository: _NoopUserRepository(),
    settingsRepository: _NoopSettingsRepository(),
    foodRepository: _NoopFoodRepository(),
    exerciseRepository: _NoopExerciseRepository(),
    alcoholRepository: alcoholRepository,
    weightRepository: _NoopWeightRepository(),
    client: client,
  );
}

void main() {
  late final SupabaseClient service;
  late final bool supabaseAvailable;

  setUpAll(() async {
    supabaseAvailable = await isLocalSupabaseAvailable();
    if (!supabaseAvailable) {
      return;
    }
    service = SupabaseClient(_localUrl, _serviceKey);
  });

  group('alcohol_entries integration', () {
    test('CRUD with RLS isolation', () async {
      if (!supabaseAvailable) {
        return;
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-alcohol-owner-$suffix@test.local',
        password: 'test-password-123',
      );
      final otherClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-alcohol-other-$suffix@test.local',
        password: 'test-password-123',
      );
      final ownerId = ownerClient.auth.currentUser!.id;
      final otherId = otherClient.auth.currentUser!.id;
      final entry = sampleAlcoholEntry(id: 'alcohol-$suffix');

      await ownerClient.from('alcohol_entries').upsert(
        FoodMasterRowMapper.alcoholEntryToRow(entry, userId: ownerId),
        onConflict: 'user_id,entry_id',
      );

      final ownRows = await ownerClient
          .from('alcohol_entries')
          .select()
          .eq('user_id', ownerId);
      expect(ownRows, hasLength(1));

      final otherRows = await otherClient
          .from('alcohol_entries')
          .select()
          .eq('user_id', ownerId);
      expect(otherRows, isEmpty);

      await expectLater(
        otherClient
            .from('alcohol_entries')
            .update({'beverage_name': '改ざん'})
            .eq('user_id', ownerId)
            .eq('entry_id', entry.id)
            .select(),
        completion(isEmpty),
      );

      await expectLater(
        otherClient
            .from('alcohol_entries')
            .delete()
            .eq('user_id', ownerId)
            .eq('entry_id', entry.id)
            .select(),
        completion(isEmpty),
      );

      final deleted = await ownerClient
          .from('alcohol_entries')
          .delete()
          .eq('user_id', ownerId)
          .eq('entry_id', entry.id)
          .select('entry_id');
      expect(deleted, hasLength(1));

      final afterDelete = await ownerClient
          .from('alcohol_entries')
          .select()
          .eq('user_id', ownerId);
      expect(afterDelete, isEmpty);

      addTearDown(() async {
        await ownerClient.auth.signOut();
        await otherClient.auth.signOut();
      });

      expect(otherId, isNot(ownerId));
    });

    group('AppController deleteAlcohol', () {
      late _InMemoryAlcoholRepository alcoholRepository;

      setUp(() {
        alcoholRepository = _InMemoryAlcoholRepository();
      });

      Future<AppController> buildController({
        required SupabaseClient client,
        required AuthUser user,
      }) async {
        final dataSync = buildDataSync(
          client: client,
          alcoholRepository: alcoholRepository,
        );
        final controller = AppController(
          healthRepository: MockHealthRepository(isAvailable: false),
          authenticationRepository: MockAuthenticationRepository(
            currentUser: user,
          ),
          dataSyncRepository: dataSync,
          userRepository: _NoopUserRepository(),
          settingsRepository: _NoopSettingsRepository(),
          foodRepository: _NoopFoodRepository(),
          exerciseRepository: _NoopExerciseRepository(),
          alcoholRepository: alcoholRepository,
          weightRepository: _NoopWeightRepository(),
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

      Future<void> syncControllerAlcoholEntries({
        required AppController controller,
      }) async {
        controller.alcoholEntries
          ..clear()
          ..addAll(await alcoholRepository.loadAll());
      }

      Future<void> simulateAlcoholEntriesPull({
        required SupabaseClient client,
        required String userId,
      }) async {
        final rows = await client
            .from('alcohol_entries')
            .select()
            .eq('user_id', userId);
        await alcoholRepository.clearAll();
        if (rows.isEmpty) {
          return;
        }
        await alcoholRepository.saveAll(
          rows.map(FoodMasterRowMapper.alcoholEntryFromRow).toList(),
        );
      }

      test('deletes locally and remotely without resurrection', () async {
        if (!supabaseAvailable) {
          return;
        }

        final suffix = DateTime.now().microsecondsSinceEpoch;
        final client = await createAuthenticatedClient(
          service: service,
          email: 'integration-alcohol-delete-$suffix@test.local',
          password: 'test-password-123',
        );
        final user = client.auth.currentUser!;
        final entry = sampleAlcoholEntry(id: 'alcohol-delete-$suffix');

        await client.from('alcohol_entries').upsert(
          FoodMasterRowMapper.alcoholEntryToRow(entry, userId: user.id),
          onConflict: 'user_id,entry_id',
        );

        final controller = await buildController(
          client: client,
          user: AuthUser(id: user.id, email: user.email ?? ''),
        );
        addTearDown(controller.dispose);

        await simulateAlcoholEntriesPull(client: client, userId: user.id);
        await syncControllerAlcoholEntries(controller: controller);
        expect(controller.alcoholEntries.map((item) => item.id), contains(entry.id));

        await controller.deleteAlcohol(entry.id);
        expect(controller.alcoholEntries.where((item) => item.id == entry.id), isEmpty);

        final rows = await client
            .from('alcohol_entries')
            .select()
            .eq('user_id', user.id)
            .eq('entry_id', entry.id);
        expect(rows, isEmpty);
      });

      test('keeps local entry when remote delete finds no row', () async {
        if (!supabaseAvailable) {
          return;
        }

        final suffix = DateTime.now().microsecondsSinceEpoch;
        final client = await createAuthenticatedClient(
          service: service,
          email: 'integration-alcohol-keep-$suffix@test.local',
          password: 'test-password-123',
        );
        final user = client.auth.currentUser!;
        final entry = sampleAlcoholEntry(id: 'alcohol-keep-$suffix');

        await client.from('alcohol_entries').upsert(
          FoodMasterRowMapper.alcoholEntryToRow(entry, userId: user.id),
          onConflict: 'user_id,entry_id',
        );

        final controller = await buildController(
          client: client,
          user: AuthUser(id: user.id, email: user.email ?? ''),
        );
        addTearDown(controller.dispose);

        await simulateAlcoholEntriesPull(client: client, userId: user.id);
        await syncControllerAlcoholEntries(controller: controller);
        expect(controller.alcoholEntries, hasLength(1));

        await expectLater(
          controller.deleteAlcohol('missing-$suffix'),
          throwsA(isA<SyncStepException>()),
        );

        expect(controller.alcoholEntries, hasLength(1));
        final persisted = await alcoholRepository.loadAll();
        expect(persisted.map((item) => item.id), contains(entry.id));
      });
    });
  });
}

class _InMemoryAlcoholRepository implements AlcoholRepositoryBase {
  final List<AlcoholEntry> _entries = [];

  @override
  Future<void> clearAll() async => _entries.clear();

  @override
  Future<void> delete(String entryId) async {
    final removed = _entries.where((entry) => entry.id == entryId).length;
    if (removed == 0) {
      throw StateError('Alcohol entry not found: $entryId');
    }
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<List<AlcoholEntry>> loadAll() async => List<AlcoholEntry>.from(_entries);

  @override
  Future<void> save(AlcoholEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }
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
