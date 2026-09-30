import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/utils/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  test('home totals stay after a remote reload of the same meal', () async {
    final now = DateTime.now();
    final loggedAt = DateTime(now.year, now.month, now.day, 20, 15);
    final foods = _RemoteClockFoodRepository();
    final users = _MemoryUserRepository();
    final settings = _MemorySettingsRepository();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      userRepository: users,
      settingsRepository: settings,
      foodRepository: foods,
    );

    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 75,
        targetDate: now.add(const Duration(days: 90)),
      ),
    );

    final meal = FoodEntry(
      id: 'meal-1',
      name: '鶏むね',
      kcalPerBase: 240,
      proteinPerBase: 12,
      fatPerBase: 8,
      carbPerBase: 30,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      consumedAmount: 150,
      loggedAt: loggedAt,
    );

    await controller.addFood(meal);

    final before = controller.summary!;
    expect(before.intakeKcal, 360);
    expect(before.intakeProteinG, 18);
    expect(before.intakeFatG, 12);
    expect(before.intakeCarbG, 45);
    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.loggedAt.isUtc, isFalse);

    // 画面の再読み込みと同じく、timestamptz から読み戻した時計で集計し直す。
    foods.remoteClock = true;
    await controller.loadPersistedState();

    final reloaded = controller.foodEntries.single;
    expect(reloaded.name, '鶏むね');
    expect(reloaded.loggedAt.isUtc, isTrue);
    expect(reloaded.totalKcal, 360);
    expect(isSameLocalDay(reloaded.loggedAt, now), isTrue);

    final after = controller.summary!;
    expect(after.intakeKcal, before.intakeKcal);
    expect(after.intakeProteinG, before.intakeProteinG);
    expect(after.intakeFatG, before.intakeFatG);
    expect(after.intakeCarbG, before.intakeCarbG);
    expect(after.remainingKcal, before.remainingKcal);
  });
}

/// ローカル保存はそのまま返し、再読み込み時だけ Supabase の読み戻しを再現する。
///
/// オフセット無しの ISO 文字列は timestamptz では UTC の壁時計になる。
class _RemoteClockFoodRepository implements FoodRepositoryBase {
  final List<FoodEntry> _entries = [];
  bool remoteClock = false;

  FoodEntry _view(FoodEntry entry) {
    if (!remoteClock) {
      return entry;
    }
    final clock = entry.loggedAt;
    return entry.copyWith(
      loggedAt: DateTime.utc(
        clock.year,
        clock.month,
        clock.day,
        clock.hour,
        clock.minute,
        clock.second,
        clock.millisecond,
        clock.microsecond,
      ),
    );
  }

  @override
  Future<void> save(FoodEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    return _entries.map(_view).toList();
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}

class _MemoryUserRepository implements UserRepositoryBase {
  UserProfile? profile;
  Goal? goal;

  @override
  Future<void> saveProfile(UserProfile value) async {
    profile = value;
  }

  @override
  Future<UserProfile?> loadProfile() async => profile;

  @override
  Future<void> saveGoal(Goal value) async {
    goal = value;
  }

  @override
  Future<Goal?> loadGoal() async => goal;

  @override
  Future<void> clearAll() async {
    profile = null;
    goal = null;
  }
}

class _MemorySettingsRepository implements SettingsRepositoryBase {
  NutritionSettings? nutritionSettings;
  HealthSnapshot? healthSnapshot;
  AppSettings appSettings = const AppSettings();

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {
    nutritionSettings = settings;
  }

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => nutritionSettings;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {
    healthSnapshot = snapshot;
  }

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => healthSnapshot;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    appSettings = settings;
  }

  @override
  Future<AppSettings> loadAppSettings() async => appSettings;

  @override
  Future<void> clearAll() async {
    nutritionSettings = null;
    healthSnapshot = null;
    appSettings = const AppSettings();
  }
}
