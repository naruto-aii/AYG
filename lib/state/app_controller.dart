import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/daily_summary.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/contracts/exercise_repository_base.dart';
import '../repositories/contracts/food_repository_base.dart';
import '../repositories/contracts/settings_repository_base.dart';
import '../repositories/contracts/user_repository_base.dart';
import '../repositories/contracts/weight_repository_base.dart';
import '../repositories/health_repository.dart';
import '../repositories/health_repository_support.dart';
import '../repositories/local_session_store.dart';
import '../services/local_user_data_clearer_base.dart';
import '../services/nutrition_engine.dart';

class AppController extends ChangeNotifier {
  AppController({
    NutritionEngine? nutritionEngine,
    HealthRepository? healthRepository,
    AuthenticationRepository? authenticationRepository,
    DataSyncRepository? dataSyncRepository,
    LocalSessionStore? localSessionStore,
    LocalUserDataClearerBase? localUserDataClearer,
    UserRepositoryBase? userRepository,
    SettingsRepositoryBase? settingsRepository,
    FoodRepositoryBase? foodRepository,
    ExerciseRepositoryBase? exerciseRepository,
    WeightRepositoryBase? weightRepository,
  }) : _nutritionEngine = nutritionEngine ?? NutritionEngine(),
       _healthRepository = healthRepository,
       _authenticationRepository = authenticationRepository,
       _dataSyncRepository = dataSyncRepository,
       _localSessionStore = localSessionStore,
       _localUserDataClearer = localUserDataClearer,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository;

  final NutritionEngine _nutritionEngine;
  final HealthRepository? _healthRepository;
  final AuthenticationRepository? _authenticationRepository;
  final DataSyncRepository? _dataSyncRepository;
  final LocalSessionStore? _localSessionStore;
  final LocalUserDataClearerBase? _localUserDataClearer;
  final UserRepositoryBase? _userRepository;
  final SettingsRepositoryBase? _settingsRepository;
  final FoodRepositoryBase? _foodRepository;
  final ExerciseRepositoryBase? _exerciseRepository;
  final WeightRepositoryBase? _weightRepository;

  StreamSubscription<AuthUser?>? _authSubscription;
  bool _hasInitialSyncCompleted = false;

  UserProfile? profile;
  Goal? goal;
  NutritionSettings? nutritionSettings;
  HealthProfileData healthPrefill = HealthProfileData.empty;
  HealthSnapshot healthSnapshot = HealthSnapshot.empty;
  AppSettings appSettings = const AppSettings();
  DailySummary? summary;
  final List<FoodEntry> foodEntries = [];
  final List<ExerciseEntry> exerciseEntries = [];

  bool get isAuthenticated =>
      _authenticationRepository?.isAuthenticated ?? false;

  bool get useHealthIntegration =>
      nutritionSettings?.useHealthIntegration ?? false;

  bool get onboardingComplete => appSettings.onboardingComplete;

  Future<void> initialize() async {
    final authRepository = _authenticationRepository;
    if (authRepository == null) {
      await loadPersistedState();
      return;
    }

    await authRepository.restoreSession();
    _authSubscription ??= authRepository.authStateChanges.listen((_) {
      notifyListeners();
    });

    if (authRepository.isAuthenticated) {
      await handleAuthenticatedSession();
      return;
    }

    _clearInMemoryState();
  }

  Future<void> handleAuthenticatedSession() async {
    final authUser = _authenticationRepository?.currentUser;
    final dataSyncRepository = _dataSyncRepository;
    if (authUser == null || dataSyncRepository == null) {
      return;
    }

    final lastUserId = await _localSessionStore?.loadLastUserId();
    if (lastUserId != null && lastUserId != authUser.id) {
      await _localUserDataClearer?.clearAll();
    }

    await dataSyncRepository.ensureUserProfile(
      userId: authUser.id,
      email: authUser.email,
    );

    if (lastUserId != authUser.id || !_hasInitialSyncCompleted) {
      await dataSyncRepository.pullRemoteToLocal(authUser.id);
      _hasInitialSyncCompleted = true;
      await _localSessionStore?.saveLastUserId(authUser.id);
    }

    await loadPersistedState();
    notifyListeners();
  }

  Future<void> logout() async {
    await _authenticationRepository?.logout();
    _hasInitialSyncCompleted = false;
    _clearInMemoryState();
    notifyListeners();
  }

  void _clearInMemoryState() {
    profile = null;
    goal = null;
    nutritionSettings = null;
    healthPrefill = HealthProfileData.empty;
    healthSnapshot = HealthSnapshot.empty;
    appSettings = const AppSettings();
    summary = null;
    foodEntries.clear();
    exerciseEntries.clear();
  }

  Future<void> loadPersistedState() async {
    final userRepository = _userRepository;
    final settingsRepository = _settingsRepository;
    final foodRepository = _foodRepository;
    final exerciseRepository = _exerciseRepository;
    if (userRepository == null || settingsRepository == null) {
      return;
    }

    profile = await userRepository.loadProfile();
    goal = await userRepository.loadGoal();
    nutritionSettings = await settingsRepository.loadNutritionSettings();
    healthSnapshot =
        await settingsRepository.loadHealthSnapshot() ?? HealthSnapshot.empty;
    appSettings = await settingsRepository.loadAppSettings();

    if (foodRepository != null) {
      foodEntries
        ..clear()
        ..addAll(await foodRepository.loadAll());
    }

    if (exerciseRepository != null) {
      exerciseEntries
        ..clear()
        ..addAll(await exerciseRepository.loadAll());
    }

    _recalculate();
  }

  Future<void> completeOnboarding() async {
    appSettings = appSettings.copyWith(onboardingComplete: true);
    await _settingsRepository?.saveAppSettings(appSettings);
    _scheduleRemoteSync();
    notifyListeners();
  }

  void setProfile(UserProfile value) {
    profile = _profileWithPreferredWeight(value);
    _userRepository?.saveProfile(profile!);
    _scheduleRemoteSync();
    _recalculate();
  }

  Future<void> applyHealthProfileData(HealthProfileData data) async {
    healthPrefill = data;
    healthSnapshot = HealthSnapshot(
      activeEnergyBurnedKcal: data.activeEnergyBurnedKcal,
      weightKg: data.weightKg,
    );
    await _settingsRepository?.saveHealthSnapshot(healthSnapshot);

    if (_healthRepository != null) {
      await HealthRepositorySupport.persistFetchedProfile(
        _healthRepository,
        data,
      );
    }

    final currentProfile = profile;
    if (currentProfile != null) {
      profile = _profileWithPreferredWeight(currentProfile);
      if (profile != null) {
        await _userRepository?.saveProfile(profile!);
      }
    }

    _scheduleRemoteSync();
    _recalculate();
  }

  Future<void> recordManualWeight(double weightKg) async {
    final entry = WeightEntry(
      id: generateId(),
      weightKg: weightKg,
      recordedAt: DateTime.now(),
      source: WeightSource.manual,
    );
    await _weightRepository?.save(entry);

    final currentProfile = profile;
    if (currentProfile == null) {
      return;
    }

    profile = _profileWithPreferredWeight(
      currentProfile.copyWith(weightKg: weightKg),
    );
    await _userRepository?.saveProfile(profile!);
    _scheduleRemoteSync();
    _recalculate();
  }

  void updateProfileWeight(double weightKg) {
    final currentProfile = profile;
    if (currentProfile == null) {
      return;
    }
    profile = _profileWithPreferredWeight(
      currentProfile.copyWith(weightKg: weightKg),
    );
    _userRepository?.saveProfile(profile!);
    _scheduleRemoteSync();
    _recalculate();
  }

  void setGoal(Goal value) {
    goal = value;
    _userRepository?.saveGoal(value);
    _scheduleRemoteSync();
    _recalculate();
  }

  void setNutritionSettings(NutritionSettings value) {
    nutritionSettings = value;
    _settingsRepository?.saveNutritionSettings(value);
    _scheduleRemoteSync();
    _recalculate();
  }

  void setHealthSnapshot(HealthSnapshot value) {
    healthSnapshot = value;
    _settingsRepository?.saveHealthSnapshot(value);
    _scheduleRemoteSync();
    _recalculate();
  }

  String generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  void addFood(FoodEntry entry) {
    foodEntries.add(entry);
    _foodRepository?.save(entry);
    _scheduleRemoteSync();
    _recalculate();
  }

  void updateFood(FoodEntry entry) {
    final index = foodEntries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    foodEntries[index] = entry;
    _foodRepository?.save(entry);
    _scheduleRemoteSync();
    _recalculate();
  }

  void deleteFood(String id) {
    foodEntries.removeWhere((item) => item.id == id);
    _foodRepository?.delete(id);
    _scheduleRemoteSync();
    _recalculate();
  }

  void addExercise(ExerciseEntry entry) {
    exerciseEntries.add(entry);
    _exerciseRepository?.save(entry);
    _scheduleRemoteSync();
    _recalculate();
  }

  void updateExercise(ExerciseEntry entry) {
    final index = exerciseEntries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    exerciseEntries[index] = entry;
    _exerciseRepository?.save(entry);
    _scheduleRemoteSync();
    _recalculate();
  }

  void deleteExercise(String id) {
    exerciseEntries.removeWhere((item) => item.id == id);
    _exerciseRepository?.delete(id);
    _scheduleRemoteSync();
    _recalculate();
  }

  void _scheduleRemoteSync() {
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (userId == null || dataSyncRepository == null) {
      return;
    }

    unawaited(dataSyncRepository.pushLocalToRemote(userId));
  }

  UserProfile _profileWithPreferredWeight(UserProfile manualProfile) {
    final preferredWeight = _resolvePreferredWeight(manualProfile.weightKg);
    if (preferredWeight == manualProfile.weightKg) {
      return manualProfile;
    }

    return manualProfile.copyWith(weightKg: preferredWeight);
  }

  double _resolvePreferredWeight(double manualWeightKg) {
    if (useHealthIntegration) {
      return healthSnapshot.weightKg ??
          healthPrefill.weightKg ??
          manualWeightKg;
    }

    return manualWeightKg;
  }

  void _recalculate() {
    final currentProfile = profile;
    final currentGoal = goal;
    final settings = nutritionSettings;

    if (currentProfile == null || currentGoal == null || settings == null) {
      summary = null;
      notifyListeners();
      return;
    }

    summary = _nutritionEngine.calculateDailySummary(
      profile: currentProfile,
      goal: currentGoal,
      settings: settings,
      healthSnapshot: healthSnapshot,
      foodEntries: List.unmodifiable(foodEntries),
      exerciseEntries: List.unmodifiable(exerciseEntries),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
