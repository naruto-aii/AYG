import '../../../models/goal.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/contracts/user_repository_base.dart';
import '../../../repositories/local_write_guard.dart';

/// Web向けインメモリ UserRepository（Supabase同期のローカルキャッシュ）。
class UserRepository implements UserRepositoryBase {
  UserProfile? _profile;
  Goal? _goal;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }

  Future<void> saveProfileForSync(
    UserProfile profile, {
    LocalWriteGuard? mayWrite,
  }) async {
    if (!localWriteAllowed(mayWrite)) {
      return;
    }
    _profile = profile;
  }

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveGoal(Goal goal) async {
    _goal = goal;
  }

  Future<void> saveGoalForSync(Goal goal, {LocalWriteGuard? mayWrite}) async {
    if (!localWriteAllowed(mayWrite)) {
      return;
    }
    _goal = goal;
  }

  @override
  Future<Goal?> loadGoal() async => _goal;

  @override
  Future<void> clearAll() async {
    _profile = null;
    _goal = null;
  }
}
