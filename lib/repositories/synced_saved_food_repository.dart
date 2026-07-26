import '../../models/food_visibility.dart';
import '../../models/saved_food.dart';
import '../../services/saved_food_version_policy.dart';
import 'contracts/saved_food_local_store.dart';
import 'contracts/saved_food_remote_store.dart';
import 'contracts/saved_food_repository_base.dart';
import 'exceptions/food_master_exceptions.dart';

/// Local First saved foods with optional Supabase remote.
class SyncedSavedFoodRepository extends SavedFoodRepositoryBase {
  SyncedSavedFoodRepository({
    required SavedFoodLocalStore local,
    SavedFoodRemoteStore? remote,
  }) : _local = local,
       _remote = remote;

  final SavedFoodLocalStore _local;
  final SavedFoodRemoteStore? _remote;

  @override
  Future<void> savePrivate(SavedFood food) async {
    final normalized = food.normalizedForSave();
    await _local.savePrivate(normalized);
    await _remote?.upsertOwnPrivate(
      userId: normalized.ownerUserId,
      food: normalized,
    );
  }

  @override
  Future<void> updateOwn(SavedFood food) async {
    final existing = await _local.getOwn(
      ownerUserId: food.ownerUserId,
      foodId: food.foodId,
    );
    var normalized = food.normalizedForSave();
    if (existing != null) {
      normalized = SavedFoodVersionPolicy.applyVersionOnUpdate(
        previous: existing,
        next: normalized,
      );
    }
    await _local.updateOwn(normalized);
    if (_remote == null) {
      return;
    }
    if (normalized.visibility == FoodVisibility.public) {
      await _remote!.updateOwnRow(
        userId: normalized.ownerUserId,
        food: normalized,
      );
      return;
    }
    await _remote!.upsertOwnPrivate(
      userId: normalized.ownerUserId,
      food: normalized,
    );
  }

  @override
  Future<SavedFood> publish({
    required String ownerUserId,
    required String foodId,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw const FoodMasterNetworkException('Supabase is not configured.');
    }
    final published = await remote.publish(userId: ownerUserId, foodId: foodId);
    await _local.updateOwn(published);
    return published;
  }

  @override
  Future<SavedFood> unpublish({
    required String ownerUserId,
    required String foodId,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw const FoodMasterNetworkException('Supabase is not configured.');
    }
    final unpublished = await remote.unpublish(
      userId: ownerUserId,
      foodId: foodId,
    );
    await _local.updateOwn(unpublished);
    return unpublished;
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {
    await _local.softDelete(
      ownerUserId: ownerUserId,
      foodId: foodId,
      deletedAt: deletedAt,
    );
    final existing = await _local.getOwn(
      ownerUserId: ownerUserId,
      foodId: foodId,
    );
    if (existing != null && _remote != null) {
      await _remote!.updateOwnRow(userId: ownerUserId, food: existing);
    }
  }

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) => _local.getOwn(ownerUserId: ownerUserId, foodId: foodId);

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) => _local.searchOwn(ownerUserId: ownerUserId, query: query);

  @override
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw const FoodMasterNetworkException('Supabase is not configured.');
    }
    return remote.searchPublic(query: query, limit: limit);
  }

  @override
  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw const FoodMasterNetworkException('Supabase is not configured.');
    }
    return remote.getPublicById(ownerUserId: ownerUserId, foodId: foodId);
  }

  @override
  Future<SavedFood> copyPublicToPrivate({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) async {
    final remote = _remote;
    if (remote == null) {
      throw const FoodMasterNetworkException('Supabase is not configured.');
    }
    final copy = remote.buildPrivateCopy(
      source: source,
      newFoodId: newFoodId,
      ownerUserId: ownerUserId,
      now: now,
    );
    await savePrivate(copy);
    return copy;
  }

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    await _local.clearAllLocal();
    if (foods.isEmpty) {
      return;
    }
    await _local.saveAllPrivate(foods);
  }

  @override
  Future<List<SavedFood>> pullAllOwnRemote(String ownerUserId) async {
    final remote = _remote;
    if (remote == null) {
      return const [];
    }
    return remote.pullAllOwn(ownerUserId);
  }

  @override
  Future<void> pushAllOwnRemote(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    await _remote?.pushAllOwn(ownerUserId, foods);
  }

  @override
  Future<void> clearAllLocal() => _local.clearAllLocal();
}
