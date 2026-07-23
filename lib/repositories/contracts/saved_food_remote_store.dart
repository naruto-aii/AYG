import '../../models/saved_food.dart';

abstract class SavedFoodRemoteStore {
  Future<SavedFood> upsertOwnPrivate({
    required String userId,
    required SavedFood food,
  });

  Future<SavedFood> updateOwnRow({
    required String userId,
    required SavedFood food,
  });

  Future<SavedFood> publish({required String userId, required String foodId});

  Future<SavedFood> unpublish({required String userId, required String foodId});

  Future<List<SavedFood>> pullAllOwn(String userId);

  Future<void> pushAllOwn(String userId, List<SavedFood> foods);

  Future<List<SavedFood>> searchPublic({required String query, int limit = 50});

  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  });

  SavedFood buildPrivateCopy({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  });
}
