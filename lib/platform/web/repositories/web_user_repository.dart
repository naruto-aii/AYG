import '../../../models/goal.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/contracts/user_repository_base.dart';

/// Web向けインメモリ UserRepository（Supabase同期のローカルキャッシュ）。
class UserRepository implements UserRepositoryBase {
  UserProfile? _profile;
  Goal? _goal;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveGoal(Goal goal) async {
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
