import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/repositories/data_sync_repository.dart';

class MockDataSyncRepository implements DataSyncRepository {
  bool ensureUserProfileCalled = false;
  bool pullRemoteToLocalCalled = false;
  bool pushLocalToRemoteCalled = false;
  bool failPull = false;
  bool failDeleteFoodEntry = false;

  bool failDeleteAlcoholEntry = false;

  bool failDeleteExerciseEntry = false;

  bool failDeleteWeightEntry = false;

  @override
  bool get supportsRemoteFoodEntryDelete => true;

  @override
  bool get supportsRemoteAlcoholEntryDelete => true;

  @override
  bool get supportsRemoteExerciseEntryDelete => true;

  @override
  bool get supportsRemoteWeightEntryDelete => true;

  String? lastUserId;
  String? lastEmail;
  final deletedFoodEntryIds = <String>[];
  final deletedAlcoholEntryIds = <String>[];
  final deletedExerciseEntryIds = <String>[];
  final deletedWeightEntryIds = <String>[];

  @override
  Future<RemoteUserProfile> ensureUserProfile({
    required String userId,
    String? email,
  }) async {
    ensureUserProfileCalled = true;
    lastUserId = userId;
    lastEmail = email;
    return RemoteUserProfile(
      id: userId,
      email: email,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<RemoteUserProfile?> fetchUserProfile(String userId) async {
    return RemoteUserProfile(
      id: userId,
      email: 'existing@example.com',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<void> pullRemoteToLocal(String userId) async {
    pullRemoteToLocalCalled = true;
    lastUserId = userId;
    if (failPull) {
      throw SyncStepException(
        SyncFailure.from(
          step: SyncStep.fetchSavedFoods,
          error: StateError('saved foods pull failed'),
          repository: 'MockDataSyncRepository',
          tableName: 'saved_foods',
          operation: 'select',
        ),
      );
    }
  }

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {
    lastUserId = userId;
    if (failPull) {
      throw StateError('pull saved foods failed');
    }
  }

  @override
  Future<void> pushLocalToRemote(String userId) async {
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
  }

  @override
  Future<void> deleteFoodEntry({
    required String userId,
    required String entryId,
  }) async {
    lastUserId = userId;
    if (failDeleteFoodEntry) {
      throw StateError('delete food entry failed');
    }
    deletedFoodEntryIds.add(entryId);
  }

  @override
  Future<void> deleteAlcoholEntry({
    required String userId,
    required String entryId,
  }) async {
    lastUserId = userId;
    if (failDeleteAlcoholEntry) {
      throw StateError('delete alcohol entry failed');
    }
    deletedAlcoholEntryIds.add(entryId);
  }

  @override
  Future<void> deleteExerciseEntry({
    required String userId,
    required String entryId,
  }) async {
    lastUserId = userId;
    if (failDeleteExerciseEntry) {
      throw StateError('delete exercise entry failed');
    }
    deletedExerciseEntryIds.add(entryId);
  }

  @override
  Future<void> deleteWeightEntry({
    required String userId,
    required String entryId,
  }) async {
    lastUserId = userId;
    if (failDeleteWeightEntry) {
      throw StateError('delete weight entry failed');
    }
    deletedWeightEntryIds.add(entryId);
  }
}
