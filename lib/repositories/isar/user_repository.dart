import 'package:isar/isar.dart';

import '../../database/entity_mapper.dart';
import '../../database/schemas.dart';
import '../../models/goal.dart';
import '../../models/user_profile.dart';
import '../contracts/user_repository_base.dart';
import '../local_write_guard.dart';

class UserRepository implements UserRepositoryBase {
  UserRepository(this._isar);

  final Isar _isar;

  Future<void> saveProfile(UserProfile profile) async {
    await _isar.writeTxn(() async {
      await _isar.userProfileEntitys.put(
        EntityMapper.toUserProfileEntity(profile),
      );
    });
  }

  /// 同期の取得だけが使う。画面の保存は [saveProfile]。
  Future<void> saveProfileForSync(
    UserProfile profile, {
    LocalWriteGuard? mayWrite,
  }) async {
    await _isar.writeTxn(() async {
      if (!localWriteAllowed(mayWrite)) {
        return;
      }
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

  Future<void> saveGoalForSync(Goal goal, {LocalWriteGuard? mayWrite}) async {
    await _isar.writeTxn(() async {
      if (!localWriteAllowed(mayWrite)) {
        return;
      }
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
