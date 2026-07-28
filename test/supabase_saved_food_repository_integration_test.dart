@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/saved_food_persistence_error.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/supabase/supabase_saved_food_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

/// Standard Supabase CLI local demo keys (not production secrets).
const _localUrl = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

Future<bool> isLocalSupabaseAvailable() async {
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$_localUrl/rest/v1/'));
    request.headers.set('apikey', _anonKey);
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain();
    client.close(force: true);
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

SavedFood sampleIntegrationFood({
  required String userId,
  required String foodId,
  String normalizedName = 'integration cabbage',
  double baseAmount = 100,
  FoodUnitType unitType = FoodUnitType.g,
  FoodVisibility visibility = FoodVisibility.private,
  int version = 1,
  double kcal = 165,
}) {
  final now = DateTime.now().toUtc();
  return SavedFood(
    foodId: foodId,
    ownerUserId: userId,
    name: 'Integration Cabbage',
    normalizedName: normalizedName,
    baseAmount: baseAmount,
    unitType: unitType,
    servingUnitLabel: 'g',
    kcalPerBase: kcal,
    proteinPerBase: 10,
    fatPerBase: 5,
    carbPerBase: 20,
    visibility: visibility,
    status: FoodStatus.active,
    sourceType: FoodSourceType.manual,
    version: version,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> insertPublicUser(String userId, String email) async {
  final result = await Process.run('docker', [
    'exec',
    'supabase_db_AYG',
    'psql',
    '-U',
    'postgres',
    '-tAc',
    "INSERT INTO public.users (id, email) VALUES ('$userId', '$email') "
        'ON CONFLICT (id) DO NOTHING;',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Failed to seed public.users: ${result.stderr}');
  }
}

Future<SupabaseClient> createAuthenticatedClient({
  required SupabaseClient service,
  required String email,
  required String password,
}) async {
  final created = await service.auth.admin.createUser(
    AdminUserAttributes(email: email, password: password, emailConfirm: true),
  );
  final userId = created.user!.id;
  await insertPublicUser(userId, email);

  final client = SupabaseClient(_localUrl, _anonKey);
  await client.auth.signInWithPassword(email: email, password: password);
  return client;
}

void main() {
  group('SupabaseSavedFoodRepository (local Supabase)', () {
    late SupabaseClient service;
    late bool available;

    setUpAll(() async {
      available = await isLocalSupabaseAvailable();
      if (!available) {
        return;
      }
      service = SupabaseClient(_localUrl, _serviceKey);
    });

    test('private save, publish RPC, fetch public', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'integration-$suffix@test.local';
      final client = await createAuthenticatedClient(
        service: service,
        email: email,
        password: 'testpass123',
      );
      final userId = client.auth.currentUser!.id;
      final repo = SupabaseSavedFoodRepository(client: client);
      const foodId = 'int-pub-1';
      final normalized = 'pub-cabbage-$suffix';

      final saved = await repo.upsertOwnPrivate(
        userId: userId,
        food: sampleIntegrationFood(
          userId: userId,
          foodId: foodId,
          normalizedName: normalized,
        ),
      );
      expect(saved.visibility, FoodVisibility.private);

      final published = await repo.publish(userId: userId, foodId: foodId);
      expect(published.visibility, FoodVisibility.public);

      final fetched = await repo.getPublicById(
        ownerUserId: userId,
        foodId: foodId,
      );
      expect(fetched?.visibility, FoodVisibility.public);
    });

    test('duplicate publish maps to PublishSavedFoodException', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final email = 'integration-dup-$suffix@test.local';
      final client = await createAuthenticatedClient(
        service: service,
        email: email,
        password: 'testpass123',
      );
      final userId = client.auth.currentUser!.id;
      final repo = SupabaseSavedFoodRepository(client: client);
      final normalized = 'dup-cabbage-$suffix';

      await repo.upsertOwnPrivate(
        userId: userId,
        food: sampleIntegrationFood(
          userId: userId,
          foodId: 'dup-a',
          normalizedName: normalized,
        ),
      );
      await repo.publish(userId: userId, foodId: 'dup-a');

      await repo.upsertOwnPrivate(
        userId: userId,
        food: sampleIntegrationFood(
          userId: userId,
          foodId: 'dup-b',
          normalizedName: normalized,
        ),
      );

      await expectLater(
        repo.publish(userId: userId, foodId: 'dup-b'),
        throwsA(
          isA<PublishSavedFoodException>().having(
            (e) => e.kind,
            'kind',
            PublishFailureKind.duplicate,
          ),
        ),
      );

      final stillPrivate = await repo.pullAllOwn(userId);
      final dupB = stillPrivate.firstWhere((f) => f.foodId == 'dup-b');
      expect(dupB.visibility, FoodVisibility.private);
    });

    test('not owner publish rejected', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-owner-$suffix@test.local',
        password: 'testpass123',
      );
      final otherClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-other-$suffix@test.local',
        password: 'testpass123',
      );
      final ownerId = ownerClient.auth.currentUser!.id;
      const foodId = 'other-food';
      final normalized = 'owner-food-$suffix';
      final ownerRepo = SupabaseSavedFoodRepository(client: ownerClient);
      await ownerRepo.upsertOwnPrivate(
        userId: ownerId,
        food: sampleIntegrationFood(
          userId: ownerId,
          foodId: foodId,
          normalizedName: normalized,
        ),
      );

      final otherRepo = SupabaseSavedFoodRepository(client: otherClient);
      await expectLater(
        otherRepo.publish(
          userId: otherClient.auth.currentUser!.id,
          foodId: foodId,
        ),
        throwsA(isA<PublishSavedFoodException>()),
      );
    });

    test('unpublish and public edit bump version', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final client = await createAuthenticatedClient(
        service: service,
        email: 'integration-edit-$suffix@test.local',
        password: 'testpass123',
      );
      final userId = client.auth.currentUser!.id;
      final repo = SupabaseSavedFoodRepository(client: client);
      const foodId = 'edit-food';
      final normalized = 'edit-cabbage-$suffix';

      await repo.upsertOwnPrivate(
        userId: userId,
        food: sampleIntegrationFood(
          userId: userId,
          foodId: foodId,
          normalizedName: normalized,
        ),
      );
      final published = await repo.publish(userId: userId, foodId: foodId);
      expect(published.version, 1);

      final updated = await repo.updateOwnRow(
        userId: userId,
        food: published.copyWith(
          kcalPerBase: 180,
          version: published.version + 1,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      expect(updated.kcalPerBase, 180);
      expect(updated.version, greaterThanOrEqualTo(2));

      final unpublished = await repo.unpublish(userId: userId, foodId: foodId);
      expect(unpublished.visibility, FoodVisibility.private);
    });

    test('network failure maps to publish network error', () async {
      final repo = SupabaseSavedFoodRepository(
        client: SupabaseClient('http://127.0.0.1:59999', _anonKey),
      );

      await expectLater(
        repo.publish(userId: 'missing', foodId: 'missing'),
        throwsA(
          isA<PublishSavedFoodException>().having(
            (e) => e.kind,
            'kind',
            PublishFailureKind.network,
          ),
        ),
      );
    });

    test('searchPublic returns public foods only', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-search-$suffix@test.local',
        password: 'testpass123',
      );
      final viewerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-viewer-$suffix@test.local',
        password: 'testpass123',
      );
      final ownerId = ownerClient.auth.currentUser!.id;
      final ownerRepo = SupabaseSavedFoodRepository(client: ownerClient);
      final viewerRepo = SupabaseSavedFoodRepository(client: viewerClient);
      final normalized = 'search-cabbage-$suffix';
      const publicFoodId = 'search-pub';
      const privateFoodId = 'search-priv';

      await ownerRepo.upsertOwnPrivate(
        userId: ownerId,
        food: sampleIntegrationFood(
          userId: ownerId,
          foodId: publicFoodId,
          normalizedName: normalized,
        ),
      );
      await ownerRepo.publish(userId: ownerId, foodId: publicFoodId);

      await ownerRepo.upsertOwnPrivate(
        userId: ownerId,
        food: sampleIntegrationFood(
          userId: ownerId,
          foodId: privateFoodId,
          normalizedName: normalized,
        ),
      );

      final results = await viewerRepo.searchPublic(query: normalized);
      expect(results.any((food) => food.foodId == publicFoodId), isTrue);
      expect(results.any((food) => food.foodId == privateFoodId), isFalse);
    });

    test('searchPublic finds barcode exact match', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final client = await createAuthenticatedClient(
        service: service,
        email: 'integration-barcode-$suffix@test.local',
        password: 'testpass123',
      );
      final userId = client.auth.currentUser!.id;
      final repo = SupabaseSavedFoodRepository(client: client);
      final barcode = '4900000$suffix'.substring(0, 13);
      const foodId = 'barcode-food';
      final normalized = 'barcode-cabbage-$suffix';

      await repo.upsertOwnPrivate(
        userId: userId,
        food: sampleIntegrationFood(
          userId: userId,
          foodId: foodId,
          normalizedName: normalized,
        ).copyWith(barcode: barcode),
      );
      await repo.publish(userId: userId, foodId: foodId);

      final results = await repo.searchPublic(query: barcode);
      expect(results.any((food) => food.foodId == foodId), isTrue);
    });

    test('copyPublicToPrivate creates own private snapshot', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available at $_localUrl');
      }

      final suffix = DateTime.now().microsecondsSinceEpoch;
      final ownerClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-copy-owner-$suffix@test.local',
        password: 'testpass123',
      );
      final copierClient = await createAuthenticatedClient(
        service: service,
        email: 'integration-copy-user-$suffix@test.local',
        password: 'testpass123',
      );
      final ownerId = ownerClient.auth.currentUser!.id;
      final copierId = copierClient.auth.currentUser!.id;
      final ownerRepo = SupabaseSavedFoodRepository(client: ownerClient);
      final copierRepo = SupabaseSavedFoodRepository(client: copierClient);
      const foodId = 'copy-src';
      final normalized = 'copy-cabbage-$suffix';

      await ownerRepo.upsertOwnPrivate(
        userId: ownerId,
        food: sampleIntegrationFood(
          userId: ownerId,
          foodId: foodId,
          normalizedName: normalized,
          kcal: 210,
        ),
      );
      final published = await ownerRepo.publish(
        userId: ownerId,
        foodId: foodId,
      );

      final copy = copierRepo.buildPrivateCopy(
        source: published,
        newFoodId: 'copy-new-$suffix',
        ownerUserId: copierId,
        now: DateTime.now().toUtc(),
      );
      final saved = await copierRepo.upsertOwnPrivate(
        userId: copierId,
        food: copy,
      );

      expect(saved.visibility, FoodVisibility.private);
      expect(saved.sourceType, FoodSourceType.copied);
      expect(saved.copiedFromFoodId, foodId);
      expect(saved.kcalPerBase, 210);
      expect(saved.ownerUserId, copierId);
    });
    test(
      'upsert without public.users row fails with userProfileRequired',
      () async {
        if (!available) {
          markTestSkipped('Local Supabase not available at $_localUrl');
        }

        final suffix = DateTime.now().microsecondsSinceEpoch;
        final email = 'fk-only-$suffix@test.local';
        final created = await service.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: 'testpass123',
            emailConfirm: true,
          ),
        );
        final userId = created.user!.id;
        final client = SupabaseClient(_localUrl, _anonKey);
        await client.auth.signInWithPassword(
          email: email,
          password: 'testpass123',
        );
        final repo = SupabaseSavedFoodRepository(client: client);

        await expectLater(
          repo.upsertOwnPrivate(
            userId: userId,
            food: sampleIntegrationFood(userId: userId, foodId: 'fk-only-food'),
          ),
          throwsA(
            isA<SavedFoodPersistenceException>().having(
              (error) => error.errorCode,
              'errorCode',
              SavedFoodErrorCode.userProfileRequired,
            ),
          ),
        );
      },
    );
  });
}
