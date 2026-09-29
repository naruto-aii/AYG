import '../../models/goal.dart';
import '../../models/user_profile.dart';

abstract class UserRepositoryBase {
  Future<void> saveProfile(UserProfile profile);

  Future<UserProfile?> loadProfile();

  Future<void> saveGoal(Goal goal);

  Future<Goal?> loadGoal();

  Future<void> clearAll();
}
