abstract class BlockedFoodCreatorRepositoryBase {
  Future<void> block({
    required String blockerUserId,
    required String blockedUserId,
  });

  Future<void> unblock({
    required String blockerUserId,
    required String blockedUserId,
  });

  Future<List<String>> getBlockedUserIds(String blockerUserId);

  Future<bool> isBlocked({
    required String blockerUserId,
    required String blockedUserId,
  });
}
