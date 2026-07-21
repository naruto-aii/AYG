import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository(this._isar);

  final Isar _isar;

  Future<void> saveProfile(UserProfile profile) async {
    await _isar.writeTxn(() async {
      await _isar.userProfileEntitys.put(
        EntityMapper.toUserProfileEntity(profile),
      );
    });
  }

  Future<UserProfile?> loadProfile() async {
    final entity = await _isar.userProfileEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromUserProfileEntity(entity);
  }

  Future<void> saveGoal(Goal goal) async {
    await _isar.writeTxn(() async {
      await _isar.goalEntitys.put(EntityMapper.toGoalEntity(goal));
    });
  }

  Future<Goal?> loadGoal() async {
    final entity = await _isar.goalEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromGoalEntity(entity);
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.userProfileEntitys.clear();
      await _isar.goalEntitys.clear();
    });
  }
}
