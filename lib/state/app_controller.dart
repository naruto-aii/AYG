import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_strings.dart';
import '../models/app_settings.dart';
import '../models/activity_level.dart';
import '../models/daily_summary.dart';
import '../models/duplicate_saved_food_action.dart';
import '../models/duplicate_saved_food_resolution.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/food_status.dart';
import '../models/food_visibility.dart';
import '../models/meal_template.dart';
import '../models/meal_template_apply.dart';
import '../models/meal_template_draft.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../models/saved_food_draft.dart';
import '../models/saved_food_entry_selection.dart';
import '../models/food_report.dart';
import '../models/public_food_publish_match.dart';
import '../models/public_food_rating_view.dart';
import '../models/public_food_search_match.dart';
import '../models/saved_food_publish_validation.dart';
import '../models/save_food_entry_result.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/exceptions/food_master_exceptions.dart';
import '../repositories/contracts/blocked_food_creator_repository_base.dart';
import '../repositories/contracts/food_rating_repository_base.dart';
import '../repositories/contracts/food_report_repository_base.dart';
import '../repositories/contracts/saved_food_repository_base.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/contracts/meal_template_repository_base.dart';
import '../repositories/health_repository.dart';
import '../repositories/health_repository_support.dart';
import '../repositories/local_session_store.dart';
import '../repositories/contracts/meal_template_repository_base.dart';
import '../services/local_user_data_clearer_base.dart';
import '../services/meal_template_apply_service.dart';
import '../services/meal_template_dependency_service.dart';
import '../services/meal_template_totals_service.dart';
import '../repositories/contracts/user_repository_base.dart';
import '../repositories/contracts/settings_repository_base.dart';
import '../repositories/contracts/food_repository_base.dart';
import '../repositories/contracts/exercise_repository_base.dart';
import '../repositories/contracts/weight_repository_base.dart';
import '../services/nutrition_engine.dart';
import '../services/public_food_search_service.dart';
import '../services/public_food_similar_service.dart';
import '../services/publish_error_messages.dart';
import '../services/saved_food_duplicate_service.dart';
import '../services/saved_food_entry_builder.dart';
import '../services/saved_food_publish_validator.dart';
import '../services/saved_food_search_service.dart';
import '../services/saved_food_version_policy.dart';
import '../utils/food_name_normalizer.dart';

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
    SavedFoodRepositoryBase? savedFoodRepository,
    FoodRatingRepositoryBase? foodRatingRepository,
    FoodReportRepositoryBase? foodReportRepository,
    BlockedFoodCreatorRepositoryBase? blockedCreatorRepository,
    MealTemplateRepositoryBase? mealTemplateRepository,
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
       _weightRepository = weightRepository,
       _savedFoodRepository = savedFoodRepository,
       _foodRatingRepository = foodRatingRepository,
       _foodReportRepository = foodReportRepository,
       _blockedCreatorRepository = blockedCreatorRepository,
       _mealTemplateRepository = mealTemplateRepository,
       _savedFoodSearchService = const SavedFoodSearchService(),
       _savedFoodDuplicateService = const SavedFoodDuplicateService(),
       _savedFoodEntryBuilder = const SavedFoodEntryBuilder(),
       _savedFoodPublishValidator = const SavedFoodPublishValidator(),
       _publicFoodSimilarService = const PublicFoodSimilarService(),
       _publicFoodSearchService = const PublicFoodSearchService(),
       _mealTemplateTotalsService = const MealTemplateTotalsService(),
       _mealTemplateDependencyService = const MealTemplateDependencyService(),
       _mealTemplateApplyService = const MealTemplateApplyService();

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
  final SavedFoodRepositoryBase? _savedFoodRepository;
  final FoodRatingRepositoryBase? _foodRatingRepository;
  final FoodReportRepositoryBase? _foodReportRepository;
  final BlockedFoodCreatorRepositoryBase? _blockedCreatorRepository;
  final MealTemplateRepositoryBase? _mealTemplateRepository;
  final SavedFoodSearchService _savedFoodSearchService;
  final SavedFoodDuplicateService _savedFoodDuplicateService;
  final SavedFoodEntryBuilder _savedFoodEntryBuilder;
  final SavedFoodPublishValidator _savedFoodPublishValidator;
  final PublicFoodSimilarService _publicFoodSimilarService;
  final PublicFoodSearchService _publicFoodSearchService;
  final MealTemplateTotalsService _mealTemplateTotalsService;
  final MealTemplateDependencyService _mealTemplateDependencyService;
  final MealTemplateApplyService _mealTemplateApplyService;

  bool _publishOperationInProgress = false;
  final Set<String> _ratingOperationsInProgress = {};

  bool get isPublishOperationInProgress => _publishOperationInProgress;

  /// 未ログイン時のローカル専用 owner ID。
  static const localOwnerUserId = 'local-user';

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

  String get currentOwnerUserId =>
      _authenticationRepository?.currentUser?.id ?? localOwnerUserId;

  bool get useHealthIntegration =>
      nutritionSettings?.useHealthIntegration ?? false;

  bool get onboardingComplete => appSettings.onboardingComplete;

  bool get isHealthRepositoryAvailable =>
      _healthRepository?.isAvailable ?? false;

  /// 計算に使用している体重のデータソース。
  WeightDataSource get weightDataSource {
    if (!useHealthIntegration) {
      return WeightDataSource.manual;
    }
    if (healthSnapshot.weightKg != null || healthPrefill.weightKg != null) {
      return WeightDataSource.health;
    }
    return WeightDataSource.healthPending;
  }

  String get weightDataSourceLabel {
    return switch (weightDataSource) {
      WeightDataSource.manual => AppStrings.weightSourceManual,
      WeightDataSource.health => AppStrings.weightSourceHealth,
      WeightDataSource.healthPending => AppStrings.weightSourceHealthPending,
    };
  }

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

    refreshDailySummary();
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
    refreshDailySummary();
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
    refreshDailySummary();
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
    refreshDailySummary();
  }

  Future<void> updateBasicProfile({
    required DateTime birthDate,
    required Gender gender,
    required double heightCm,
    double? manualWeightKg,
  }) async {
    final currentProfile = profile;
    if (currentProfile == null) {
      return;
    }

    final weightChanged =
        manualWeightKg != null &&
        (manualWeightKg - currentProfile.weightKg).abs() > 0.009;

    if (weightChanged && !useHealthIntegration) {
      await recordManualWeight(manualWeightKg);
      profile = profile!.copyWith(
        birthDate: birthDate,
        gender: gender,
        heightCm: heightCm,
      );
      await _userRepository?.saveProfile(profile!);
      _scheduleRemoteSync();
      refreshDailySummary();
      return;
    }

    var nextProfile = currentProfile.copyWith(
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
    );

    if (weightChanged && useHealthIntegration) {
      final entry = WeightEntry(
        id: generateId(),
        weightKg: manualWeightKg,
        recordedAt: DateTime.now(),
        source: WeightSource.manual,
      );
      await _weightRepository?.save(entry);
      nextProfile = nextProfile.copyWith(weightKg: manualWeightKg);
    }

    profile = _profileWithPreferredWeight(nextProfile);
    await _userRepository?.saveProfile(profile!);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> saveGoalSettings(Goal value) async {
    goal = value;
    await _userRepository?.saveGoal(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> saveNutritionSettingsSettings(NutritionSettings value) async {
    nutritionSettings = value;
    await _settingsRepository?.saveNutritionSettings(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> updateActivityLevel(ActivityLevel activityLevel) async {
    await saveNutritionSettingsSettings(
      NutritionSettings(
        useHealthIntegration: false,
        activityLevel: activityLevel,
      ),
    );
  }

  Future<bool> enableHealthIntegration() async {
    final healthRepository = _healthRepository;
    if (healthRepository == null || !healthRepository.isAvailable) {
      return false;
    }

    final granted = await healthRepository.requestPermissions();
    final profileData = granted
        ? await healthRepository.fetchProfileData()
        : HealthProfileData.empty;

    await saveNutritionSettingsSettings(
      const NutritionSettings(useHealthIntegration: true),
    );
    await applyHealthProfileData(profileData);
    return granted;
  }

  Future<void> disableHealthIntegration({ActivityLevel? activityLevel}) async {
    final fallbackLevel =
        activityLevel ??
        nutritionSettings?.activityLevel ??
        ActivityLevel.moderate;
    await saveNutritionSettingsSettings(
      NutritionSettings(
        useHealthIntegration: false,
        activityLevel: fallbackLevel,
      ),
    );
  }

  Future<bool> resyncHealthData() async {
    final healthRepository = _healthRepository;
    if (healthRepository == null || !useHealthIntegration) {
      return false;
    }

    final profileData = await healthRepository.fetchProfileData();
    await applyHealthProfileData(profileData);
    return profileData.weightKg != null ||
        profileData.activeEnergyBurnedKcal != null;
  }

  void setGoal(Goal value) {
    goal = value;
    _userRepository?.saveGoal(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  void setNutritionSettings(NutritionSettings value) {
    nutritionSettings = value;
    _settingsRepository?.saveNutritionSettings(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  void setHealthSnapshot(HealthSnapshot value) {
    healthSnapshot = value;
    _settingsRepository?.saveHealthSnapshot(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  /// 当日の食事・運動を Repository から再取得し、Nutrition Engine を実行する。
  void refreshDailySummary({DateTime? referenceDate}) {
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
      referenceDate: referenceDate ?? DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> _reloadFoodEntries() async {
    final foodRepository = _foodRepository;
    if (foodRepository == null) {
      return;
    }
    foodEntries
      ..clear()
      ..addAll(await foodRepository.loadAll());
  }

  Future<void> _reloadExerciseEntries() async {
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository == null) {
      return;
    }
    exerciseEntries
      ..clear()
      ..addAll(await exerciseRepository.loadAll());
  }

  String generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> addFood(FoodEntry entry) async {
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.save(entry);
      await _reloadFoodEntries();
    } else {
      foodEntries.add(entry);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> updateFood(FoodEntry entry) async {
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.save(entry);
      await _reloadFoodEntries();
    } else {
      final index = foodEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        return;
      }
      foodEntries[index] = entry;
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> deleteFood(String id) async {
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.delete(id);
      await _reloadFoodEntries();
    } else {
      foodEntries.removeWhere((item) => item.id == id);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> addExercise(ExerciseEntry entry) async {
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.save(entry);
      await _reloadExerciseEntries();
    } else {
      exerciseEntries.add(entry);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> updateExercise(ExerciseEntry entry) async {
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.save(entry);
      await _reloadExerciseEntries();
    } else {
      final index = exerciseEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        return;
      }
      exerciseEntries[index] = entry;
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> deleteExercise(String id) async {
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.delete(id);
      await _reloadExerciseEntries();
    } else {
      exerciseEntries.removeWhere((item) => item.id == id);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  // --- Saved food (Phase 6A–6C) ---

  Future<SavedFood> createSavedFood(SavedFoodDraft draft) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }
    if (draft.visibility != FoodVisibility.private) {
      throw UnsupportedError('Only private foods can be saved in Phase 6A–6C');
    }

    final now = DateTime.now();
    final food = SavedFood(
      foodId: generateId(),
      ownerUserId: currentOwnerUserId,
      name: draft.name.trim(),
      normalizedName: FoodNameNormalizer.normalize(draft.name),
      baseAmount: draft.baseAmount,
      unitType: draft.unitType,
      kcalPerBase: draft.kcalPerBase,
      proteinPerBase: draft.proteinPerBase,
      fatPerBase: draft.fatPerBase,
      carbPerBase: draft.carbPerBase,
      brand: draft.brand,
      barcode: draft.barcode,
      supplementaryWeight: draft.supplementaryWeight,
      sourceType: draft.sourceType,
      visibility: FoodVisibility.private,
      status: FoodStatus.active,
      createdAt: now,
      updatedAt: now,
    ).normalizedForSave();

    await repository.savePrivate(food);
    _scheduleRemoteSync();
    return food;
  }

  Future<SavedFood> updateSavedFood(SavedFood food) async {
    if (food.visibility == FoodVisibility.public) {
      throw StateError('Use updatePublishedSavedFood for public foods');
    }
    return _updateOwnSavedFood(food);
  }

  Future<SavedFood> updatePublishedSavedFood(
    SavedFood food, {
    required bool confirmedPublicUpdate,
  }) async {
    if (food.visibility != FoodVisibility.public) {
      return updateSavedFood(food);
    }

    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    final existing = await repository.getOwn(
      ownerUserId: currentOwnerUserId,
      foodId: food.foodId,
    );
    if (existing == null) {
      throw StateError('Saved food not found');
    }

    if (SavedFoodVersionPolicy.requiresPublicUpdateConfirmation(
          existing,
          food,
        ) &&
        !confirmedPublicUpdate) {
      throw StateError('Public update confirmation is required');
    }

    return _updateOwnSavedFood(food, previous: existing);
  }

  Future<SavedFood> _updateOwnSavedFood(
    SavedFood food, {
    SavedFood? previous,
  }) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    var updated = food
        .copyWith(
          updatedAt: DateTime.now(),
          normalizedName: FoodNameNormalizer.normalize(food.name),
        )
        .normalizedForSave();

    if (previous != null) {
      updated = SavedFoodVersionPolicy.applyVersionOnUpdate(
        previous: previous,
        next: updated,
      );
    }

    await repository.updateOwn(updated);
    _scheduleRemoteSync();
    return updated;
  }

  SavedFoodPublishValidationResult validateSavedFoodForPublish(SavedFood food) {
    return _savedFoodPublishValidator.validate(
      food: food,
      ownerUserId: currentOwnerUserId,
    );
  }

  Future<PublicFoodPublishMatch?> checkPublicDuplicate(SavedFood food) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return null;
    }

    final duplicate = await repository.findExactPublicDuplicate(
      normalizedName: food.normalizedName,
      baseAmount: food.baseAmount,
      unitType: food.unitType,
      excludeOwnerUserId: food.ownerUserId,
      excludeFoodId: food.foodId,
    );
    return _toPublishMatch(duplicate);
  }

  Future<List<PublicFoodSimilarMatch>> findSimilarPublicFoods(
    SavedFood food,
  ) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }

    final candidates = await repository.findSimilarPublicFoods(food: food);
    final matches = <PublicFoodSimilarMatch>[];
    for (final candidate in candidates) {
      if (_publicFoodSimilarService.isExactDuplicatePublic(
        candidate: candidate,
        source: food,
      )) {
        continue;
      }
      final summary = await _foodRatingRepository?.getSummary(
        foodOwnerUserId: candidate.ownerUserId,
        foodId: candidate.foodId,
      );
      matches.addAll(
        _publicFoodSimilarService.classify(
          candidate: candidate,
          source: food,
          goodCount: summary?.goodCount ?? 0,
          badCount: summary?.badCount ?? 0,
        ),
      );
    }
    return _publicFoodSimilarService.mergeMatches(matches);
  }

  Future<SavedFood> publishSavedFood(String foodId) async {
    if (_publishOperationInProgress) {
      throw StateError('Publish operation already in progress');
    }

    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    _publishOperationInProgress = true;
    notifyListeners();
    try {
      final food = await repository.getOwn(
        ownerUserId: currentOwnerUserId,
        foodId: foodId,
      );
      if (food == null) {
        throw StateError('Saved food not found');
      }

      final validation = validateSavedFoodForPublish(food);
      if (!validation.isValid) {
        throw FoodMasterValidationException(validation.errors.join('\n'));
      }

      return await repository.publish(
        ownerUserId: currentOwnerUserId,
        foodId: foodId,
      );
    } finally {
      _publishOperationInProgress = false;
      notifyListeners();
    }
  }

  Future<SavedFood> unpublishSavedFood(String foodId) async {
    if (_publishOperationInProgress) {
      throw StateError('Publish operation already in progress');
    }

    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    _publishOperationInProgress = true;
    notifyListeners();
    try {
      return await repository.unpublish(
        ownerUserId: currentOwnerUserId,
        foodId: foodId,
      );
    } finally {
      _publishOperationInProgress = false;
      notifyListeners();
    }
  }

  String publishErrorMessage(Object error) =>
      PublishErrorMessages.messageFor(error);

  Future<PublicFoodPublishMatch?> _toPublishMatch(SavedFood? food) async {
    if (food == null) {
      return null;
    }
    final summary = await _foodRatingRepository?.getSummary(
      foodOwnerUserId: food.ownerUserId,
      foodId: food.foodId,
    );
    return PublicFoodPublishMatch(
      food: food,
      goodCount: summary?.goodCount ?? 0,
      badCount: summary?.badCount ?? 0,
    );
  }

  Future<void> deleteSavedFood(String foodId) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    await repository.softDelete(
      ownerUserId: currentOwnerUserId,
      foodId: foodId,
      deletedAt: DateTime.now(),
    );
    _scheduleRemoteSync();
  }

  Future<List<SavedFood>> searchOwnSavedFoods(String query) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }

    final results = await repository.searchOwn(
      ownerUserId: currentOwnerUserId,
      query: query,
    );
    return _savedFoodSearchService.rankOwnResults(foods: results, query: query);
  }

  Future<List<PublicFoodSearchMatch>> searchPublicSavedFoods(
    String query,
  ) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }

    try {
      final candidates = await repository.searchPublic(query: query);
      final ratingsByKey = <String, ({int goodCount, int badCount})>{};
      for (final food in candidates) {
        final key = '${food.ownerUserId}:${food.foodId}';
        final summary = await _foodRatingRepository?.getSummary(
          foodOwnerUserId: food.ownerUserId,
          foodId: food.foodId,
        );
        ratingsByKey[key] = (
          goodCount: summary?.goodCount ?? 0,
          badCount: summary?.badCount ?? 0,
        );
      }
      return _publicFoodSearchService.rankResults(
        candidates: candidates,
        query: query,
        ratingsByKey: ratingsByKey,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<SavedFood?> getPublicSavedFood({
    required String ownerUserId,
    required String foodId,
  }) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return null;
    }

    try {
      return await repository.getPublicById(
        ownerUserId: ownerUserId,
        foodId: foodId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SavedFood> copyPublicFoodToPrivate(SavedFood source) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    final copy = await repository.copyPublicToPrivate(
      source: source,
      newFoodId: generateId(),
      ownerUserId: currentOwnerUserId,
      now: DateTime.now(),
    );
    _scheduleRemoteSync();
    return copy;
  }

  bool canEditSavedFood(SavedFood food) {
    return food.ownerUserId == currentOwnerUserId;
  }

  String _foodRatingKey(SavedFood food) => '${food.ownerUserId}:${food.foodId}';

  bool _canRatePublicFood(SavedFood food) {
    return isAuthenticated &&
        food.ownerUserId != currentOwnerUserId &&
        _foodRatingRepository != null;
  }

  Future<PublicFoodRatingView> getPublicFoodRatingView(SavedFood food) async {
    final summary = await _foodRatingRepository?.getSummary(
      foodOwnerUserId: food.ownerUserId,
      foodId: food.foodId,
    );
    final myRating = _canRatePublicFood(food)
        ? await _foodRatingRepository?.getMyRating(
            foodOwnerUserId: food.ownerUserId,
            foodId: food.foodId,
            raterUserId: currentOwnerUserId,
          )
        : null;

    return PublicFoodRatingView(
      goodCount: summary?.goodCount ?? 0,
      badCount: summary?.badCount ?? 0,
      myRating: myRating?.ratingType,
      canRate: _canRatePublicFood(food),
    );
  }

  Future<PublicFoodRatingResult> setPublicFoodGood(SavedFood food) =>
      _mutatePublicFoodRating(
        food: food,
        mutate: (ratingId) => _foodRatingRepository!.setGood(
          foodOwnerUserId: food.ownerUserId,
          foodId: food.foodId,
          raterUserId: currentOwnerUserId,
          ratingId: ratingId,
        ),
      );

  Future<PublicFoodRatingResult> setPublicFoodBad(SavedFood food) =>
      _mutatePublicFoodRating(
        food: food,
        mutate: (ratingId) => _foodRatingRepository!.setBad(
          foodOwnerUserId: food.ownerUserId,
          foodId: food.foodId,
          raterUserId: currentOwnerUserId,
          ratingId: ratingId,
        ),
      );

  Future<PublicFoodRatingResult> clearPublicFoodRating(SavedFood food) async {
    final key = _foodRatingKey(food);
    if (!_canRatePublicFood(food) ||
        _ratingOperationsInProgress.contains(key)) {
      return const PublicFoodRatingResult(
        success: false,
        errorMessage: '評価を取消できません',
      );
    }

    _ratingOperationsInProgress.add(key);
    try {
      await _foodRatingRepository!.clearRating(
        foodOwnerUserId: food.ownerUserId,
        foodId: food.foodId,
        raterUserId: currentOwnerUserId,
      );
      final view = await getPublicFoodRatingView(food);
      return PublicFoodRatingResult(success: true, view: view);
    } catch (error) {
      return PublicFoodRatingResult(
        success: false,
        errorMessage: error.toString(),
      );
    } finally {
      _ratingOperationsInProgress.remove(key);
    }
  }

  Future<PublicFoodRatingResult> _mutatePublicFoodRating({
    required SavedFood food,
    required Future<void> Function(String ratingId) mutate,
  }) async {
    final key = _foodRatingKey(food);
    if (!_canRatePublicFood(food)) {
      return const PublicFoodRatingResult(
        success: false,
        errorMessage: '自分の食品には評価できません',
      );
    }
    if (_ratingOperationsInProgress.contains(key)) {
      return const PublicFoodRatingResult(
        success: false,
        errorMessage: '評価処理中です',
      );
    }

    _ratingOperationsInProgress.add(key);
    try {
      final existing = await _foodRatingRepository!.getMyRating(
        foodOwnerUserId: food.ownerUserId,
        foodId: food.foodId,
        raterUserId: currentOwnerUserId,
      );
      final ratingId = existing?.ratingId ?? generateId();
      await mutate(ratingId);
      final view = await getPublicFoodRatingView(food);
      return PublicFoodRatingResult(success: true, view: view);
    } catch (error) {
      return PublicFoodRatingResult(
        success: false,
        errorMessage: error.toString(),
      );
    } finally {
      _ratingOperationsInProgress.remove(key);
    }
  }

  Future<bool> hasReportedPublicFood(SavedFood food) async {
    final repository = _foodReportRepository;
    if (repository == null || !isAuthenticated) {
      return false;
    }

    final reports = await repository.getMyReports(currentOwnerUserId);
    return reports.any(
      (report) =>
          report.targetFoodId == food.foodId &&
          report.targetFoodOwnerUserId == food.ownerUserId,
    );
  }

  Future<PublicFoodReportResult> submitPublicFoodReport({
    required SavedFood food,
    required FoodReportReasonCode reasonCode,
    String? detailText,
  }) async {
    final repository = _foodReportRepository;
    if (repository == null || !isAuthenticated) {
      return const PublicFoodReportResult(
        success: false,
        errorMessage: 'ログインが必要です',
      );
    }
    if (food.ownerUserId == currentOwnerUserId) {
      return const PublicFoodReportResult(
        success: false,
        errorMessage: '自分の食品は通報できません',
      );
    }
    if (await hasReportedPublicFood(food)) {
      return const PublicFoodReportResult(
        success: false,
        errorMessage: 'この食品はすでに通報済みです',
      );
    }

    try {
      await repository.submitReport(
        reportId: generateId(),
        reporterUserId: currentOwnerUserId,
        targetFoodOwnerUserId: food.ownerUserId,
        targetFoodId: food.foodId,
        reasonCode: reasonCode,
        detailText: detailText,
      );
      return const PublicFoodReportResult(success: true);
    } catch (error) {
      return PublicFoodReportResult(
        success: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<List<FoodReport>> getMyPublicFoodReports() async {
    final repository = _foodReportRepository;
    if (repository == null || !isAuthenticated) {
      return const [];
    }
    return repository.getMyReports(currentOwnerUserId);
  }

  Future<void> blockFoodCreator(String creatorUserId) async {
    final repository = _blockedCreatorRepository;
    if (repository == null || !isAuthenticated) {
      throw StateError('Blocked creator repository is not configured');
    }
    if (creatorUserId == currentOwnerUserId) {
      throw StateError('Cannot block yourself');
    }
    await repository.block(
      blockerUserId: currentOwnerUserId,
      blockedUserId: creatorUserId,
    );
  }

  Future<void> unblockFoodCreator(String creatorUserId) async {
    final repository = _blockedCreatorRepository;
    if (repository == null || !isAuthenticated) {
      throw StateError('Blocked creator repository is not configured');
    }
    await repository.unblock(
      blockerUserId: currentOwnerUserId,
      blockedUserId: creatorUserId,
    );
  }

  Future<bool> isFoodCreatorBlocked(String creatorUserId) async {
    final repository = _blockedCreatorRepository;
    if (repository == null || !isAuthenticated) {
      return false;
    }
    return repository.isBlocked(
      blockerUserId: currentOwnerUserId,
      blockedUserId: creatorUserId,
    );
  }

  Future<SavedFood?> findPrivateDuplicateSavedFood(
    String name, {
    String? excludeFoodId,
  }) async {
    final ownFoods = await searchOwnSavedFoods('');
    return _savedFoodDuplicateService.findPrivateDuplicateByName(
      ownFoods: ownFoods,
      name: name,
      excludeFoodId: excludeFoodId,
    );
  }

  Future<void> addFoodEntriesBatch(List<FoodEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.saveAll(entries);
      await _reloadFoodEntries();
    } else {
      foodEntries.addAll(entries);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<List<MealTemplate>> searchMealTemplates(String query) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return const [];
    }
    return repository.search(ownerUserId: currentOwnerUserId, query: query);
  }

  Future<MealTemplateWithItems?> getMealTemplateWithItems(
    String templateId,
  ) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return null;
    }
    final template = await repository.getById(
      ownerUserId: currentOwnerUserId,
      templateId: templateId,
    );
    if (template == null) {
      return null;
    }
    final items = await repository.getItems(
      ownerUserId: currentOwnerUserId,
      templateId: templateId,
    );
    return MealTemplateWithItems(template: template, items: items);
  }

  Future<void> _saveTemplateWithItems({
    required MealTemplateRepositoryBase repository,
    required MealTemplate template,
    required List<MealTemplateItem> items,
  }) async {
    await repository.saveWithItems(template: template, items: items);
  }

  Future<MealTemplate> saveMealTemplate({
    required MealTemplateDraft draft,
    String? templateId,
  }) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      throw StateError('MealTemplateRepository is not configured');
    }
    if (draft.name.trim().isEmpty) {
      throw ArgumentError('Template name is required');
    }
    if (draft.items.isEmpty) {
      throw ArgumentError('Template must include at least one item');
    }

    final now = DateTime.now();
    final id = templateId ?? generateId();
    final existing = templateId == null
        ? null
        : await repository.getById(
            ownerUserId: currentOwnerUserId,
            templateId: id,
          );
    final items = draft.items.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final mappedItems = items
        .asMap()
        .entries
        .map(
          (entry) => entry.value
              .copyWithSortOrder(entry.key + 1)
              .toItem(itemId: entry.value.itemId ?? generateId(), now: now),
        )
        .toList();
    final totals = _mealTemplateTotalsService.totalsFromItems(mappedItems);
    final template = MealTemplate(
      templateId: id,
      ownerUserId: currentOwnerUserId,
      name: draft.name.trim(),
      normalizedName: FoodNameNormalizer.normalize(draft.name),
      totalKcal: totals.kcal,
      totalProteinG: totals.protein,
      totalFatG: totals.fat,
      totalCarbG: totals.carb,
      useCount: existing?.useCount ?? 0,
      lastUsedAt: existing?.lastUsedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _saveTemplateWithItems(
      repository: repository,
      template: template,
      items: mappedItems,
    );
    _scheduleRemoteSync();
    return template;
  }

  Future<void> deleteMealTemplate(String templateId) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      throw StateError('MealTemplateRepository is not configured');
    }
    await repository.softDelete(
      ownerUserId: currentOwnerUserId,
      templateId: templateId,
      deletedAt: DateTime.now(),
    );
    _scheduleRemoteSync();
  }

  Future<List<MealTemplateDependencyIssue>> analyzeMealTemplateDependencies(
    List<MealTemplateItem> items,
  ) {
    return _mealTemplateDependencyService.analyze(
      items: items,
      lookupFood:
          ({
            required String ownerUserId,
            required String foodId,
            required bool isOwn,
          }) async {
            final savedFoodRepository = _savedFoodRepository;
            if (savedFoodRepository == null) {
              return null;
            }
            if (ownerUserId == currentOwnerUserId) {
              return savedFoodRepository.getOwn(
                ownerUserId: ownerUserId,
                foodId: foodId,
              );
            }
            return savedFoodRepository.getPublicById(
              ownerUserId: ownerUserId,
              foodId: foodId,
            );
          },
      isCreatorBlocked: isFoodCreatorBlocked,
    );
  }

  Future<MealTemplateApplyResult> applyMealTemplate({
    required String templateId,
    List<MealTemplateItemResolution> resolutions = const [],
  }) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return const MealTemplateApplyResult(
        success: false,
        errorMessage: 'MealTemplateRepository is not configured',
      );
    }

    final bundle = await getMealTemplateWithItems(templateId);
    if (bundle == null) {
      return const MealTemplateApplyResult(
        success: false,
        errorMessage: 'Template not found',
      );
    }

    var items = bundle.items;
    if (resolutions.isEmpty) {
      final issues = await analyzeMealTemplateDependencies(items);
      if (issues.isNotEmpty) {
        return MealTemplateApplyResult(success: false, issues: issues);
      }
    } else {
      items = _mealTemplateApplyService.resolveItems(
        originalItems: items,
        resolutions: resolutions,
      );
      if (items.isEmpty) {
        return const MealTemplateApplyResult(success: false, cancelled: true);
      }
    }

    final mealGroupId = generateId();
    final loggedAt = DateTime.now();
    final entries = _mealTemplateApplyService.buildEntries(
      items: items,
      mealGroupId: mealGroupId,
      mealGroupName: bundle.template.name,
      loggedAt: loggedAt,
      generateEntryId: generateId,
    );

    try {
      await addFoodEntriesBatch(entries);

      final now = DateTime.now();
      await repository.update(
        bundle.template.copyWith(
          useCount: bundle.template.useCount + 1,
          lastUsedAt: now,
          updatedAt: now,
        ),
      );
      _scheduleRemoteSync();

      return MealTemplateApplyResult(
        success: true,
        createdEntryCount: entries.length,
      );
    } catch (error) {
      return MealTemplateApplyResult(
        success: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<SavedFood> copyPublicFoodForTemplateItem(SavedFood source) =>
      copyPublicFoodToPrivate(source);

  SavedFoodEntrySelection selectSavedFoodForEntry(SavedFood food) {
    return SavedFoodEntrySelection.fromSavedFood(food);
  }

  String formatSavedFoodBaseLabel(SavedFood food) {
    return _savedFoodEntryBuilder.formatBaseLabel(food);
  }

  String formatBaseAmountLabel({
    required double baseAmount,
    required FoodUnitType unitType,
  }) {
    return _savedFoodEntryBuilder.formatBaseAmountLabel(
      baseAmount: baseAmount,
      unitType: unitType,
    );
  }

  Future<SaveFoodEntryResult> saveFoodEntryWithOptionalSavedFood({
    required FoodEntry entry,
    required bool saveAsFood,
    SavedFoodDraft? savedFoodDraft,
    DuplicateSavedFoodResolution? duplicateResolution,
  }) async {
    var entryToSave = entry;

    if (duplicateResolution?.action == DuplicateSavedFoodAction.useExisting) {
      final existing = duplicateResolution!.existingFood;
      if (existing != null) {
        entryToSave = entry.copyWith(
          savedFoodId: existing.foodId,
          sourceFoodOwnerUserId: existing.ownerUserId,
        );
      }
    }

    try {
      final isUpdate = foodEntries.any((item) => item.id == entryToSave.id);
      if (isUpdate) {
        await updateFood(entryToSave);
      } else {
        await addFood(entryToSave);
      }
    } catch (error) {
      return SaveFoodEntryResult(
        foodEntrySaved: false,
        savedFoodErrorMessage: error.toString(),
      );
    }

    if (entryToSave.savedFoodId != null) {
      await _recordSavedFoodUsage(entryToSave.savedFoodId!);
    }

    if (!saveAsFood) {
      return SaveFoodEntryResult(foodEntrySaved: true, entry: entryToSave);
    }

    try {
      SavedFood? savedFood;
      if (duplicateResolution != null) {
        savedFood = await _resolveSavedFoodFromDuplicateAction(
          duplicateResolution,
        );
      } else if (savedFoodDraft != null) {
        savedFood = await createSavedFood(savedFoodDraft);
      }

      if (savedFood != null && entryToSave.savedFoodId == null) {
        entryToSave = entryToSave.copyWith(
          savedFoodId: savedFood.foodId,
          sourceFoodOwnerUserId: savedFood.ownerUserId,
        );
        await updateFood(entryToSave);
        await _recordSavedFoodUsage(savedFood.foodId);
      }

      return SaveFoodEntryResult(
        foodEntrySaved: true,
        entry: entryToSave,
        savedFood: savedFood,
        savedFoodSaved: savedFood != null,
      );
    } catch (error) {
      return SaveFoodEntryResult(
        foodEntrySaved: true,
        entry: entryToSave,
        savedFoodSaved: false,
        savedFoodErrorMessage: error.toString(),
      );
    }
  }

  Future<SavedFood?> _resolveSavedFoodFromDuplicateAction(
    DuplicateSavedFoodResolution resolution,
  ) async {
    return switch (resolution.action) {
      DuplicateSavedFoodAction.skipSavedFood => null,
      DuplicateSavedFoodAction.useExisting => null,
      DuplicateSavedFoodAction.updateExisting => updateSavedFood(
        resolution.existingFood!.copyWith(
          name: resolution.draft.name,
          baseAmount: resolution.draft.baseAmount,
          unitType: resolution.draft.unitType,
          kcalPerBase: resolution.draft.kcalPerBase,
          proteinPerBase: resolution.draft.proteinPerBase,
          fatPerBase: resolution.draft.fatPerBase,
          carbPerBase: resolution.draft.carbPerBase,
          brand: resolution.draft.brand,
          barcode: resolution.draft.barcode,
          supplementaryWeight: resolution.draft.supplementaryWeight,
        ),
      ),
      DuplicateSavedFoodAction.saveAsNewName => createSavedFood(
        SavedFoodDraft(
          name: resolution.newName ?? resolution.draft.name,
          baseAmount: resolution.draft.baseAmount,
          unitType: resolution.draft.unitType,
          kcalPerBase: resolution.draft.kcalPerBase,
          proteinPerBase: resolution.draft.proteinPerBase,
          fatPerBase: resolution.draft.fatPerBase,
          carbPerBase: resolution.draft.carbPerBase,
          brand: resolution.draft.brand,
          barcode: resolution.draft.barcode,
          supplementaryWeight: resolution.draft.supplementaryWeight,
          sourceType: resolution.draft.sourceType,
        ),
      ),
    };
  }

  Future<void> _recordSavedFoodUsage(String savedFoodId) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return;
    }

    final food = await repository.getOwn(
      ownerUserId: currentOwnerUserId,
      foodId: savedFoodId,
    );
    if (food == null || food.status != FoodStatus.active) {
      return;
    }

    final now = DateTime.now();
    await repository.updateOwn(
      food.copyWith(
        useCount: food.useCount + 1,
        lastUsedAt: now,
        updatedAt: now,
      ),
    );
    _scheduleRemoteSync();
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

  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

enum WeightDataSource { manual, health, healthPending }
