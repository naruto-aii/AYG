import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:uuid/uuid.dart';

import '../config/subscription_catalog.dart';
import '../constants/app_strings.dart';
import '../services/ai_data_consent.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/catalog_actions.dart';
import '../repositories/storekit_subscription_repository.dart';
import '../models/alcohol_entry.dart';
import '../models/app_settings.dart';
import '../models/activity_level.dart';
import '../models/daily_summary.dart';
import '../models/duplicate_saved_food_action.dart';
import '../models/duplicate_saved_food_resolution.dart';
import '../data/met_activity_catalog.dart';
import '../models/exercise_calculation_source.dart';
import '../models/exercise_category.dart';
import '../models/exercise_entry.dart';
import '../models/food_form_suggestion.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
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
import '../models/saved_food_persistence_error.dart';
import '../models/sync_failure.dart';
import '../models/saved_food_entry_selection.dart';
import '../models/food_report.dart';
import '../models/public_food_publish_match.dart';
import '../models/public_food_rating_view.dart';
import '../models/public_food_search_match.dart';
import '../models/saved_food_publish_validation.dart';
import '../models/save_food_entry_result.dart';
import '../models/user_profile.dart';
import '../models/calculation/calorie_target_mode.dart';
import '../models/calculation/goal_pace.dart';
import '../models/calculation/landing_guidance.dart';
import '../models/calculation/weight_sample.dart';
import '../models/weight_entry.dart';
import '../services/weight_for_target.dart';
import '../utils/local_date.dart';
import '../models/workout_template.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/exceptions/food_master_exceptions.dart';
import '../repositories/contracts/blocked_food_creator_repository_base.dart';
import '../repositories/contracts/food_rating_repository_base.dart';
import '../repositories/contracts/food_report_repository_base.dart';
import '../repositories/contracts/saved_food_repository_base.dart';
import '../repositories/contracts/alcohol_repository_base.dart';
import '../repositories/contracts/exercise_repository_base.dart';
import '../repositories/contracts/food_repository_base.dart';
import '../repositories/contracts/meal_template_repository_base.dart';
import '../repositories/contracts/settings_repository_base.dart';
import '../repositories/contracts/user_repository_base.dart';
import '../repositories/contracts/workout_template_repository_base.dart';
import '../repositories/contracts/weight_repository_base.dart';
import '../repositories/data_sync_repository.dart';
import '../repositories/pending_record_store.dart';
import '../repositories/first_meal_guide_store.dart';
import '../repositories/sync_step_runner.dart';
import '../repositories/health_repository.dart';
import '../repositories/health_repository_support.dart';
import '../repositories/local_session_store.dart';
import '../services/local_user_data_clearer_base.dart';
import '../config/official_foods_flag.dart';
import '../config/supabase_config.dart';
import '../repositories/subscription_exceptions.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/unavailable_subscription_repository.dart';
import '../repositories/coach_proposal_log.dart';
import '../repositories/plus_funnel_repository.dart';
import '../repositories/usage_record_repository.dart';
import '../services/usage_record.dart';
import '../repositories/review_prompt_store.dart';
import '../services/lock_screen_meal.dart';
import '../services/review_prompt.dart';
import '../services/lock_screen_meal_gateway.dart';
import '../services/siri_voice_gateway.dart';
import '../services/siri_voice_log.dart';
import '../services/meal_template_apply_service.dart';
import '../services/meal_template_dependency_service.dart';
import '../services/meal_template_totals_service.dart';
import '../services/nutrition_engine.dart';
import '../services/plus_gate_retry.dart';
import '../services/official_food_provenance.dart';
import '../services/public_food_search_service.dart';
import '../services/public_food_similar_service.dart';
import '../services/publish_error_messages.dart';
import '../services/saved_food_duplicate_service.dart';
import '../services/saved_food_entry_builder.dart';
import '../services/saved_food_publish_validator.dart';
import '../services/saved_food_search_service.dart';
import '../services/saved_food_version_policy.dart';
import '../services/search_suggestion_service.dart';
import '../services/source_food_edit_policy.dart';
import '../utils/food_name_normalizer.dart';
import '../utils/food_search_normalizer.dart';
import '../utils/id_generator.dart';
import '../utils/user_error_message.dart';

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
    AlcoholRepositoryBase? alcoholRepository,
    WeightRepositoryBase? weightRepository,
    SavedFoodRepositoryBase? savedFoodRepository,
    FoodRatingRepositoryBase? foodRatingRepository,
    FoodReportRepositoryBase? foodReportRepository,
    BlockedFoodCreatorRepositoryBase? blockedCreatorRepository,
    MealTemplateRepositoryBase? mealTemplateRepository,
    WorkoutTemplateRepositoryBase? workoutTemplateRepository,
    FirstMealGuideStore? firstMealGuideStore,
    LockScreenMealGateway? lockScreenMealGateway,
    SiriVoiceGateway? siriVoiceGateway,
    SubscriptionRepository? subscriptionRepository,
    UsageRecordRepository? usageRecordRepository,
    CoachProposalLog? coachProposalLog,
    PlusFunnelRepository? plusFunnelRepository,
    ReviewPromptStore? reviewPromptStore,
    PendingRecordStore? pendingRecords,
    Future<bool> Function()? termsAgreed,
  }) : _termsAgreed = termsAgreed ?? AiDataConsent.grantedNow,
       _nutritionEngine = nutritionEngine ?? NutritionEngine(),
       _healthRepository = healthRepository,
       _authenticationRepository = authenticationRepository,
       _dataSyncRepository = dataSyncRepository,
       _localSessionStore = localSessionStore,
       _localUserDataClearer = localUserDataClearer,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _alcoholRepository = alcoholRepository,
       _weightRepository = weightRepository,
       _savedFoodRepository = savedFoodRepository,
       _foodRatingRepository = foodRatingRepository,
       _foodReportRepository = foodReportRepository,
       _blockedCreatorRepository = blockedCreatorRepository,
       _mealTemplateRepository = mealTemplateRepository,
       _workoutTemplateRepository = workoutTemplateRepository,
       _firstMealGuideStore = firstMealGuideStore,
       _lockScreenMealGateway = lockScreenMealGateway,
       _siriVoiceGateway = siriVoiceGateway,
       _subscriptionRepository =
           subscriptionRepository ?? UnavailableSubscriptionRepository(),
       _usageRecordRepository = usageRecordRepository,
       _coachProposalLog = coachProposalLog ?? const NoOpCoachProposalLog(),
       _plusFunnelRepository = plusFunnelRepository,
       _reviewPromptStore = reviewPromptStore ?? const NoOpReviewPromptStore(),
       _pendingRecords = pendingRecords ?? PendingRecordStore(),
       _savedFoodSearchService = const SavedFoodSearchService(),
       _savedFoodDuplicateService = const SavedFoodDuplicateService(),
       _savedFoodEntryBuilder = const SavedFoodEntryBuilder(),
       _savedFoodPublishValidator = const SavedFoodPublishValidator(),
       _publicFoodSimilarService = const PublicFoodSimilarService(),
       _publicFoodSearchService = const PublicFoodSearchService(),
       _mealTemplateTotalsService = const MealTemplateTotalsService(),
       _mealTemplateDependencyService = const MealTemplateDependencyService(),
       _mealTemplateApplyService = const MealTemplateApplyService(),
       _searchSuggestionService = const SearchSuggestionService() {
    PlusGateRetry.bind(_syncPlusForAiRetry);
  }

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
  final AlcoholRepositoryBase? _alcoholRepository;
  final WeightRepositoryBase? _weightRepository;
  final SavedFoodRepositoryBase? _savedFoodRepository;
  final FoodRatingRepositoryBase? _foodRatingRepository;
  final FoodReportRepositoryBase? _foodReportRepository;
  final BlockedFoodCreatorRepositoryBase? _blockedCreatorRepository;
  final MealTemplateRepositoryBase? _mealTemplateRepository;
  final WorkoutTemplateRepositoryBase? _workoutTemplateRepository;
  final FirstMealGuideStore? _firstMealGuideStore;
  final LockScreenMealGateway? _lockScreenMealGateway;
  final SiriVoiceGateway? _siriVoiceGateway;
  final SubscriptionRepository _subscriptionRepository;
  final UsageRecordRepository? _usageRecordRepository;
  final CoachProposalLog _coachProposalLog;
  final PlusFunnelRepository? _plusFunnelRepository;
  final ReviewPromptStore _reviewPromptStore;
  final PendingRecordStore _pendingRecords;

  PendingRecordStore get pendingRecords => _pendingRecords;

  CoachProposalLog get coachProposalLog => _coachProposalLog;

  PlusFunnelRepository? get plusFunnelRepository => _plusFunnelRepository;

  ReviewPromptStore get reviewPromptStore => _reviewPromptStore;

  /// 依頼を出してよい状態になった回数。画面はこれでダイアログを開く。
  final ValueNotifier<int> reviewPromptTick = ValueNotifier(0);
  StreamSubscription<bool>? _plusSubscription;
  StreamSubscription<void>? _entitlementSyncSubscription;

  SubscriptionRepository get subscriptionRepository => _subscriptionRepository;
  bool _firstMealGuideSeen = false;
  bool _offerFirstMealGuide = false;
  DateTime? _onboardingOpenedAt;
  String? _currentTab;
  String? _linkedFoodSearchId;
  final Map<String, String> _foodSearchIds = {};
  final Map<String, int> _foodSearchCounts = {};
  final Map<String, DateTime> _foodSearchStarted = {};
  final Map<String, int> _exerciseSearchCounts = {};
  final Map<String, DateTime> _exerciseSearchStarted = {};

  String? get linkedFoodSearchId => _linkedFoodSearchId;

  /// 初回設定の最初の画面を開いた時刻。完了までの時間に使う。
  void noteOnboardingOpened() {
    _onboardingOpenedAt ??= DateTime.now();
  }

  /// 選んだ検索の id を、次の食事記録に付ける。
  void pinFoodSearch(String source) {
    final id = _foodSearchIds[source];
    if (id != null) {
      _linkedFoodSearchId = id;
    }
  }

  void noteFoodSearchResults({required String source, required int count}) {
    _foodSearchCounts[source] = count;
  }

  void noteExerciseSearchResults({required String source, required int count}) {
    _exerciseSearchCounts[source] = count;
  }

  /// 目標設定を終えた直後だけ true。一度案内を出したら false のまま。
  bool get shouldOfferFirstMealGuide =>
      _offerFirstMealGuide && !_firstMealGuideSeen;
  final SavedFoodSearchService _savedFoodSearchService;
  final SavedFoodDuplicateService _savedFoodDuplicateService;
  final SavedFoodEntryBuilder _savedFoodEntryBuilder;
  final SavedFoodPublishValidator _savedFoodPublishValidator;
  final PublicFoodSimilarService _publicFoodSimilarService;
  final PublicFoodSearchService _publicFoodSearchService;
  final MealTemplateTotalsService _mealTemplateTotalsService;
  final MealTemplateDependencyService _mealTemplateDependencyService;
  final MealTemplateApplyService _mealTemplateApplyService;
  final SearchSuggestionService _searchSuggestionService;

  bool _publishOperationInProgress = false;
  final Set<String> _ratingOperationsInProgress = {};

  bool get isPublishOperationInProgress => _publishOperationInProgress;

  /// 未ログイン時のローカル専用 owner ID。
  static const localOwnerUserId = 'local-user';

  StreamSubscription<AuthUser?>? _authSubscription;
  bool _hasInitialSyncCompleted = false;
  bool _isSyncInProgress = false;

  /// この端末で、今の版の規約・プライバシー（AI送信の一文を含む）に
  /// ログイン画面で同意したか。
  final Future<bool> Function() _termsAgreed;
  bool _termsAgreementRequired = false;
  int _termsCheck = 0;

  /// ログイン済みでも、ログイン画面（同意画面）をもう一度出す必要があるか。
  /// 再インストールや規約の版上げで端末に同意が無いとき true。
  bool get requiresTermsAgreement => _termsAgreementRequired;
  bool _lastSyncFailed = false;
  bool _hasUnsentRecords = false;
  bool _isInitializing = false;
  SyncFailure? _syncFailure;

  bool get hasInitialSyncCompleted => _hasInitialSyncCompleted;
  bool get isSyncInProgress => _isSyncInProgress;
  bool get lastSyncFailed => _lastSyncFailed;

  /// 手元にあるのに、まだ本番へ届いていない記録がある。
  bool get hasUnsentRecords => _hasUnsentRecords;
  bool get isInitializing => _isInitializing;
  SyncFailure? get syncFailure => _syncFailure;

  /// 初回同期失敗などでプロフィール未取得のままオンボーディングへ進まない。
  bool get requiresSyncRetry =>
      isAuthenticated && _lastSyncFailed && !_hasInitialSyncCompleted;

  bool get requiresOnboarding =>
      isAuthenticated &&
      _hasInitialSyncCompleted &&
      !_lastSyncFailed &&
      !onboardingComplete;

  UserProfile? profile;
  Goal? goal;
  NutritionSettings? nutritionSettings;
  HealthProfileData healthPrefill = HealthProfileData.empty;
  HealthSnapshot healthSnapshot = HealthSnapshot.empty;
  AppSettings appSettings = const AppSettings();
  DailySummary? summary;
  final List<FoodEntry> foodEntries = [];
  final List<ExerciseEntry> exerciseEntries = [];
  final List<AlcoholEntry> alcoholEntries = [];
  final List<WeightEntry> weightEntries = [];

  bool get isAuthenticated =>
      _authenticationRepository?.isAuthenticated ?? false;

  String get currentOwnerUserId =>
      _authenticationRepository?.currentUser?.id ?? localOwnerUserId;

  bool get useHealthIntegration =>
      nutritionSettings?.useHealthIntegration ?? false;

  bool get onboardingComplete => appSettings.onboardingComplete;

  bool get isHealthRepositoryAvailable =>
      _healthRepository?.isAvailable ?? false;

  /// 計算に使用している体重。測定時刻が新しい方。
  WeightSelection get currentWeightSelection => selectWeight(
    samples: calculationWeightSamples(),
    reference: DateTime.now(),
    fallbackKg: profile?.weightKg,
  );

  /// 計算に使用している体重のデータソース。
  WeightDataSource get weightDataSource {
    final source = currentWeightSelection.source;
    if (source == WeightSource.health) {
      return WeightDataSource.health;
    }
    if (useHealthIntegration &&
        healthSnapshot.weightKg == null &&
        healthPrefill.weightKg == null &&
        !weightEntries.any((entry) => entry.source == WeightSource.health)) {
      return WeightDataSource.healthPending;
    }
    return WeightDataSource.manual;
  }

  String get weightDataSourceLabel {
    final selection = currentWeightSelection;
    final lines = <String>[selection.usageLabel];
    final healthNote = selection.healthUpdateStoppedNote;
    if (healthNote != null) {
      lines.add(healthNote);
    }
    final staleNote = selection.staleRecordPrompt;
    if (staleNote != null) {
      lines.add(staleNote);
    }
    return lines.join('\n');
  }

  List<WeightSample> calculationWeightSamples() {
    final measuredAt = healthSnapshot.weightMeasuredAt;
    final ignoreHealthAfter = measuredAt?.add(const Duration(minutes: 1));
    final samples = <WeightSample>[];
    for (final entry in weightEntries) {
      if (entry.source == WeightSource.health &&
          ignoreHealthAfter != null &&
          entry.recordedAt.isAfter(ignoreHealthAfter)) {
        continue;
      }
      samples.add(
        WeightSample(
          kg: entry.weightKg,
          measuredAt: entry.recordedAt,
          source: entry.source,
        ),
      );
    }
    final snapshotKg = healthSnapshot.weightKg;
    if (snapshotKg != null && measuredAt != null) {
      final already = samples.any(
        (sample) =>
            sample.source == WeightSource.health &&
            sample.measuredAt.isAtSameMomentAs(measuredAt) &&
            (sample.kg - snapshotKg).abs() < 0.001,
      );
      if (!already) {
        samples.add(
          WeightSample(
            kg: snapshotKg,
            measuredAt: measuredAt,
            source: WeightSource.health,
          ),
        );
      }
    }
    return samples;
  }

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    _listenForPaidEntitlement();
    await _applyPaidEntitlement();
    _firstMealGuideSeen = await _firstMealGuideStore?.isSeen() ?? false;

    final authRepository = _authenticationRepository;
    if (authRepository == null) {
      await loadPersistedState();
      _isInitializing = false;
      notifyListeners();
      return;
    }

    try {
      await authRepository.restoreSession();
    } catch (_) {
      // セッション復元失敗時は未ログインとして続行する。
    }

    _authSubscription ??= authRepository.authStateChanges.listen((user) {
      unawaited(_handleAuthStateChanged(user));
    });

    if (authRepository.isAuthenticated) {
      await handleAuthenticatedSession();
    } else {
      _clearInMemoryState();
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _handleAuthStateChanged(AuthUser? user) async {
    if (user == null) {
      _resetSyncState();
      _clearInMemoryState();
      notifyListeners();
      return;
    }

    if (!_isSyncInProgress) {
      await handleAuthenticatedSession();
    }
    notifyListeners();
  }

  Future<void> retryAuthenticatedSync() async {
    if (_isSyncInProgress) {
      return;
    }
    await handleAuthenticatedSession(force: true);
  }

  Future<void> handleAuthenticatedSession({bool force = false}) async {
    final authUser = _authenticationRepository?.currentUser;
    if (authUser != null) {
      // 同意はログイン画面のボタンでだけ記録する。保存済みのログイン状態が
      // 戻っただけなら、同意の画面をもう一度出し、同期も AI も始めない。
      final check = ++_termsCheck;
      final agreed = await _termsAgreed();
      if (check != _termsCheck) {
        return;
      }
      if (!agreed) {
        if (!_termsAgreementRequired) {
          _termsAgreementRequired = true;
          notifyListeners();
        }
        return;
      }
      if (_termsAgreementRequired) {
        _termsAgreementRequired = false;
        notifyListeners();
      }
    }
    final dataSyncRepository = _dataSyncRepository;
    if (authUser == null || dataSyncRepository == null) {
      return;
    }
    final userId = authUser.id.toLowerCase();
    await Analytics.service?.setCurrentUser(userId);
    _subscriptionRepository.bindStoreAccountToken(userId);

    if (_isSyncInProgress) {
      return;
    }

    _isSyncInProgress = true;
    _lastSyncFailed = false;
    _syncFailure = null;
    notifyListeners();

    try {
      final lastUserId = await _localSessionStore?.loadLastUserId();
      final switching =
          lastUserId != null &&
          lastUserId.toLowerCase() != authUser.id.toLowerCase();
      if (switching) {
        final delivered = await _pushBeforeWipe(dataSyncRepository, lastUserId);
        if (!delivered) {
          _blockSession(
            '前のアカウントの未送信の記録を送れなかったため、アカウントの切り替えを中止しました。通信できるときに再度開いてください。',
          );
          return;
        }
        final pendingCount = await _pendingRecords.count();
        _usage('local_data_cleared', {
          'reason': 'user_switch',
          'pending_records_count': pendingCount,
        });
        await _pendingRecords.clear();
        await _localUserDataClearer?.clearAll();
      }

      await dataSyncRepository.ensureUserProfile(
        userId: authUser.id,
        email: authUser.email,
      );

      if (force || switching || !_hasInitialSyncCompleted) {
        await _migrateLocalOwnerData(toUserId: authUser.id);
        final failed = await _pushUnsentBeforePull(
          dataSyncRepository,
          authUser.id,
        );
        await dataSyncRepository.pullRemoteToLocal(
          authUser.id,
          skipTables: failed,
        );
        _hasInitialSyncCompleted = true;
        await _localSessionStore?.saveLastUserId(authUser.id);
      }

      await runSyncStep(
        step: SyncStep.applyRemoteData,
        repository: 'AppController',
        tableName: 'local_cache',
        operation: 'load',
        action: () => loadPersistedState(),
      );
      await syncLockScreenMeals();
      await syncSiriVoiceLogs();
      await _syncPlusEntitlement();
      await _adoptServerPlusForTestBuild(authUser.id);
      _lastSyncFailed = false;
      _syncFailure = null;
    } on SyncStepException catch (error) {
      _lastSyncFailed = true;
      _hasInitialSyncCompleted = false;
      _syncFailure = error.failure;
      _hasUnsentRecords = true;
      _clearInMemoryState();
    } catch (error, stackTrace) {
      _lastSyncFailed = true;
      _hasInitialSyncCompleted = false;
      _syncFailure = SyncFailure.from(
        step: SyncStep.applyRemoteData,
        error: error,
        repository: 'AppController',
        tableName: 'local_cache',
        operation: 'sync',
      )..logDebug();
      _hasUnsentRecords = true;
      _clearInMemoryState();
      if (kDebugMode) {
        debugPrint('[AYG] handleAuthenticatedSession failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _isSyncInProgress = false;
      await _flushBehaviorQueues();
      notifyListeners();
    }
  }

  /// 未送信を送れたとき true。送れないときは消さずに false。
  Future<bool> logout({bool force = false}) async {
    _usage('logout', {'forced': force});
    if (_isSyncInProgress && !force) {
      sessionBlockMessage = '同期中です。しばらくしてから再度ログアウトしてください。';
      notifyListeners();
      return false;
    }
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (!force && userId != null && dataSyncRepository != null) {
      final delivered = await _pushBeforeWipe(dataSyncRepository, userId);
      if (!delivered) {
        _blockSession('未送信の記録を送れなかったため、ログアウトを中止しました。通信できるときに再度お試しください。');
        return false;
      }
    }
    await Analytics.service?.flush();
    await _usageRecordRepository?.flushPending();
    await _plusFunnelRepository?.flushPending();
    await _coachProposalLog.flushPending();
    _resetSyncState();
    _clearInMemoryState();
    final pendingCount = await _pendingRecords.count();
    _usage('local_data_cleared', {
      'reason': 'logout',
      'pending_records_count': pendingCount,
    });
    await _pendingRecords.clear();
    await _localUserDataClearer?.clearAll();
    await _localSessionStore?.clearLastUserId();
    await _authenticationRepository?.logout();
    await Analytics.service?.setCurrentUser(null);
    sessionBlockMessage = null;
    notifyListeners();
    return true;
  }

  String? sessionBlockMessage;

  void _blockSession(String message) {
    sessionBlockMessage = message;
    _lastSyncFailed = true;
    _hasUnsentRecords = true;
    _syncFailure = SyncFailure(
      step: SyncStep.applyRemoteData,
      errorCode: 'UNSENT_PUSH_FAILED',
      message: message,
      userMessage: message,
      repository: 'AppController',
      tableName: 'local_cache',
      operation: 'push',
    );
    notifyListeners();
  }

  /// 消す前に未送信を送る。一部でも失敗したら false。手元は残す。
  Future<bool> _pushBeforeWipe(
    DataSyncRepository dataSyncRepository,
    String userId,
  ) async {
    try {
      await dataSyncRepository.pushLocalToRemote(userId);
      return true;
    } on PartialPushException catch (error, stackTrace) {
      debugPrint('[AYG] push before wipe incomplete: $error');
      debugPrintStack(stackTrace: stackTrace);
      for (final failure in error.failures) {
        await _pendingRecords.markTableDirty(failure.table);
      }
      return false;
    } catch (error, stackTrace) {
      debugPrint('[AYG] push before wipe failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  void _resetSyncState() {
    _termsAgreementRequired = false;
    _termsCheck += 1;
    _hasInitialSyncCompleted = false;
    _lastSyncFailed = false;
    _hasUnsentRecords = false;
    _isSyncInProgress = false;
    _syncFailure = null;
  }

  /// 取得で手元の未送信行を消さないよう、先に送る。失敗した表は取得しない。
  Future<Set<String>> _pushUnsentBeforePull(
    DataSyncRepository dataSyncRepository,
    String userId,
  ) async {
    try {
      await dataSyncRepository.pushLocalToRemote(userId);
      _hasUnsentRecords = await _pendingRecords.count() > 0;
      return const {};
    } on PartialPushException catch (error, stackTrace) {
      _hasUnsentRecords = true;
      debugPrint('[AYG] push before pull incomplete: $error');
      debugPrintStack(stackTrace: stackTrace);
      final tables = <String>{};
      for (final failure in error.failures) {
        tables.add(failure.table);
        await _pendingRecords.markTableDirty(failure.table);
      }
      return tables;
    }
  }

  /// 起動のあと、前面に戻ったときに未送信を再送する。
  Future<void> flushUnsentRecords() async {
    await _flushBehaviorQueues();
    if (_isSyncInProgress) {
      return;
    }
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (userId == null || dataSyncRepository == null) {
      return;
    }
    if (!_hasInitialSyncCompleted || _lastSyncFailed) {
      await handleAuthenticatedSession(force: true);
      return;
    }
    if (!_hasUnsentRecords) {
      return;
    }
    if (_remoteSyncInFlight) {
      _remoteSyncQueued = true;
      return;
    }
    _remoteSyncInFlight = true;
    await _drainRemoteSync(dataSyncRepository, userId);
  }

  Future<void> _flushBehaviorQueues() async {
    await _usageRecordRepository?.flushPending();
    await _plusFunnelRepository?.flushPending();
    await _coachProposalLog.flushPending();
  }

  void recordPlusFunnel({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) {
    _emitFunnel(event, feature: feature, productId: productId);
    final repository = _plusFunnelRepository;
    if (repository == null) {
      return;
    }
    unawaited(() async {
      try {
        await repository.record(
          event: event,
          feature: feature,
          productId: productId,
        );
      } catch (error, stackTrace) {
        debugPrint('[AYG] plus funnel record failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }());
  }

  void _usage(
    String name, [
    Map<String, Object?> props = const {},
    String? origin,
  ]) {
    Analytics.emit(name, props, origin);
  }

  void _emitFunnel(
    PlusFunnelEvent event, {
    PlusFunnelFeature? feature,
    String? productId,
  }) {
    final featureName = switch (feature) {
      PlusFunnelFeature.memo => 'food_memo',
      null => 'other',
      _ => feature.storageValue,
    };
    switch (event) {
      case PlusFunnelEvent.paywallOpen:
        Analytics.emit('paywall_open', {
          'entry_point': feature == null ? 'other' : 'gate_$featureName',
        });
      case PlusFunnelEvent.planSelect:
        Analytics.emit('plan_select', {
          'product_id': SubscriptionCatalog.planKeyForProduct(productId),
        });
      case PlusFunnelEvent.purchaseTap:
        Analytics.emit('purchase_tap', {
          'product_id': SubscriptionCatalog.planKeyForProduct(productId),
        });
      case PlusFunnelEvent.purchaseSuccess:
      case PlusFunnelEvent.purchaseCancel:
      case PlusFunnelEvent.purchaseFailed:
        break;
      case PlusFunnelEvent.restoreTap:
        Analytics.emit('restore_tap', {
          'product_id': SubscriptionCatalog.planKeyForProduct(productId),
        });
      case PlusFunnelEvent.gateShown:
        Analytics.emit('gate_shown', {'feature': featureName});
      case PlusFunnelEvent.gateTap:
        Analytics.emit('gate_tap', {
          'feature': featureName,
          'choice': 'view_plus',
        });
    }
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
    alcoholEntries.clear();
    weightEntries.clear();
  }

  Future<void> loadPersistedState() async {
    final userRepository = _userRepository;
    final settingsRepository = _settingsRepository;
    final foodRepository = _foodRepository;
    final exerciseRepository = _exerciseRepository;
    final alcoholRepository = _alcoholRepository;
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

    if (alcoholRepository != null) {
      alcoholEntries
        ..clear()
        ..addAll(await alcoholRepository.loadAll());
    }

    await _reloadWeightEntries();

    refreshDailySummary();
  }

  Future<void> completeOnboarding() async {
    final opened = _onboardingOpenedAt ??= DateTime.now();
    final durationMs = DateTime.now().difference(opened).inMilliseconds;
    final elapsed = durationMs < 0 ? 0 : durationMs;
    CatalogActions.onboardingStepComplete(
      step: 'goal',
      durationMs: elapsed,
      skipped: false,
    );
    _usage('onboarding_complete', {
      'goal_type': goal?.type.name ?? 'maintain',
      'health_enabled': useHealthIntegration,
      'duration_ms': elapsed,
    });
    appSettings = appSettings.copyWith(onboardingComplete: true);
    await _settingsRepository?.saveAppSettings(appSettings);
    await _persistToRemoteNow();
    offerFirstMealGuide();
    notifyListeners();
  }

  /// 目標設定を終えたこのセッションだけ、食事1件の案内を出す。
  void offerFirstMealGuide() {
    _usage('first_meal_guide_shown');
    if (_firstMealGuideSeen) {
      return;
    }
    _offerFirstMealGuide = true;
  }

  /// 案内を出した時点で終わりにする。食事を保存しても、途中で閉じても再表示しない。
  void finishFirstMealGuide() {
    if (_firstMealGuideSeen && !_offerFirstMealGuide) {
      return;
    }
    _firstMealGuideSeen = true;
    _offerFirstMealGuide = false;
    final store = _firstMealGuideStore;
    if (store != null) {
      unawaited(store.markSeen());
    }
    recordScreenAction(
      screen: UsageScreen.firstMealGuide,
      action: UsageScreenAction.open,
    );
    _usage('first_meal_guide_finished', {'action': 'started'});
  }

  void setProfile(UserProfile value) {
    CatalogActions.settingsChanged(settingKey: 'profile', newValue: 'saved');
    profile = value;
    _userRepository?.saveProfile(profile!);
    _rememberManualWeight(value.weightKg);
    _scheduleRemoteSync();
    refreshDailySummary();
    unawaited(publishSiriVoiceCatalog());
    unawaited(_fillWidgetExercisesWaitingForWeight());
  }

  Future<void> applyHealthProfileData(HealthProfileData data) async {
    _usage('profile_updated', {'changed_fields': 'health', 'source': 'health'});
    healthPrefill = data;
    healthSnapshot = HealthSnapshot(
      activeEnergyBurnedKcal: data.activeEnergyBurnedKcal,
      weightKg: data.weightKg,
      weightMeasuredAt: data.weightKg == null ? null : data.weightMeasuredAt,
    );
    await _settingsRepository?.saveHealthSnapshot(healthSnapshot);
    unawaited(_fillWidgetExercisesWaitingForWeight());

    if (_healthRepository != null) {
      await HealthRepositorySupport.persistFetchedProfile(
        _healthRepository,
        data,
      );
    }
    await _reloadWeightEntries();

    final currentProfile = profile;
    if (currentProfile != null) {
      profile = currentProfile.copyWith(
        weightKg: currentWeightSelection.kg > 0
            ? currentWeightSelection.kg
            : currentProfile.weightKg,
      );
      await _userRepository?.saveProfile(profile!);
    }

    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> recordManualWeight(
    double weightKg, {
    DateTime? recordedAt,
  }) async {
    final entry = WeightEntry(
      id: generateId(),
      weightKg: weightKg,
      recordedAt: recordedAt ?? DateTime.now(),
      source: WeightSource.manual,
    );
    await _pendingRecords.markUpsert(PendingRecordKind.weight, entry.id);
    _usage('weight_entry_added', {
      'weight_entry_id': entry.id,
      'source': 'manual',
    });
    final weightRepository = _weightRepository;
    await weightRepository?.save(entry);
    if (weightRepository != null) {
      _placeWeightEntry(entry);
    }
    await _refreshProfileWeightFromEntries();
  }

  Future<void> updateWeightEntry(WeightEntry entry) async {
    _usage('weight_entry_updated', {
      'weight_entry_id': entry.id,
      'action': 'update',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.weight, entry.id);
    final weightRepository = _weightRepository;
    await weightRepository?.save(entry);
    if (weightRepository != null) {
      _placeWeightEntry(entry);
    }
    await _refreshProfileWeightFromEntries();
  }

  Future<void> restoreWeightEntry(WeightEntry entry) async {
    _usage('weight_entry_updated', {
      'weight_entry_id': entry.id,
      'action': 'restore',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.weight, entry.id);
    final weightRepository = _weightRepository;
    await weightRepository?.save(entry);
    if (weightRepository != null) {
      _placeWeightEntry(entry);
    }
    await _refreshProfileWeightFromEntriesWithoutScheduledSync();
    await _persistToRemoteNow();
  }

  Future<void> _refreshProfileWeightFromEntriesWithoutScheduledSync() async {
    final currentProfile = profile;
    if (currentProfile == null) {
      refreshDailySummary();
      return;
    }

    profile = currentProfile.copyWith(
      weightKg: currentWeightSelection.kg > 0
          ? currentWeightSelection.kg
          : currentProfile.weightKg,
    );
    await _userRepository?.saveProfile(profile!);
    refreshDailySummary();
  }

  /// 送信中の同期が終わってから消す。送信中に消すと、その送信が消した行を
  /// サーバへ書き戻し、次の再インストールで記録が復活する。
  Future<void> deleteWeightEntry(String entryId) =>
      _serialRemoteWrite(() => _deleteWeightEntryNow(entryId));

  Future<void> _deleteWeightEntryNow(String entryId) async {
    _usage('weight_entry_updated', {
      'weight_entry_id': entryId,
      'action': 'delete',
    });
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    final weightRepository = _weightRepository;
    final confirmed = await _confirmRemoteDelete(
      kind: PendingRecordKind.weight,
      id: entryId,
      enabled: dataSyncRepository?.supportsRemoteWeightEntryDelete ?? false,
      missingUser: 'Authentication required to delete weight entry.',
      delete: () => dataSyncRepository!.deleteWeightEntry(
        userId: userId!,
        entryId: entryId,
      ),
    );

    if (weightRepository != null) {
      await weightRepository.delete(entryId);
      weightEntries.removeWhere((item) => item.id == entryId);
      await _finishLocalDelete(
        kind: PendingRecordKind.weight,
        id: entryId,
        confirmed: confirmed,
      );
      await _refreshProfileWeightFromEntries();
    }
  }

  /// 本番の削除が確認できたら true。失敗したときは手元を残したまま例外を戻す。
  Future<bool> _confirmRemoteDelete({
    required PendingRecordKind kind,
    required String id,
    required bool enabled,
    required String missingUser,
    required Future<void> Function() delete,
  }) async {
    if (!enabled) {
      return false;
    }
    if (_authenticationRepository?.currentUser?.id == null) {
      throw StateError(missingUser);
    }
    try {
      await delete();
      return true;
    } catch (_) {
      await _pendingRecords.markDelete(kind, id);
      rethrow;
    }
  }

  Future<void> _finishLocalDelete({
    required PendingRecordKind kind,
    required String id,
    required bool confirmed,
  }) async {
    if (confirmed) {
      await _pendingRecords.forget(kind, id);
      return;
    }
    await _pendingRecords.markDelete(kind, id);
  }

  Future<void> _reloadWeightEntries() async {
    final weightRepository = _weightRepository;
    if (weightRepository == null) {
      return;
    }
    weightEntries
      ..clear()
      ..addAll(await weightRepository.loadAll());
    notifyListeners();
  }

  Future<void> _refreshProfileWeightFromEntries() async {
    final currentProfile = profile;
    if (currentProfile == null) {
      refreshDailySummary();
      return;
    }

    profile = currentProfile.copyWith(
      weightKg: currentWeightSelection.kg > 0
          ? currentWeightSelection.kg
          : currentProfile.weightKg,
    );
    await _userRepository?.saveProfile(profile!);
    _scheduleRemoteSync();
    refreshDailySummary();
    unawaited(publishSiriVoiceCatalog());
  }

  void _rememberManualWeight(double weightKg) {
    WeightEntry? latestManual;
    for (final entry in weightEntries) {
      if (entry.source != WeightSource.manual) {
        continue;
      }
      if (latestManual == null ||
          entry.recordedAt.isAfter(latestManual.recordedAt)) {
        latestManual = entry;
      }
    }
    if (latestManual != null &&
        (latestManual.weightKg - weightKg).abs() < 0.05) {
      return;
    }
    final daysBefore = _reviewLoggedDays();
    final entry = WeightEntry(
      id: generateId(),
      weightKg: weightKg,
      recordedAt: DateTime.now(),
      source: WeightSource.manual,
    );
    weightEntries.add(entry);
    _noteReviewRecords(daysBefore: daysBefore, origin: ReviewRecordOrigin.app);
    final repository = _weightRepository;
    if (repository != null) {
      unawaited(repository.save(entry));
    }
  }

  Future<void> updateBasicProfile({
    required DateTime birthDate,
    required Gender gender,
    required double heightCm,
    required String displayName,
    double? manualWeightKg,
  }) async {
    _usage('profile_updated', {
      'changed_fields': 'basic',
      'source': 'settings',
    });
    final currentProfile = profile;
    if (currentProfile == null) {
      return;
    }

    final weightChanged =
        manualWeightKg != null &&
        (manualWeightKg - currentProfile.weightKg).abs() > 0.009;

    profile = currentProfile.copyWith(
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
      displayName: displayName,
    );
    await _userRepository?.saveProfile(profile!);

    if (weightChanged) {
      await recordManualWeight(manualWeightKg);
      return;
    }

    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> saveGoalSettings(Goal value) async {
    CatalogActions.settingsChanged(
      settingKey: 'goal',
      newValue: value.type.name,
    );
    _usage('goal_updated', {'source': 'settings', 'target_mode': 'auto'});
    goal = value;
    await _userRepository?.saveGoal(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> saveNutritionSettingsSettings(NutritionSettings value) async {
    CatalogActions.settingsChanged(
      settingKey: 'nutrition',
      newValue: value.calorieTargetMode.name,
    );
    _usage('goal_updated', {'source': 'settings', 'target_mode': 'manual'});
    final next = _settingsPreservingAutoSwitch(value);
    nutritionSettings = next;
    await _settingsRepository?.saveNutritionSettings(next);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> updateActivityLevel(ActivityLevel activityLevel) async {
    CatalogActions.settingsChanged(
      settingKey: 'activity_level',
      newValue: activityLevel.name,
    );
    _usage('profile_updated', {
      'changed_fields': 'activity_level',
      'source': 'settings',
    });
    final current = nutritionSettings;
    await saveNutritionSettingsSettings(
      (current ??
              const NutritionSettings(
                useHealthIntegration: false,
                activityLevel: ActivityLevel.moderate,
              ))
          .copyWith(useHealthIntegration: false, activityLevel: activityLevel),
    );
  }

  Future<bool> enableHealthIntegration() async {
    CatalogActions.settingsChanged(settingKey: 'health', newValue: 'on');
    CatalogActions.onboardingStepView('health');
    final healthRepository = _healthRepository;
    if (healthRepository == null || !healthRepository.isAvailable) {
      _usage('health_permission_result', {
        'context': 'settings',
        'granted': false,
      });
      _usage('health_integration_changed', {
        'enabled': false,
        'context': 'settings',
      });
      return false;
    }

    final granted = await healthRepository.requestPermissions();
    _usage('health_permission_result', {
      'context': 'settings',
      'granted': granted,
    });
    _usage('health_integration_changed', {
      'enabled': granted,
      'context': 'settings',
    });
    final profileData = granted
        ? await healthRepository.fetchProfileData()
        : HealthProfileData.empty;

    final current = nutritionSettings;
    await saveNutritionSettingsSettings(
      (current ?? const NutritionSettings(useHealthIntegration: true)).copyWith(
        useHealthIntegration: true,
      ),
    );
    await applyHealthProfileData(profileData);
    return granted;
  }

  Future<void> disableHealthIntegration({ActivityLevel? activityLevel}) async {
    CatalogActions.settingsChanged(settingKey: 'health', newValue: 'off');
    _usage('health_integration_changed', {
      'enabled': false,
      'context': 'settings',
    });
    final fallbackLevel =
        activityLevel ??
        nutritionSettings?.activityLevel ??
        ActivityLevel.moderate;
    final current = nutritionSettings;
    await saveNutritionSettingsSettings(
      (current ??
              NutritionSettings(
                useHealthIntegration: false,
                activityLevel: fallbackLevel,
              ))
          .copyWith(useHealthIntegration: false, activityLevel: fallbackLevel),
    );
  }

  Future<void> applyLandingSuggestion(LandingGuidanceAction action) async {
    CatalogActions.landingGuidanceShown(action.name);
    _usage('landing_guidance_tap', {'action': action.name});
    final currentGoal = goal;
    final guidance = summary?.energyBreakdown?.guidance;
    if (currentGoal == null || guidance == null) {
      return;
    }
    final next = switch (action) {
      LandingGuidanceAction.extendDate =>
        guidance.suggestedDate == null
            ? null
            : currentGoal.copyWith(targetDate: guidance.suggestedDate),
      LandingGuidanceAction.changeWeight =>
        guidance.suggestedWeightKg == null
            ? null
            : currentGoal.copyWith(targetWeightKg: guidance.suggestedWeightKg),
      LandingGuidanceAction.useStandardPace => currentGoal.copyWith(
        goalPace: GoalPace.standard,
      ),
    };
    if (next == null) {
      return;
    }
    await saveGoalSettings(next);
  }

  Future<bool> resyncHealthData() async {
    final started = DateTime.now();
    void emit(String result, {int weightSamples = 0}) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _usage('health_sync_result', {
        'trigger': 'manual',
        'result': result,
        'workouts_imported': 0,
        'weight_samples_imported': weightSamples,
        'duration_ms': elapsed < 0 ? 0 : elapsed,
      });
    }

    final healthRepository = _healthRepository;
    if (healthRepository == null || !useHealthIntegration) {
      emit('failed');
      return false;
    }

    try {
      final profileData = await healthRepository.fetchProfileData();
      await applyHealthProfileData(profileData);
      final hasWeight = profileData.weightKg != null;
      final ok = hasWeight || profileData.activeEnergyBurnedKcal != null;
      emit(ok ? 'success' : 'failed', weightSamples: hasWeight ? 1 : 0);
      return ok;
    } catch (error, stackTrace) {
      emit('failed');
      debugPrint('[AYG] health sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void setGoal(Goal value) {
    CatalogActions.settingsChanged(
      settingKey: 'goal',
      newValue: value.type.name,
    );
    goal = value;
    _userRepository?.saveGoal(value);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  void setNutritionSettings(NutritionSettings value) {
    CatalogActions.settingsChanged(
      settingKey: 'nutrition',
      newValue: value.calorieTargetMode.name,
    );
    final next = _settingsPreservingAutoSwitch(value);
    nutritionSettings = next;
    _settingsRepository?.saveNutritionSettings(next);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  NutritionSettings _settingsPreservingAutoSwitch(NutritionSettings value) {
    final previous = nutritionSettings;
    final switchingToAutomatic =
        previous?.calorieTargetMode == CalorieTargetMode.manual &&
        value.calorieTargetMode == CalorieTargetMode.automatic;
    if (!switchingToAutomatic) {
      return value;
    }
    return value.copyWith(clearAutoFoodTarget: true);
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

    final day = referenceDate ?? DateTime.now();
    _summaryDay = day;
    summary = _nutritionEngine.calculateDailySummary(
      profile: currentProfile,
      goal: currentGoal,
      settings: settings,
      healthSnapshot: healthSnapshot,
      goalPace: currentGoal.goalPace,
      foodEntries: List.unmodifiable(foodEntries),
      exerciseEntries: List.unmodifiable(exerciseEntries),
      alcoholEntries: List.unmodifiable(alcoholEntries),
      referenceDate: day,
      weightSamples: calculationWeightSamples(),
    );
    _persistAutoTargetAnchor(day);
    notifyListeners();
    unawaited(publishLockScreenMealSnapshot());
  }

  void _persistAutoTargetAnchor(DateTime referenceDate) {
    final settings = nutritionSettings;
    final update = summary?.energyBreakdown?.anchorUpdate;
    if (settings == null ||
        update == null ||
        settings.usesManualTargets ||
        !isSameLocalDay(referenceDate, DateTime.now())) {
      return;
    }
    final sameTarget =
        settings.autoFoodTargetKcal != null &&
        (settings.autoFoodTargetKcal! - update.targetKcal).abs() < 0.05;
    final sameDay =
        settings.autoFoodTargetOn != null &&
        isSameLocalDay(settings.autoFoodTargetOn!, update.targetOn);
    final samePrior =
        settings.autoFoodTargetPriorKcal == null && update.priorKcal == null ||
        (settings.autoFoodTargetPriorKcal != null &&
            update.priorKcal != null &&
            (settings.autoFoodTargetPriorKcal! - update.priorKcal!).abs() <
                0.05);
    if (sameTarget && sameDay && samePrior) {
      return;
    }
    nutritionSettings = settings.copyWith(
      autoFoodTargetKcal: update.targetKcal,
      autoFoodTargetOn: update.targetOn,
      autoFoodTargetPriorKcal: update.priorKcal,
      clearAutoFoodTargetPrior: update.priorKcal == null,
    );
    final saved = nutritionSettings;
    if (saved != null) {
      _settingsRepository?.saveNutritionSettings(saved);
      _scheduleRemoteSync();
    }
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

  Future<void> _reloadAlcoholEntries() async {
    final alcoholRepository = _alcoholRepository;
    if (alcoholRepository == null) {
      return;
    }
    alcoholEntries
      ..clear()
      ..addAll(await alcoholRepository.loadAll());
  }

  void _placeExerciseEntry(ExerciseEntry entry) {
    _placeByTime(
      exerciseEntries,
      entry,
      (item) => item.id,
      (item) => item.loggedAt,
    );
  }

  void _placeAlcoholEntry(AlcoholEntry entry) {
    _placeByTime(
      alcoholEntries,
      entry,
      (item) => item.id,
      (item) => item.consumedAt,
    );
  }

  void _placeWeightEntry(WeightEntry entry) {
    _placeByTime(
      weightEntries,
      entry,
      (item) => item.id,
      (item) => item.recordedAt,
    );
  }

  /// 新しい順。loadAll の並びと同じで、全件は読み直さない。
  void _placeByTime<T>(
    List<T> items,
    T entry,
    String Function(T item) id,
    DateTime Function(T item) time,
  ) {
    final entryId = id(entry);
    items.removeWhere((item) => id(item) == entryId);
    final at = time(entry);
    var index = 0;
    while (index < items.length && !at.isAfter(time(items[index]))) {
      index++;
    }
    items.insert(index, entry);
  }

  String generateId() => generateUniqueId();

  static const foodMemoMaxLength = 200;

  /// 空のメモは保存しない。無料でもカロナビ+でも同じ。
  String? storedFoodMemo(String? memo) {
    final trimmed = memo?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= foodMemoMaxLength) {
      return trimmed;
    }
    return trimmed.substring(0, foodMemoMaxLength);
  }

  /// 空の運動メモは保存しない。無料でもカロナビ+でも同じ。
  String? storedExerciseNotes(String? notes) {
    final trimmed = notes?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  ExerciseEntry _exerciseEntryForStorage(ExerciseEntry entry) {
    final notes = storedExerciseNotes(entry.notes);
    if (notes == entry.notes) {
      return entry;
    }
    return entry.copyWith(notes: notes, clearNotes: notes == null);
  }

  Future<bool> repeatRecentFood(
    FoodEntry source, {
    double? consumedAmount,
    DateTime? loggedAt,
  }) async {
    if (!_subscriptionRepository.isPlusActive) {
      return false;
    }
    final amount = consumedAmount ?? source.consumedAmount;
    if (amount <= 0) {
      return false;
    }
    // メモは前回の登録に残す。同じ食品をあとから足しても写さない。
    await addFood(
      FoodEntry(
        id: generateId(),
        name: source.name,
        kcalPerBase: source.kcalPerBase,
        proteinPerBase: source.proteinPerBase,
        fatPerBase: source.fatPerBase,
        carbPerBase: source.carbPerBase,
        baseAmount: source.baseAmount,
        unitType: source.unitType,
        consumedAmount: amount,
        sourceType: source.sourceType,
        savedFoodId: source.savedFoodId,
        sourceFoodOwnerUserId: source.sourceFoodOwnerUserId,
        sourceSavedFoodVersion: source.sourceSavedFoodVersion,
        officialFoodCode: source.officialFoodCode,
        officialFoodName: source.officialFoodName,
        loggedAt: loggedAt ?? DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> updateFoodMemo(FoodEntry entry, String? memo) async {
    _usage('food_memo_saved', {
      'food_entry_id': entry.id,
      'has_memo': memo != null && memo.isNotEmpty,
      'memo_length': memo?.length ?? 0,
    });
    final stored = storedFoodMemo(memo);
    await updateFood(entry.copyWith(memo: stored, clearMemo: stored == null));
    return true;
  }

  Set<DateTime> _reviewLoggedDays() {
    return reviewLoggedDays(
      foodLoggedAts: foodEntries.map((entry) => entry.loggedAt),
      exerciseLoggedAts: exerciseEntries.map((entry) => entry.loggedAt),
      alcoholConsumedAts: alcoholEntries.map((entry) => entry.consumedAt),
      weightEntries: weightEntries,
    );
  }

  void _noteReviewRecords({
    required Set<DateTime> daysBefore,
    required ReviewRecordOrigin origin,
  }) {
    final streak = reviewStreakJustCompleted(
      daysBefore: daysBefore,
      daysAfter: _reviewLoggedDays(),
      now: DateTime.now(),
    );
    final external = reviewOriginIsExternal(origin);
    if (!streak && !external) {
      return;
    }
    unawaited(_markReviewDue(streak: streak, external: external));
  }

  Future<void> _markReviewDue({
    required bool streak,
    required bool external,
  }) async {
    final opened = await _reviewPromptStore.markDue(
      streak: streak,
      external: external,
    );
    if (opened) {
      reviewPromptTick.value++;
    }
  }

  Future<void> addFood(FoodEntry entry) async {
    final stored = _foodWithOrigin(entry, ReviewRecordOrigin.app);
    final daysBefore = _reviewLoggedDays();
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.save(stored);
      // 全件 loadAll は UI アイソレートを止める。保存した1件だけ足す。
      _placeSavedFoodEntry(stored);
    } else {
      foodEntries.add(stored);
    }
    _scheduleFoodEntrySync(stored);
    refreshDailySummary();
    _emitFoodAdded(stored, ReviewRecordOrigin.app);
    _noteReviewRecords(daysBefore: daysBefore, origin: ReviewRecordOrigin.app);
    await _pendingRecords.markUpsert(PendingRecordKind.food, stored.id);
  }

  /// 新しい順（loggedAt 降順）。loadAll と同じ並び。
  void _placeSavedFoodEntry(FoodEntry entry) {
    foodEntries.removeWhere((item) => item.id == entry.id);
    var index = 0;
    while (index < foodEntries.length &&
        !entry.loggedAt.isAfter(foodEntries[index].loggedAt)) {
      index++;
    }
    foodEntries.insert(index, entry);
  }

  void _scheduleFoodEntrySync(FoodEntry entry) {
    if (!_hasInitialSyncCompleted || _lastSyncFailed) {
      return;
    }

    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (userId == null || dataSyncRepository == null) {
      return;
    }

    unawaited(_pushFoodEntryNow(dataSyncRepository, userId, entry));
  }

  Future<void> _pushFoodEntryNow(
    DataSyncRepository dataSyncRepository,
    String userId,
    FoodEntry entry,
  ) async {
    try {
      await _serialRemoteWrite(
        () => dataSyncRepository.pushFoodEntry(userId: userId, entry: entry),
      );
    } catch (error, stackTrace) {
      _hasUnsentRecords = true;
      debugPrint('[AYG] food entry push failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  FoodEntry _foodWithOrigin(FoodEntry entry, ReviewRecordOrigin origin) {
    final existing = entry.recordOrigin;
    if (existing != null && existing.isNotEmpty) {
      return entry;
    }
    return entry.copyWith(recordOrigin: origin.name);
  }

  ExerciseEntry _exerciseWithOrigin(
    ExerciseEntry entry,
    ReviewRecordOrigin origin,
  ) {
    final existing = entry.recordOrigin;
    if (existing != null && existing.isNotEmpty) {
      return entry;
    }
    return entry.copyWith(recordOrigin: origin.name);
  }

  Future<void> restoreFoodEntry(FoodEntry entry) async {
    _usage('food_entry_restored', {'food_entry_id': entry.id});
    await _pendingRecords.markUpsert(PendingRecordKind.food, entry.id);
    await _saveFoodEntryLocally(entry);
    refreshDailySummary();
    await _persistToRemoteNow();
  }

  Future<void> _saveFoodEntryLocally(FoodEntry entry) async {
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.save(entry);
      _placeSavedFoodEntry(entry);
    } else {
      final index = foodEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        foodEntries.add(entry);
      } else {
        foodEntries[index] = entry;
      }
    }
  }

  Future<void> updateFood(FoodEntry entry) async {
    _usage('food_entry_updated', {
      'food_entry_id': entry.id,
      'changed_fields': 'quantity',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.food, entry.id);
    final kept = _keepFoodOrigin(entry);
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.save(kept);
      _placeSavedFoodEntry(kept);
    } else {
      final index = foodEntries.indexWhere((item) => item.id == kept.id);
      if (index == -1) {
        return;
      }
      foodEntries[index] = kept;
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  FoodEntry _keepFoodOrigin(FoodEntry entry) {
    final current = entry.recordOrigin;
    if (current != null && current.isNotEmpty) {
      return entry;
    }
    for (final existing in foodEntries) {
      if (existing.id != entry.id) {
        continue;
      }
      final origin = existing.recordOrigin;
      if (origin != null && origin.isNotEmpty) {
        return entry.copyWith(recordOrigin: origin);
      }
    }
    return entry;
  }

  ExerciseEntry _keepExerciseOrigin(ExerciseEntry entry) {
    final current = entry.recordOrigin;
    if (current != null && current.isNotEmpty) {
      return entry;
    }
    for (final existing in exerciseEntries) {
      if (existing.id != entry.id) {
        continue;
      }
      final origin = existing.recordOrigin;
      if (origin != null && origin.isNotEmpty) {
        return entry.copyWith(recordOrigin: origin);
      }
    }
    return entry;
  }

  Future<void> saveEditedFoodEntryWithSourceChoice({
    required FoodEntry entry,
    required FoodEntry originalEntry,
    required SourceFoodUpdateChoice sourceChoice,
  }) async {
    if (sourceChoice == SourceFoodUpdateChoice.cancel) {
      return;
    }

    var entryToSave = entry;

    if (sourceChoice == SourceFoodUpdateChoice.copyAndUpdateSource) {
      entryToSave = await _copyLinkedPublicFoodAndPatch(
        entry: entry,
        patch: SourceFoodEditPolicy.fromFoodEntry(entry),
      );
    } else if (sourceChoice == SourceFoodUpdateChoice.updateSource) {
      await _patchLinkedOwnSavedFood(
        savedFoodId: entry.savedFoodId!,
        patch: SourceFoodEditPolicy.fromFoodEntry(entry),
      );
    }

    await updateFood(entryToSave);
  }

  Future<void> _patchLinkedOwnSavedFood({
    required String savedFoodId,
    required SavedFoodPatch patch,
  }) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    final existing = await repository.getOwn(
      ownerUserId: currentOwnerUserId,
      foodId: savedFoodId,
    );
    if (existing == null) {
      throw StateError('Saved food not found');
    }

    final updated = existing.copyWith(
      name: patch.name,
      normalizedName: FoodNameNormalizer.normalize(patch.name),
      baseAmount: patch.baseAmount,
      unitType: patch.unitType,
      kcalPerBase: patch.kcalPerBase,
      proteinPerBase: patch.proteinPerBase,
      fatPerBase: patch.fatPerBase,
      carbPerBase: patch.carbPerBase,
      updatedAt: DateTime.now(),
    );

    if (updated.visibility == FoodVisibility.public) {
      await updatePublishedSavedFood(updated, confirmedPublicUpdate: true);
    } else {
      await updateSavedFood(updated);
    }
  }

  Future<FoodEntry> _copyLinkedPublicFoodAndPatch({
    required FoodEntry entry,
    required SavedFoodPatch patch,
  }) async {
    final repository = _savedFoodRepository;
    final sourceOwnerUserId = entry.sourceFoodOwnerUserId;
    final savedFoodId = entry.savedFoodId;
    if (repository == null ||
        sourceOwnerUserId == null ||
        savedFoodId == null) {
      throw StateError('Linked public food is unavailable');
    }

    final source = await repository.getPublicById(
      ownerUserId: sourceOwnerUserId,
      foodId: savedFoodId,
    );
    if (source == null) {
      throw StateError('Public source food not found');
    }

    final copy = await copyPublicFoodToPrivate(source);
    final patched = await updateSavedFood(
      copy.copyWith(
        name: patch.name,
        normalizedName: FoodNameNormalizer.normalize(patch.name),
        baseAmount: patch.baseAmount,
        unitType: patch.unitType,
        kcalPerBase: patch.kcalPerBase,
        proteinPerBase: patch.proteinPerBase,
        fatPerBase: patch.fatPerBase,
        carbPerBase: patch.carbPerBase,
        updatedAt: DateTime.now(),
      ),
    );

    return entry.copyWith(
      savedFoodId: patched.foodId,
      sourceFoodOwnerUserId: currentOwnerUserId,
      sourceSavedFoodVersion: patched.version,
    );
  }

  /// 送信中の同期が終わってから消す。送信中に消すと、その送信が消した行を
  /// サーバへ書き戻し、次の再インストールで記録が復活する。
  Future<void> deleteFood(String id) =>
      _serialRemoteWrite(() => _deleteFoodNow(id));

  Future<void> _deleteFoodNow(String id) async {
    _usage('food_entry_deleted', {'food_entry_id': id, 'undo_offered': true});
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    final foodRepository = _foodRepository;
    final confirmed = await _confirmRemoteDelete(
      kind: PendingRecordKind.food,
      id: id,
      enabled: dataSyncRepository?.supportsRemoteFoodEntryDelete ?? false,
      missingUser: 'Authentication required to delete food entry.',
      delete: () =>
          dataSyncRepository!.deleteFoodEntry(userId: userId!, entryId: id),
    );

    if (foodRepository != null) {
      await foodRepository.delete(id);
      foodEntries.removeWhere((item) => item.id == id);
    } else {
      foodEntries.removeWhere((item) => item.id == id);
    }
    await _finishLocalDelete(
      kind: PendingRecordKind.food,
      id: id,
      confirmed: confirmed,
    );
    refreshDailySummary();
  }

  Future<void> addExercise(
    ExerciseEntry entry, {
    ReviewRecordOrigin origin = ReviewRecordOrigin.app,
    String? analyticsOrigin,
    bool countAnalytics = true,
  }) async {
    if (countAnalytics) {
      _usage(
        'exercise_entry_added',
        {
          'exercise_entry_ids': [entry.id],
          'method': origin == ReviewRecordOrigin.siri
              ? 'siri'
              : origin == ReviewRecordOrigin.widget
              ? 'widget'
              : 'catalog',
          'items_count': 1,
        },
        analyticsOrigin ??
            (origin == ReviewRecordOrigin.siri
                ? 'siri'
                : origin == ReviewRecordOrigin.widget
                ? 'home_widget'
                : 'app'),
      );
    }
    final stored = _exerciseWithOrigin(_exerciseEntryForStorage(entry), origin);
    final daysBefore = _reviewLoggedDays();
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.save(stored);
      _placeExerciseEntry(stored);
    } else {
      exerciseEntries.add(stored);
    }
    _noteReviewRecords(daysBefore: daysBefore, origin: origin);
    await _pendingRecords.markUpsert(PendingRecordKind.exercise, stored.id);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> restoreExerciseEntry(ExerciseEntry entry) async {
    _usage('exercise_entry_restored', {'exercise_entry_id': entry.id});
    await _pendingRecords.markUpsert(PendingRecordKind.exercise, entry.id);
    await _saveExerciseEntryLocally(entry);
    refreshDailySummary();
    await _persistToRemoteNow();
  }

  Future<void> _saveExerciseEntryLocally(ExerciseEntry entry) async {
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.save(entry);
      _placeExerciseEntry(entry);
    } else {
      final index = exerciseEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        exerciseEntries.add(entry);
      } else {
        exerciseEntries[index] = entry;
      }
    }
  }

  Future<void> updateExercise(ExerciseEntry entry) async {
    _usage('exercise_entry_updated', {
      'exercise_entry_id': entry.id,
      'changed_fields': 'duration',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.exercise, entry.id);
    final stored = _exerciseEntryForStorage(_keepExerciseOrigin(entry));
    final exerciseRepository = _exerciseRepository;
    if (exerciseRepository != null) {
      await exerciseRepository.save(stored);
      _placeExerciseEntry(stored);
    } else {
      final index = exerciseEntries.indexWhere((item) => item.id == stored.id);
      if (index == -1) {
        return;
      }
      exerciseEntries[index] = stored;
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  /// 送信中の同期が終わってから消す。送信中に消すと、その送信が消した行を
  /// サーバへ書き戻し、次の再インストールで記録が復活する。
  Future<void> deleteExercise(String id) =>
      _serialRemoteWrite(() => _deleteExerciseNow(id));

  Future<void> _deleteExerciseNow(String id) async {
    _usage('exercise_entry_deleted', {
      'exercise_entry_id': id,
      'undo_offered': true,
    });
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    final exerciseRepository = _exerciseRepository;
    final confirmed = await _confirmRemoteDelete(
      kind: PendingRecordKind.exercise,
      id: id,
      enabled: dataSyncRepository?.supportsRemoteExerciseEntryDelete ?? false,
      missingUser: 'Authentication required to delete exercise entry.',
      delete: () =>
          dataSyncRepository!.deleteExerciseEntry(userId: userId!, entryId: id),
    );

    if (exerciseRepository != null) {
      await exerciseRepository.delete(id);
      exerciseEntries.removeWhere((item) => item.id == id);
    } else {
      exerciseEntries.removeWhere((item) => item.id == id);
    }
    await _finishLocalDelete(
      kind: PendingRecordKind.exercise,
      id: id,
      confirmed: confirmed,
    );
    refreshDailySummary();
  }

  Future<void> addAlcohol(AlcoholEntry entry) async {
    _usage('alcohol_entry_added', {'alcohol_entry_id': entry.id});
    final daysBefore = _reviewLoggedDays();
    final alcoholRepository = _alcoholRepository;
    if (alcoholRepository != null) {
      await alcoholRepository.save(entry);
      _placeAlcoholEntry(entry);
    } else {
      alcoholEntries.add(entry);
    }
    _noteReviewRecords(daysBefore: daysBefore, origin: ReviewRecordOrigin.app);
    await _pendingRecords.markUpsert(PendingRecordKind.alcohol, entry.id);
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  Future<void> restoreAlcoholEntry(AlcoholEntry entry) async {
    _usage('alcohol_entry_changed', {
      'alcohol_entry_id': entry.id,
      'action': 'restore',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.alcohol, entry.id);
    await _saveAlcoholEntryLocally(entry);
    refreshDailySummary();
    await _persistToRemoteNow();
  }

  Future<void> _saveAlcoholEntryLocally(AlcoholEntry entry) async {
    final alcoholRepository = _alcoholRepository;
    if (alcoholRepository != null) {
      await alcoholRepository.save(entry);
      _placeAlcoholEntry(entry);
    } else {
      final index = alcoholEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        alcoholEntries.add(entry);
      } else {
        alcoholEntries[index] = entry;
      }
    }
  }

  Future<void> updateAlcohol(AlcoholEntry entry) async {
    _usage('alcohol_entry_changed', {
      'alcohol_entry_id': entry.id,
      'action': 'update',
    });
    await _pendingRecords.markUpsert(PendingRecordKind.alcohol, entry.id);
    final alcoholRepository = _alcoholRepository;
    if (alcoholRepository != null) {
      await alcoholRepository.save(entry);
      _placeAlcoholEntry(entry);
    } else {
      final index = alcoholEntries.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        return;
      }
      alcoholEntries[index] = entry;
    }
    _scheduleRemoteSync();
    refreshDailySummary();
  }

  /// 送信中の同期が終わってから消す。送信中に消すと、その送信が消した行を
  /// サーバへ書き戻し、次の再インストールで記録が復活する。
  Future<void> deleteAlcohol(String id) =>
      _serialRemoteWrite(() => _deleteAlcoholNow(id));

  Future<void> _deleteAlcoholNow(String id) async {
    _usage('alcohol_entry_changed', {
      'alcohol_entry_id': id,
      'action': 'delete',
    });
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    final alcoholRepository = _alcoholRepository;
    final confirmed = await _confirmRemoteDelete(
      kind: PendingRecordKind.alcohol,
      id: id,
      enabled: dataSyncRepository?.supportsRemoteAlcoholEntryDelete ?? false,
      missingUser: 'Authentication required to delete alcohol entry.',
      delete: () =>
          dataSyncRepository!.deleteAlcoholEntry(userId: userId!, entryId: id),
    );

    if (alcoholRepository != null) {
      await alcoholRepository.delete(id);
      alcoholEntries.removeWhere((item) => item.id == id);
    } else {
      alcoholEntries.removeWhere((item) => item.id == id);
    }
    await _finishLocalDelete(
      kind: PendingRecordKind.alcohol,
      id: id,
      confirmed: confirmed,
    );
    refreshDailySummary();
  }

  // --- Saved food (Phase 6A–6C) ---

  Future<SavedFood> createSavedFood(SavedFoodDraft draft) async {
    _usage('saved_food_created', {'visibility': 'private', 'from': 'form'});
    final repository = _savedFoodRepository;
    if (repository == null) {
      throw StateError('SavedFoodRepository is not configured');
    }

    final authUser = _authenticationRepository?.currentUser;
    if (authUser == null) {
      final error = SavedFoodPersistenceException(
        errorCode: SavedFoodErrorCode.authRequired,
        message: 'Authentication required.',
        repositoryStep: 'AppController.createSavedFood',
        operation: 'validate',
      )..logDebug();
      throw error;
    }

    await _ensureAuthenticatedUserProfile();

    final unitLabel = draft.servingUnitLabel.trim();
    if (unitLabel.isEmpty) {
      throw SavedFoodPersistenceException(
        errorCode: SavedFoodErrorCode.validationFailed,
        message: '基準単位を入力してください',
        repositoryStep: 'AppController.createSavedFood',
        operation: 'validate',
      )..logDebug();
    }
    if (draft.baseAmount <= 0) {
      throw SavedFoodPersistenceException(
        errorCode: SavedFoodErrorCode.validationFailed,
        message: '基準数量は0より大きい数値で入力してください',
        repositoryStep: 'AppController.createSavedFood',
        operation: 'validate',
      )..logDebug();
    }

    final now = DateTime.now();
    final unitType = FoodUnitTypeX.inferFromUnitLabel(unitLabel);
    final food = SavedFood(
      foodId: generateId(),
      ownerUserId: authUser.id,
      name: draft.name.trim(),
      normalizedName: FoodNameNormalizer.normalize(draft.name),
      baseAmount: draft.baseAmount,
      unitType: unitType,
      servingUnitLabel: unitLabel,
      kcalPerBase: draft.kcalPerBase,
      proteinPerBase: draft.proteinPerBase,
      fatPerBase: draft.fatPerBase,
      carbPerBase: draft.carbPerBase,
      brand: draft.brand,
      barcode: draft.barcode,
      supplementaryWeight: draft.supplementaryWeight,
      officialFoodCode: draft.officialFoodCode,
      officialFoodName: draft.officialFoodName,
      sourceAttribution: draft.sourceAttribution,
      sourceType: draft.sourceType,
      visibility: FoodVisibility.private,
      status: FoodStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    final saved = OfficialFoodProvenance.attach(food).normalizedForSave();

    await repository.savePrivate(saved);

    if (draft.visibility == FoodVisibility.public) {
      final validation = validateSavedFoodForPublish(saved);
      if (!validation.isValid) {
        throw SavedFoodPersistenceException(
          errorCode: SavedFoodErrorCode.validationFailed,
          message: validation.errors.join('\n'),
          repositoryStep: 'AppController.createSavedFood',
          operation: 'publish_validate',
        );
      }

      final duplicate = await checkPublicDuplicate(saved);
      if (duplicate != null) {
        CatalogActions.publicFoodDuplicateWarning(
          kind: 'exact',
          choice: 'blocked',
        );
        throw SavedFoodPersistenceException(
          errorCode: SavedFoodErrorCode.conflict,
          message: 'Duplicate public food exists.',
          repositoryStep: 'AppController.createSavedFood',
          operation: 'publish_duplicate_check',
        );
      }

      final published = await repository.publish(
        ownerUserId: authUser.id,
        foodId: saved.foodId,
      );
      _scheduleRemoteSync();
      unawaited(publishSiriVoiceCatalog());
      return published;
    }

    _scheduleRemoteSync();
    unawaited(publishSiriVoiceCatalog());
    return saved;
  }

  Future<SavedFood> updateSavedFood(SavedFood food) async {
    CatalogActions.savedFoodUpdated(
      savedFoodId: food.foodId,
      visibility: food.visibility.name,
      changedFields: 'form',
    );
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

    await _ensureAuthenticatedUserProfile();

    var updated = OfficialFoodProvenance.attach(food)
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
    _usage('public_food_published', {
      'saved_food_id': foodId,
      'action': 'publish',
    });
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
    _usage('public_food_published', {
      'saved_food_id': foodId,
      'action': 'unpublish',
    });
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
    _usage('saved_food_deleted', {'saved_food_id': foodId});
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
    unawaited(publishSiriVoiceCatalog());
  }

  Future<List<SavedFood>> searchOwnSavedFoods(String query) async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }

    _recordFoodSearch(FoodSearchSources.savedFood, query);
    final results = await repository.searchOwn(
      ownerUserId: currentOwnerUserId,
      query: query,
    );
    final ranked = _savedFoodSearchService.rankOwnResults(
      foods: results,
      query: query,
    );
    noteFoodSearchResults(
      source: FoodSearchSources.savedFood,
      count: ranked.length,
    );
    return ranked;
  }

  /// 食品を探すの空欄用。検索語の記録や利用回数での並べ替えはしない。
  Future<List<SavedFood>> listOwnSavedFoods() async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }
    return repository.searchOwn(ownerUserId: currentOwnerUserId, query: '');
  }

  Future<List<SavedFood>> getOwnSavedFoodSuggestions() async {
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }
    final results = await repository.searchOwn(
      ownerUserId: currentOwnerUserId,
      query: '',
    );
    return _searchSuggestionService.rankSavedFoodSuggestions(results);
  }

  Future<List<MealTemplate>> getMealTemplateSuggestions() async {
    return searchMealTemplates('');
  }

  Future<List<FoodFormSuggestion>> getFoodFormSuggestions(String query) async {
    final trimmed = query.trim();
    final foods = trimmed.isEmpty
        ? await getOwnSavedFoodSuggestions()
        : await searchOwnSavedFoods(trimmed);
    final templates = await searchMealTemplates(trimmed);

    final ranked = _searchSuggestionService.rankFoodFormSuggestions(
      foods: foods,
      templates: templates,
      templateItemCounts: const {},
    );
    final mealRepo = _mealTemplateRepository;
    if (mealRepo == null) {
      return ranked;
    }

    // 画面に出す5件だけ品数を数える。全テンプレートを毎回読むと入力のたびに止まる。
    final shownTemplates = ranked
        .whereType<MealTemplateFormSuggestion>()
        .take(5)
        .toList();
    if (shownTemplates.isEmpty) {
      return ranked;
    }
    final itemCounts = <String, int>{};
    for (final suggestion in shownTemplates) {
      final items = await mealRepo.getItems(
        ownerUserId: currentOwnerUserId,
        templateId: suggestion.template.templateId,
      );
      itemCounts[suggestion.template.templateId] = items.length;
    }
    return [
      for (final suggestion in ranked)
        if (suggestion is MealTemplateFormSuggestion &&
            itemCounts.containsKey(suggestion.template.templateId))
          MealTemplateFormSuggestion(
            suggestion.template,
            itemCount: itemCounts[suggestion.template.templateId]!,
          )
        else
          suggestion,
    ];
  }

  Future<List<WorkoutTemplate>> getWorkoutTemplateSuggestions() async {
    return searchWorkoutTemplates('');
  }

  Future<List<String>> getExerciseNameSuggestions() async {
    final counts = <String, int>{};
    final lastUsed = <String, DateTime>{};
    for (final entry in exerciseEntries) {
      final name = entry.name.trim();
      if (name.isEmpty) {
        continue;
      }
      final key = FoodNameNormalizer.normalize(name);
      counts[key] = (counts[key] ?? 0) + 1;
      final loggedAt = entry.loggedAt;
      final previous = lastUsed[key];
      if (previous == null || loggedAt.isAfter(previous)) {
        lastUsed[key] = loggedAt;
      }
    }

    final displayNames = <String, String>{};
    for (final entry in exerciseEntries) {
      final name = entry.name.trim();
      if (name.isEmpty) {
        continue;
      }
      displayNames[FoodNameNormalizer.normalize(name)] = name;
    }

    final keys = counts.keys.toList()
      ..sort((a, b) {
        final countCompare = counts[b]!.compareTo(counts[a]!);
        if (countCompare != 0) {
          return countCompare;
        }
        final usedCompare = lastUsed[b]!.compareTo(lastUsed[a]!);
        if (usedCompare != 0) {
          return usedCompare;
        }
        return a.compareTo(b);
      });

    return keys.map((key) => displayNames[key] ?? key).toList();
  }

  Future<List<PublicFoodSearchMatch>> searchPublicSavedFoods(
    String query, {
    bool surfaceErrors = false,
  }) async {
    _usage('public_food_search_quota', {
      'remaining': 0,
      'limit': 0,
      'is_plus': _subscriptionRepository.isPlusActive,
    });
    final repository = _savedFoodRepository;
    if (repository == null) {
      return const [];
    }

    _recordFoodSearch(FoodSearchSources.publicFood, query);
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
      final ranked = _publicFoodSearchService.rankResults(
        candidates: candidates,
        query: query,
        ratingsByKey: ratingsByKey,
      );
      noteFoodSearchResults(
        source: FoodSearchSources.publicFood,
        count: ranked.length,
      );
      return ranked;
    } catch (error) {
      if (surfaceErrors) {
        rethrow;
      }
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

  Future<PublicFoodRatingResult> setPublicFoodGood(SavedFood food) {
    CatalogActions.publicFoodRated(savedFoodId: food.foodId, rating: 'good');
    return _mutatePublicFoodRating(
      food: food,
      mutate: (ratingId) => _foodRatingRepository!.setGood(
        foodOwnerUserId: food.ownerUserId,
        foodId: food.foodId,
        raterUserId: currentOwnerUserId,
        ratingId: ratingId,
      ),
    );
  }

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
        errorMessage: userErrorMessage(error, action: '評価'),
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
        errorMessage: '自分の保存済み食品には評価できません',
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
        errorMessage: userErrorMessage(error, action: '評価'),
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
    CatalogActions.publicFoodReported(
      savedFoodId: food.foodId,
      reason: reasonCode.name,
    );
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
        errorMessage: '自分の保存済み食品は通報できません',
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
        errorMessage: userErrorMessage(error, action: '通報'),
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
    _usage('food_creator_blocked', {'action': 'block'});
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
    _usage('food_creator_blocked', {'action': 'unblock'});
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

  Future<void> addFoodEntriesBatch(
    List<FoodEntry> entries, {
    ReviewRecordOrigin origin = ReviewRecordOrigin.app,
  }) async {
    if (entries.isEmpty) {
      return;
    }
    final stored = [
      for (final entry in entries) _foodWithOrigin(entry, origin),
    ];
    final daysBefore = _reviewLoggedDays();
    final foodRepository = _foodRepository;
    if (foodRepository != null) {
      await foodRepository.saveAll(stored);
      for (final entry in stored) {
        _placeSavedFoodEntry(entry);
      }
    } else {
      foodEntries.addAll(stored);
    }
    _scheduleRemoteSync();
    refreshDailySummary();
    _noteReviewRecords(daysBefore: daysBefore, origin: origin);
    for (final entry in stored) {
      _emitFoodAdded(entry, origin);
      await _pendingRecords.markUpsert(PendingRecordKind.food, entry.id);
    }
  }

  void _emitFoodAdded(FoodEntry entry, ReviewRecordOrigin origin) {
    final link = origin == ReviewRecordOrigin.app ? _linkedFoodSearchId : null;
    if (origin == ReviewRecordOrigin.app) {
      _linkedFoodSearchId = null;
    }
    final method = switch (origin) {
      ReviewRecordOrigin.siri => 'siri',
      ReviewRecordOrigin.widget => 'widget',
      ReviewRecordOrigin.app => 'manual',
    };
    _usage('food_entry_added', {
      'food_entry_ids': [entry.id],
      'method': method,
      'items_count': 1,
      if (link != null) 'search_query_id': link,
    });
  }

  Future<void> registerFoodMealFromDrafts({
    required String mealGroupName,
    required List<MealTemplateItemDraft> items,
    required DateTime loggedAt,
    String? sourceTemplateId,
    String? memo,
  }) async {
    if (items.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final mealGroupId = generateId();
    final mappedItems = items
        .asMap()
        .entries
        .map(
          (entry) => entry.value
              .copyWithSortOrder(entry.key + 1)
              .toItem(itemId: generateId(), now: now),
        )
        .toList();
    final foodEntriesToSave = _mealTemplateApplyService.buildEntries(
      items: mappedItems,
      mealGroupId: mealGroupId,
      mealGroupName: mealGroupName,
      loggedAt: loggedAt,
      generateEntryId: generateId,
      memo: storedFoodMemo(memo),
    );
    await addFoodEntriesBatch(foodEntriesToSave);

    if (sourceTemplateId == null) {
      return;
    }

    final repository = _mealTemplateRepository;
    if (repository == null) {
      return;
    }

    final bundle = await getMealTemplateWithItems(sourceTemplateId);
    if (bundle == null) {
      return;
    }

    await repository.update(
      bundle.template.copyWith(
        useCount: bundle.template.useCount + 1,
        lastUsedAt: now,
        updatedAt: now,
      ),
    );
    _scheduleRemoteSync();
  }

  Future<List<MealTemplate>> searchMealTemplates(String query) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return const [];
    }
    _recordFoodSearch(FoodSearchSources.mealTemplate, query);
    final results = await repository.search(
      ownerUserId: currentOwnerUserId,
      query: query,
    );
    if (query.trim().isEmpty) {
      final ranked = _searchSuggestionService.rankMealTemplateSuggestions(
        results,
      );
      noteFoodSearchResults(
        source: FoodSearchSources.mealTemplate,
        count: ranked.length,
      );
      return ranked;
    }
    noteFoodSearchResults(
      source: FoodSearchSources.mealTemplate,
      count: results.length,
    );
    return results;
  }

  /// その他（手入力）を1種目だけ保存したテンプレート。スキーマは足していない。
  Future<List<CustomActivityTemplate>> listCustomActivityTemplates() async {
    final repository = _workoutTemplateRepository;
    if (repository == null) {
      return const [];
    }
    final templates = await repository.getAll(currentOwnerUserId);
    final saved = <CustomActivityTemplate>[];
    for (final template in templates) {
      final items = await repository.getItems(
        ownerUserId: currentOwnerUserId,
        templateId: template.templateId,
      );
      if (items.length != 1 || items.single.activityId != 'custom') {
        continue;
      }
      final item = items.single;
      saved.add(
        CustomActivityTemplate(
          templateId: template.templateId,
          itemId: item.itemId,
          name: template.name,
          durationMin: item.durationMin,
          categoryKey: item.categoryKey,
          intensity: item.intensity,
          sets: item.sets,
          reps: item.reps,
          liftWeightKg: item.liftWeightKg,
          metValue: item.metValue,
          sourceKey: item.sourceKey,
          notes: item.notes,
        ),
      );
    }
    saved.sort((a, b) => a.name.compareTo(b.name));
    return saved;
  }

  /// 手入力の種目をテンプレートへ足す。同じ名前があればそのテンプレートを更新する。
  /// 戻すときはそのテンプレートを削除する。新しい列は無い。
  Future<void> saveCustomActivityTemplate(ExerciseEntry entry) async {
    _usage('custom_activity_saved');
    final name = entry.name.trim();
    final normalized = FoodSearchNormalizer.normalize(name);
    final existing = await listCustomActivityTemplates();
    CustomActivityTemplate? match;
    for (final saved in existing) {
      if (FoodSearchNormalizer.normalize(saved.name) == normalized) {
        match = saved;
        break;
      }
    }
    await saveWorkoutTemplate(
      templateId: match?.templateId,
      draft: WorkoutTemplateDraft(
        name: name,
        items: [
          WorkoutTemplateItem(
            itemId: match?.itemId ?? generateId(),
            name: name,
            activityId: 'custom',
            categoryKey: entry.category?.id ?? match?.categoryKey,
            intensity: entry.intensity,
            durationMin: entry.durationMin,
            sets: entry.sets,
            reps: entry.reps,
            liftWeightKg: entry.liftWeightKg,
            sortOrder: 1,
            notes: entry.notes,
            metValue: entry.metValue,
            sourceKey: entry.sourceKey,
          ),
        ],
      ),
    );
  }

  Future<List<WorkoutTemplate>> searchWorkoutTemplates(String query) async {
    final repository = _workoutTemplateRepository;
    if (repository == null) {
      return const [];
    }
    _recordExerciseSearch(ExerciseSearchSources.workoutTemplate, query);
    final results = await repository.search(
      ownerUserId: currentOwnerUserId,
      query: query,
    );
    if (query.trim().isEmpty) {
      final ranked = _searchSuggestionService.rankWorkoutTemplateSuggestions(
        results,
      );
      noteExerciseSearchResults(
        source: ExerciseSearchSources.workoutTemplate,
        count: ranked.length,
      );
      return ranked;
    }
    noteExerciseSearchResults(
      source: ExerciseSearchSources.workoutTemplate,
      count: results.length,
    );
    return results;
  }

  Future<WorkoutTemplateWithItems?> getWorkoutTemplateWithItems(
    String templateId,
  ) async {
    final repository = _workoutTemplateRepository;
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
    return WorkoutTemplateWithItems(template: template, items: items);
  }

  Future<WorkoutTemplate> saveWorkoutTemplate({
    required WorkoutTemplateDraft draft,
    String? templateId,
  }) async {
    _usage('workout_template_saved', {
      'template_id': templateId,
      'action': templateId == null ? 'create' : 'update',
      'items_count': draft.items.length,
    });
    final repository = _workoutTemplateRepository;
    if (repository == null) {
      throw StateError('WorkoutTemplateRepository is not configured');
    }
    if (draft.name.trim().isEmpty) {
      throw ArgumentError('Template name is required');
    }
    if (draft.items.isEmpty) {
      throw ArgumentError('Template must include at least one item');
    }
    if (templateId == null && !await canCreateWorkoutTemplate()) {
      throw SubscriptionLimitExceededException(
        SubscriptionLimitKind.workoutTemplate,
      );
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
        .map((entry) => entry.value.copyWith(sortOrder: entry.key + 1))
        .toList();
    final template = WorkoutTemplate(
      templateId: id,
      ownerUserId: currentOwnerUserId,
      name: draft.name.trim(),
      normalizedName: FoodNameNormalizer.normalize(draft.name),
      useCount: existing?.useCount ?? 0,
      lastUsedAt: existing?.lastUsedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await repository.saveWithItems(template: template, items: mappedItems);
    _scheduleRemoteSync();
    return template;
  }

  Future<void> deleteWorkoutTemplate(String templateId) async {
    _usage('workout_template_deleted', {'template_id': templateId});
    final repository = _workoutTemplateRepository;
    if (repository == null) {
      throw StateError('WorkoutTemplateRepository is not configured');
    }
    await repository.softDelete(
      ownerUserId: currentOwnerUserId,
      templateId: templateId,
      deletedAt: DateTime.now(),
    );
    _scheduleRemoteSync();
  }

  Future<void> registerWorkoutEntriesFromDrafts(
    List<WorkoutTemplateApplyDraft> drafts,
  ) async {
    for (final draft in drafts) {
      final manual =
          MetActivityCatalog.findById(draft.activityId)?.requiresManualKcal ==
          true;
      await addExercise(
        ExerciseEntry(
          id: generateId(),
          name: draft.name,
          durationMin: draft.durationMin,
          burnedKcal: draft.grossKcal ?? draft.netKcal ?? 0,
          loggedAt: draft.loggedAt,
          category: ExerciseCategoryX.tryParse(draft.categoryKey),
          activityId: draft.activityId,
          intensity: manual ? null : draft.intensity,
          sets: draft.sets,
          reps: draft.reps,
          liftWeightKg: draft.liftWeightKg,
          metValue: manual ? null : draft.metValue,
          grossKcal: manual ? draft.netKcal : draft.grossKcal,
          netKcal: draft.netKcal,
          calculationSource: manual
              ? ExerciseCalculationSource.manualOverride
              : ExerciseCalculationSource.template,
          calculationVersion: MetActivityCatalog.calculationVersion,
          sourceKey: manual ? null : draft.sourceKey,
          notes: draft.notes,
        ),
      );
    }
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

  /// ウィジェットの枠に流し込む食事テンプレートの一覧。検索の計測は残さない。
  Future<List<MealTemplate>> mealTemplatesForWidget() async {
    final repository = _mealTemplateRepository;
    final owner = currentOwnerUserId.trim();
    if (repository == null || owner.isEmpty) {
      return const [];
    }
    final all = await repository.getAll(owner);
    final active = [
      for (final template in all)
        if (template.status == TemplateStatus.active &&
            template.deletedAt == null)
          template,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return active;
  }

  /// ウィジェットの枠に流し込む運動テンプレートの一覧。検索の計測は残さない。
  Future<List<WorkoutTemplate>> workoutTemplatesForWidget() async {
    final repository = _workoutTemplateRepository;
    final owner = currentOwnerUserId.trim();
    if (repository == null || owner.isEmpty) {
      return const [];
    }
    final all = await repository.getAll(owner);
    final active = [
      for (final template in all)
        if (template.status == WorkoutTemplateStatus.active &&
            template.deletedAt == null)
          template,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return active;
  }

  /// 無料は4件まで。カロナビ+は件数の上限なし。編集と復元は止めない。
  Future<bool> canCreateWorkoutTemplate() async {
    final repository = _workoutTemplateRepository;
    if (repository == null) {
      return true;
    }
    final existing = await repository.getAll(currentOwnerUserId);
    return !SubscriptionCatalog.workoutTemplateCreateRequiresPlus(
      savedCount: existing.length,
      isPlus: _subscriptionRepository.isPlusActive,
    );
  }

  /// 無料は4件まで。カロナビ+は件数の上限なし。編集は止めない。
  Future<bool> canCreateMealTemplate() async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return true;
    }
    final existing = await repository.getAll(currentOwnerUserId);
    return !SubscriptionCatalog.mealTemplateCreateRequiresPlus(
      savedCount: existing.length,
      isPlus: _subscriptionRepository.isPlusActive,
    );
  }

  Future<MealTemplate> saveMealTemplate({
    required MealTemplateDraft draft,
    String? templateId,
  }) async {
    _usage('meal_template_saved', {
      'template_id': templateId,
      'action': templateId == null ? 'create' : 'update',
      'items_count': draft.items.length,
    });
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
    if (templateId == null && !await canCreateMealTemplate()) {
      throw SubscriptionLimitExceededException(
        SubscriptionLimitKind.mealTemplate,
      );
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

    await repository.saveWithItems(template: template, items: mappedItems);
    _scheduleRemoteSync();
    unawaited(publishLockScreenMealSnapshot());
    return template;
  }

  Future<void> deleteMealTemplate(String templateId) async {
    _usage('meal_template_deleted', {'template_id': templateId});
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
    unawaited(publishLockScreenMealSnapshot());
  }

  Future<void> restoreMealTemplateBundle(MealTemplateWithItems bundle) async {
    await saveMealTemplate(
      draft: MealTemplateDraft(
        name: bundle.template.name,
        items: bundle.items
            .map(
              (item) => MealTemplateItemDraft(
                itemId: item.itemId,
                savedFoodId: item.savedFoodId,
                sourceOwnerUserId: item.sourceOwnerUserId,
                name: item.name,
                baseAmount: item.baseAmount,
                unitType: item.unitType,
                kcalPerBase: item.kcalPerBase,
                proteinPerBase: item.proteinPerBase,
                fatPerBase: item.fatPerBase,
                carbPerBase: item.carbPerBase,
                consumedAmount: item.consumedAmount,
                sortOrder: item.sortOrder,
              ),
            )
            .toList(),
      ),
      templateId: bundle.template.templateId,
    );
  }

  Future<void> restoreWorkoutTemplateBundle(
    WorkoutTemplateWithItems bundle,
  ) async {
    await saveWorkoutTemplate(
      draft: WorkoutTemplateDraft(
        name: bundle.template.name,
        items: bundle.items,
      ),
      templateId: bundle.template.templateId,
    );
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

  List<MealTemplateItem> resolveMealTemplateItems({
    required List<MealTemplateItem> originalItems,
    required List<MealTemplateItemResolution> resolutions,
  }) {
    return _mealTemplateApplyService.resolveItems(
      originalItems: originalItems,
      resolutions: resolutions,
    );
  }

  Future<LockScreenMealConfig> loadLockScreenMealConfig() async {
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return LockScreenMealConfig.defaults();
    }
    return gateway.loadConfig();
  }

  Future<void> saveLockScreenMealConfig(LockScreenMealConfig config) async {
    final counts = config.homeSlotCounts;
    _usage('widget_config_saved', {
      'surface': 'home',
      'assigned_meal_slots': counts.meal,
      'assigned_exercise_slots': counts.exercise,
    });
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return;
    }
    await gateway.saveConfig(config);
    await publishLockScreenMealSnapshot();
  }

  /// カロナビ+ の購入画面を開く。購入処理はこのブランチでは差し替えない。
  Future<void> Function(BuildContext context)? openCalonaviPlusFlow;

  Future<bool> isMealWidgetPaid() async {
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return false;
    }
    return gateway.isPaid();
  }

  /// ウィジェットと Siri を開いてよいか。
  ///
  /// 開発ビルドのプレビューを含むカロナビ+なら、App Group の有料フラグを
  /// true にしてから通す。リリースで未加入のときは、そのフラグだけを見る。
  Future<bool> ensurePaidShortcutsReady() async {
    if (_subscriptionRepository.isPlusActive) {
      await setLockScreenMealPaid(true);
      return true;
    }
    return isMealWidgetPaid();
  }

  /// ストアの加入をフラグへ写す。設定画面からは呼ばない。
  ///
  /// Health の数値は送らない。書くのは有料かどうかだけ。
  Future<void> refreshPaidEntitlement() async {
    final before = _subscriptionRepository.isPlusActive;
    try {
      await _subscriptionRepository.refreshEntitlement();
    } catch (_) {}
    if (!_subscriptionRepository.reportsEntitlementAnalytics) {
      final active = _subscriptionRepository.isPlusActive;
      final records = _subscriptionRepository.confirmedEntitlements;
      _usage('entitlement_observed', {
        'status': active ? 'active' : 'inactive',
        'product_id': records.isEmpty ? null : records.first.productId,
        'expires_at': records.isEmpty || records.first.expiresAt == null
            ? null
            : records.first.expiresAt!.toUtc().toIso8601String(),
        'original_transaction_id':
            _subscriptionRepository.storeOriginalTransactionId,
        'changed': before != active,
      });
    }
    await _applyPaidEntitlement();
  }

  void _listenForPaidEntitlement() {
    _plusSubscription ??= _subscriptionRepository.plusChanges.listen((_) {
      unawaited(_applyPaidEntitlement());
      notifyListeners();
    });
    _entitlementSyncSubscription ??= _subscriptionRepository.entitlementChanges
        .listen((_) {
          unawaited(_syncPlusEntitlement());
        });
  }

  Future<bool> _syncPlusForAiRetry() async {
    if (!_hasUnexpiredStorePlus()) {
      return false;
    }
    try {
      await _subscriptionRepository.refreshEntitlement();
    } catch (_) {}
    if (!_hasUnexpiredStorePlus()) {
      return false;
    }
    await _syncPlusEntitlement();
    return true;
  }

  bool _hasUnexpiredStorePlus() {
    final now = DateTime.now();
    for (final record in _subscriptionRepository.confirmedEntitlements) {
      final signed = record.signedTransaction?.trim() ?? '';
      final expiry = record.expiresAt;
      if (signed.isNotEmpty &&
          expiry != null &&
          expiry.isAfter(now) &&
          SubscriptionCatalog.isPlusProduct(record.productId)) {
        return true;
      }
    }
    return false;
  }

  /// テストが差し替える。本番の実機テスト用ビルドは Supabase の本人の行を読む。
  @visibleForTesting
  Future<bool> Function(String userId)? serverPlusLookupOverride;

  /// 実機テスト用ビルド（CALONAVI_TEST_PURCHASE）だけ。入れ直し直後に、サーバの
  /// 有料を無料表示で隠さない。審査に出すビルドではこの処理は何もしない。
  Future<void> _adoptServerPlusForTestBuild(String userId) async {
    final repository = _subscriptionRepository;
    if (!repository.testPurchaseToggleEnabled || repository.isPlusActive) {
      return;
    }
    try {
      final lookup = serverPlusLookupOverride ?? _serverHasActivePlus;
      final serverPlus = await lookup(userId);
      repository.adoptServerPlusForTest(serverPlus);
      if (serverPlus) {
        await _applyPaidEntitlement();
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[AYG] server plus lookup failed: $error');
    }
  }

  Future<bool> _serverHasActivePlus(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return false;
    }
    final rows = await Supabase.instance.client
        .from('calonavi_plus_entitlements')
        .select('product_id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> _syncPlusEntitlement() async {
    final usage = _usageRecordRepository;
    if (usage == null || !isAuthenticated) {
      return;
    }
    await usage.syncPlusEntitlements(
      confirmed: _subscriptionRepository.confirmedEntitlements,
      inactive: _subscriptionRepository.inactiveEntitlements,
      authoritative: _subscriptionRepository.entitlementAuthoritative,
    );
  }

  void recordFoodSearch({required String source, required String query}) {
    _recordFoodSearch(source, query);
  }

  void recordExerciseSearch({required String source, required String query}) {
    _recordExerciseSearch(source, query);
  }

  void recordScreenAction({
    required String screen,
    required String action,
    String? fromTab,
  }) {
    if (!screenActionAllowed(screen: screen, action: action)) {
      return;
    }
    final eventId = const Uuid().v4();
    if (action == UsageScreenAction.open) {
      _currentTab ??= screen;
    }
    if (action == UsageScreenAction.select) {
      final previous = fromTab ?? _currentTab ?? screen;
      Analytics.emit(
        'tab_select',
        {'tab': screen, 'from_tab': previous},
        null,
        eventId,
      );
      _currentTab = screen;
    } else if (action != UsageScreenAction.mealButton &&
        action != UsageScreenAction.shareMeal) {
      Analytics.emit(
        'screen_view',
        {'screen': screen, 'via': 'push'},
        null,
        eventId,
      );
    }
    final usage = _usageRecordRepository;
    if (usage == null || usage is NoOpUsageRecordRepository) {
      return;
    }
    unawaited(
      usage.recordScreenAction(
        screen: screen,
        action: action,
        eventId: eventId,
      ),
    );
  }

  void _recordFoodSearch(String source, String query) {
    final usage = _usageRecordRepository;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (!foodSearchSourceAllowed(source)) {
      return;
    }
    final eventId = const Uuid().v4();
    _foodSearchIds[source] = eventId;
    _linkedFoodSearchId = eventId;
    _foodSearchStarted[source] = DateTime.now();
    void emitSearch(String settled, String id) {
      final clipped = settled.length > 256
          ? settled.substring(0, 256)
          : settled;
      final started = _foodSearchStarted[source];
      final latency = started == null
          ? 0
          : DateTime.now().difference(started).inMilliseconds;
      Analytics.emit(
        'food_search',
        {
          'source': source,
          'query': clipped,
          'query_length': settled.length,
          'result_count': _foodSearchCounts[source] ?? 0,
          'latency_ms': latency < 0 ? 0 : latency,
          'search_query_id': id,
        },
        null,
        id,
      );
    }

    if (usage == null || usage is NoOpUsageRecordRepository) {
      emitSearch(trimmed, eventId);
      return;
    }
    unawaited(
      usage.recordFoodSearch(
        source: source,
        query: trimmed,
        eventId: eventId,
        onSettled: emitSearch,
      ),
    );
  }

  void _recordExerciseSearch(String source, String query) {
    final usage = _usageRecordRepository;
    final trimmed = query.trim();
    if (trimmed.isEmpty || !exerciseSearchSourceAllowed(source)) {
      return;
    }
    final eventId = const Uuid().v4();
    _exerciseSearchStarted[source] = DateTime.now();
    void emitSearch(String settled, String id) {
      final clipped = settled.length > 256
          ? settled.substring(0, 256)
          : settled;
      final started = _exerciseSearchStarted[source];
      final latency = started == null
          ? 0
          : DateTime.now().difference(started).inMilliseconds;
      Analytics.emit(
        'exercise_search',
        {
          'source': source,
          'query': clipped,
          'query_length': settled.length,
          'result_count': _exerciseSearchCounts[source] ?? 0,
          'latency_ms': latency < 0 ? 0 : latency,
        },
        null,
        id,
      );
    }

    if (usage == null || usage is NoOpUsageRecordRepository) {
      emitSearch(trimmed, eventId);
      return;
    }
    unawaited(
      usage.recordExerciseSearch(
        source: source,
        query: trimmed,
        eventId: eventId,
        onSettled: emitSearch,
      ),
    );
  }

  Future<void> _applyPaidEntitlement() async {
    await setLockScreenMealPaid(_subscriptionRepository.isPlusActive);
  }

  /// 有料フラグの入口。設定画面のスイッチからは呼ばない。
  ///
  /// true のときだけ、ウィジェットと Siri が登録する。
  Future<void> setLockScreenMealPaid(bool isPaid) async {
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return;
    }
    await gateway.setPaid(isPaid);
    await publishLockScreenMealSnapshot();
  }

  Future<void> syncLockScreenMeals() async {
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return;
    }
    try {
      await _importLockScreenMeals(gateway);
      await publishLockScreenMealSnapshot();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] syncLockScreenMeals failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  SiriOpenSearch? _pendingSiriSearch;

  /// 0件の Siri が残した検索。一度だけ取り出す。
  SiriOpenSearch? takeSiriOpenSearch() {
    final pending = _pendingSiriSearch;
    _pendingSiriSearch = null;
    return pending;
  }

  Future<void> syncSiriVoiceLogs() async {
    final gateway = _siriVoiceGateway;
    if (gateway == null) {
      return;
    }
    try {
      await _importSiriVoiceLogs(gateway);
      final openSearch = SiriOpenSearch.decode(await gateway.readOpenSearch());
      if (openSearch != null) {
        _pendingSiriSearch = openSearch;
        _usage('siri_open_search', {'reason': openSearch.kind});
        await gateway.clearOpenSearch();
        notifyListeners();
      }
      await publishSiriVoiceCatalog();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] syncSiriVoiceLogs failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> publishSiriVoiceCatalog() async {
    final gateway = _siriVoiceGateway;
    if (gateway == null) {
      return;
    }
    final foods = <SiriFoodRecord>[];
    try {
      for (final food in await getOwnSavedFoodSuggestions()) {
        if (food.deletedAt != null) {
          continue;
        }
        foods.add(SiriFoodRecord.saved(food));
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] siri food catalog failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final official = OfficialFoodsFlag.enabled && SupabaseConfig.isConfigured;
    final blockedCreators = official ? await siriBlockedFoodCreatorIds() : null;
    await gateway.publishCatalog(
      SiriVoiceCodec.encodeCatalog(
        ownerUserId: currentOwnerUserId,
        weightKg: profile?.weightKg,
        officialFoodsEnabled: official,
        supabaseUrl: SupabaseConfig.url,
        supabaseAnonKey: SupabaseConfig.anonKey,
        blockedFoodCreatorIds: blockedCreators,
        foods: foods,
        mealTemplates: await _siriMealTemplates(),
        workoutTemplates: await _siriWorkoutTemplates(),
      ),
    );
  }

  /// Siri が公開食品から外す作成者（自分がブロックした人）。
  ///
  /// 読めなかったとき・ログインしていないときは null。そのとき Siri は公開食品を使わない
  /// （ブロックした人の食品を出さない）。ブロックの仕組みが無いときは空。
  @visibleForTesting
  Future<List<String>?> siriBlockedFoodCreatorIds() async {
    final repository = _blockedCreatorRepository;
    final owner = currentOwnerUserId.trim();
    if (repository == null) {
      return const [];
    }
    if (!isAuthenticated || owner.isEmpty) {
      return null;
    }
    try {
      return await repository.getBlockedUserIds(owner);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] siri blocked creators failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Future<List<SiriMealTemplate>> _siriMealTemplates() async {
    final repository = _mealTemplateRepository;
    final owner = currentOwnerUserId.trim();
    if (repository == null || owner.isEmpty) {
      return const [];
    }
    try {
      final templates = <SiriMealTemplate>[];
      for (final template in await repository.getAll(owner)) {
        if (template.deletedAt != null ||
            template.status != TemplateStatus.active) {
          continue;
        }
        final items = await repository.getItems(
          ownerUserId: owner,
          templateId: template.templateId,
        );
        if (items.isEmpty) {
          continue;
        }
        templates.add(
          SiriMealTemplate(
            id: template.templateId,
            speakName: template.name,
            keys: [
              FoodSearchNormalizer.normalize(template.name),
              FoodSearchNormalizer.normalize(template.normalizedName),
            ].where((key) => key.isNotEmpty).toSet().toList(),
            items: [
              for (final item in items)
                if (item.itemDependencyStatus == ItemDependencyStatus.available)
                  SiriTemplateFood(
                    consumedAmount: item.consumedAmount,
                    food: SiriFoodRecord(
                      id: item.itemId,
                      speakName: item.name,
                      keys: [FoodSearchNormalizer.normalize(item.name)],
                      baseAmount: item.baseAmount,
                      unit: item.unitType,
                      source: item.savedFoodId == null
                          ? FoodEntrySource.manual
                          : FoodEntrySource.savedFood,
                      kcalPerBase: item.kcalPerBase,
                      proteinPerBase: item.proteinPerBase,
                      fatPerBase: item.fatPerBase,
                      carbPerBase: item.carbPerBase,
                      savedFoodId: item.savedFoodId,
                      sourceOwnerUserId: item.sourceOwnerUserId,
                    ),
                  ),
            ],
          ),
        );
      }
      return templates.where((template) => template.items.isNotEmpty).toList();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] siri meal templates failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return const [];
    }
  }

  Future<List<SiriWorkoutTemplate>> _siriWorkoutTemplates() async {
    final repository = _workoutTemplateRepository;
    final owner = currentOwnerUserId.trim();
    if (repository == null || owner.isEmpty) {
      return const [];
    }
    try {
      final templates = <SiriWorkoutTemplate>[];
      for (final template in await repository.getAll(owner)) {
        if (template.deletedAt != null ||
            template.status != WorkoutTemplateStatus.active) {
          continue;
        }
        final items = await repository.getItems(
          ownerUserId: owner,
          templateId: template.templateId,
        );
        final exercises = <SiriWorkoutTemplateExercise>[];
        for (final item in items) {
          final activityId = item.activityId;
          if (activityId == null || activityId.trim().isEmpty) {
            continue;
          }
          if (item.durationMin <= 0) {
            continue;
          }
          exercises.add(
            SiriWorkoutTemplateExercise(
              activityId: activityId,
              minutes: item.durationMin.toDouble(),
              intensityId: item.intensity,
            ),
          );
        }
        if (exercises.isEmpty) {
          continue;
        }
        templates.add(
          SiriWorkoutTemplate(
            id: template.templateId,
            speakName: template.name,
            keys: [
              FoodSearchNormalizer.normalize(template.name),
              FoodSearchNormalizer.normalize(template.normalizedName),
            ].where((key) => key.isNotEmpty).toSet().toList(),
            exercises: exercises,
          ),
        );
      }
      return templates;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AYG] siri workout templates failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return const [];
    }
  }

  Future<void> _importSiriVoiceLogs(SiriVoiceGateway gateway) async {
    final plan = SiriVoiceCodec.decodePending(
      raw: await gateway.readPending(),
      ownerUserId: currentOwnerUserId,
      existingFoodIds: foodEntries.map((entry) => entry.id).toSet(),
      existingExerciseIds: exerciseEntries.map((entry) => entry.id).toSet(),
    );
    for (final id in plan.undoIds) {
      if (foodEntries.any((entry) => entry.id == id)) {
        await deleteFood(id);
      }
      if (exerciseEntries.any((entry) => entry.id == id)) {
        await deleteExercise(id);
      }
    }
    if (plan.foods.isNotEmpty) {
      await addFoodEntriesBatch(plan.foods, origin: ReviewRecordOrigin.siri);
    }
    for (final exercise in plan.exercises) {
      await addExercise(exercise, origin: ReviewRecordOrigin.siri);
    }
    final siriLogged = [
      ...plan.foods.map((entry) => entry.loggedAt),
      ...plan.exercises.map((entry) => entry.loggedAt),
    ];
    _usage('siri_registration_imported', {
      'undo': plan.undoIds.isNotEmpty,
      'delay_seconds': _delaySeconds(
        siriLogged.isEmpty
            ? DateTime.now()
            : siriLogged.reduce((a, b) => a.isBefore(b) ? a : b),
      ),
      'food_entry_ids': [for (final entry in plan.foods) entry.id],
      'exercise_entry_ids': [for (final entry in plan.exercises) entry.id],
      if (plan.acknowledgeIds.isNotEmpty)
        'registration_id': plan.acknowledgeIds.first,
    });
    await gateway.acknowledge(plan.acknowledgeIds);
  }

  Future<void> publishLockScreenMealSnapshot() async {
    final gateway = _lockScreenMealGateway;
    if (gateway == null) {
      return;
    }
    final config = await gateway.loadConfig();
    await gateway.publishSnapshot(
      LockScreenMealSnapshot(
        ownerUserId: currentOwnerUserId,
        homeButtons: _widgetButtons(config.homeButtons),
        lockButtons: _widgetButtons(config.lockButtons),
        figures: _mealWidgetFigures(),
      ),
    );
  }

  /// [summary] を計算した日。ウィジェットの数字にその日付を付ける。
  DateTime? _summaryDay;

  MealWidgetFigures _mealWidgetFigures() {
    final current = summary;
    if (current == null) {
      return const MealWidgetFigures();
    }
    final summaryDay = _summaryDay;
    final remaining = current.remainingKcal;
    return MealWidgetFigures(
      remainingKcal: remaining < 0 ? 0 : remaining.round(),
      intakeKcal: current.intakeKcal.round(),
      burnKcal: current.exerciseBurnKcal.round(),
      targetKcal: current.targetKcal.round(),
      overageKcal: current.isCalorieOverage
          ? current.calorieOverageKcal.round()
          : null,
      day: summaryDay == null ? null : mealWidgetDayKey(summaryDay),
    );
  }

  List<LockScreenMealButtonSnapshot> _widgetButtons(
    List<LockScreenMealButtonConfig> buttons,
  ) {
    return [
      for (final button in buttons)
        LockScreenMealButtonSnapshot(
          slot: button.slot,
          label: button.label,
          kind: button.kind,
          templateId: button.hasContent
              ? 'widget-${button.kind.name}-${button.slot}'
              : null,
          templateName: _widgetPatternName(button),
          items: button.kind == WidgetPatternKind.meal
              ? button.items
              : const [],
          exercises: button.kind == WidgetPatternKind.exercise
              ? [for (final item in button.exercises) _withWidgetNetKcal(item)]
              : const [],
        ),
    ];
  }

  WidgetExercisePattern _withWidgetNetKcal(WidgetExercisePattern item) {
    final entry = widgetExerciseEntry(
      pattern: item,
      weightKg: profile?.weightKg,
      id: 'widget-kcal',
      loggedAt: DateTime.now(),
    );
    return item.copyWith(netKcal: entry?.netKcal ?? 0);
  }

  String? _widgetPatternName(LockScreenMealButtonConfig button) {
    final name = button.contentName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final label = button.label.trim();
    if (label.isEmpty) {
      return null;
    }
    return label;
  }

  Future<void> _importLockScreenMeals(LockScreenMealGateway gateway) async {
    final pending = await gateway.readPending();
    if (pending.isEmpty) {
      return;
    }
    final plan = planLockScreenMealImport(
      pending: pending,
      ownerUserId: currentOwnerUserId,
      existingEntryIds: foodEntries.map((entry) => entry.id).toSet(),
    );
    if (plan.entries.isNotEmpty) {
      await addFoodEntriesBatch(
        plan.entries,
        origin: ReviewRecordOrigin.widget,
      );
      await _countLockScreenTemplateUses(plan.templateIds);
    }
    final acknowledged = plan.acknowledgeIds.toSet();
    final weight = currentWeightSelection.kg;
    final weightKg = weight > 0 ? weight : null;
    final existingExerciseIds = exerciseEntries
        .map((entry) => entry.id)
        .toSet();
    for (final record in plan.exerciseRecords) {
      var waiting = false;
      for (final pattern in record.exercises) {
        if (existingExerciseIds.contains(pattern.itemId)) {
          continue;
        }
        final entry = widgetExerciseEntry(
          pattern: pattern,
          weightKg: weightKg,
          id: pattern.itemId,
          loggedAt: record.loggedAt,
        );
        final analyticsOrigin = record.surface == 'lock'
            ? 'lock_widget'
            : 'home_widget';
        if (entry == null) {
          final pendingEntry = widgetExercisePendingWeight(
            pattern: pattern,
            id: pattern.itemId,
            loggedAt: record.loggedAt,
          );
          if (pendingEntry != null &&
              widgetExerciseWaitsForWeight(pattern, weightKg)) {
            await addExercise(
              pendingEntry,
              origin: ReviewRecordOrigin.widget,
              analyticsOrigin: analyticsOrigin,
            );
            existingExerciseIds.add(pendingEntry.id);
          } else if (widgetExerciseWaitsForWeight(pattern, weightKg)) {
            waiting = true;
          }
          continue;
        }
        await addExercise(
          entry,
          origin: ReviewRecordOrigin.widget,
          analyticsOrigin: analyticsOrigin,
        );
        existingExerciseIds.add(entry.id);
      }
      if (!waiting) {
        acknowledged.add(record.registrationId);
      }
    }
    for (final meal in pending) {
      if (!acknowledged.contains(meal.registrationId)) {
        continue;
      }
      final action = widgetSurfaceAction(meal.surface);
      if (action == null) {
        continue;
      }
      _usage('widget_registration_imported', {
        'registration_id': meal.registrationId,
        'food_entry_ids': [for (final entry in meal.entries) entry.id],
        'exercise_entry_ids': [for (final item in meal.exercises) item.itemId],
        'delay_seconds': _delaySeconds(meal.loggedAt),
      });
      recordScreenAction(screen: action.screen, action: action.action);
    }
    await gateway.acknowledge(acknowledged.toList());
  }

  int _delaySeconds(DateTime loggedAt) {
    final seconds = DateTime.now().difference(loggedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> _fillWidgetExercisesWaitingForWeight() async {
    final weight = currentWeightSelection.kg;
    if (weight <= 0) {
      return;
    }
    final waiting = exerciseEntries
        .where((entry) => entry.sourceKey == widgetWeightPendingSourceKey)
        .toList();
    if (waiting.isEmpty) {
      return;
    }
    for (final entry in waiting) {
      final activityId = entry.activityId;
      if (activityId == null || activityId.isEmpty) {
        continue;
      }
      final filled = widgetExerciseEntry(
        pattern: WidgetExercisePattern(
          itemId: entry.id,
          activityId: activityId,
          name: entry.name,
          sortOrder: 0,
          durationMin: entry.durationMin,
          distanceKm: entry.distanceKm,
        ),
        weightKg: weight,
        id: entry.id,
        loggedAt: entry.loggedAt,
      );
      if (filled == null) {
        continue;
      }
      await _saveExerciseEntryLocally(
        filled.copyWith(
          recordOrigin: entry.recordOrigin ?? ReviewRecordOrigin.widget.name,
        ),
      );
      await _pendingRecords.markUpsert(PendingRecordKind.exercise, entry.id);
    }
    refreshDailySummary();
    _scheduleRemoteSync();
  }

  Future<void> _countLockScreenTemplateUses(List<String> templateIds) async {
    final repository = _mealTemplateRepository;
    if (repository == null) {
      return;
    }
    for (final templateId in templateIds) {
      if (templateId.startsWith('widget-')) {
        continue;
      }
      final bundle = await getMealTemplateWithItems(templateId);
      if (bundle == null) {
        continue;
      }
      final now = DateTime.now();
      await repository.update(
        bundle.template.copyWith(
          useCount: bundle.template.useCount + 1,
          lastUsedAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<MealTemplateApplyResult> applyMealTemplate({
    required String templateId,
    List<MealTemplateItemResolution> resolutions = const [],
    String? memo,
  }) async {
    _usage('meal_template_applied', {
      'template_id': templateId,
      'items_count': resolutions.length,
    });
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
      memo: storedFoodMemo(memo),
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
        errorMessage: userErrorMessage(error, action: 'テンプレートの適用'),
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

  Future<void> addMealEntryFromSavedFoodMaster({
    required SavedFood food,
    required double consumedQuantity,
    required DateTime loggedAt,
  }) async {
    if (!food.baseServingDefined) {
      throw StateError('Saved food serving spec is not defined.');
    }
    if (consumedQuantity <= 0) {
      throw StateError('Consumed quantity must be positive.');
    }

    final entry = _savedFoodEntryBuilder.buildFromSavedFood(
      food: food,
      entryId: generateId(),
      consumedAmount: consumedQuantity,
      loggedAt: loggedAt,
    );
    await addFood(entry);

    if (food.ownerUserId == currentOwnerUserId) {
      await _recordSavedFoodUsage(food.foodId);
    }
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
        savedFoodErrorMessage: userErrorMessage(error, action: '保存'),
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
      SavedFoodErrorCode? errorCode;
      String? message;
      if (error is SavedFoodPersistenceException) {
        error.logDebug();
        errorCode = error.errorCode;
        message = error.userMessage;
      } else {
        message = userErrorMessage(error, action: 'マイ食品の保存');
        if (kDebugMode) {
          debugPrint(
            '[AYG SavedFood] saveFoodEntryWithOptionalSavedFood: $error',
          );
        }
      }
      return SaveFoodEntryResult(
        foodEntrySaved: true,
        entry: entryToSave,
        savedFoodSaved: false,
        savedFoodErrorMessage: message,
        savedFoodErrorCode: errorCode ?? SavedFoodErrorCode.insertFailed,
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
          unitType: FoodUnitTypeX.inferFromUnitLabel(
            resolution.draft.servingUnitLabel,
          ),
          servingUnitLabel: resolution.draft.servingUnitLabel.trim(),
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
          servingUnitLabel: resolution.draft.servingUnitLabel,
          unitType: FoodUnitTypeX.inferFromUnitLabel(
            resolution.draft.servingUnitLabel,
          ),
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

  Future<void> _ensureAuthenticatedUserProfile() async {
    final authUser = _authenticationRepository?.currentUser;
    final dataSyncRepository = _dataSyncRepository;
    if (authUser == null) {
      final error = SavedFoodPersistenceException(
        errorCode: SavedFoodErrorCode.authRequired,
        message: 'Authentication required.',
        repositoryStep: 'AppController._ensureAuthenticatedUserProfile',
        operation: 'validate',
      )..logDebug();
      throw error;
    }
    if (dataSyncRepository == null) {
      final error = SavedFoodPersistenceException(
        errorCode: SavedFoodErrorCode.networkFailed,
        message: 'Remote sync is not configured.',
        repositoryStep: 'AppController._ensureAuthenticatedUserProfile',
        operation: 'validate',
      )..logDebug();
      throw error;
    }

    try {
      await dataSyncRepository.ensureUserProfile(
        userId: authUser.id,
        email: authUser.email,
      );
    } catch (error) {
      if (error is SyncStepException) {
        final mapped = SavedFoodPersistenceException(
          errorCode: SavedFoodErrorCode.userProfileRequired,
          message: error.failure.message,
          repositoryStep: 'AppController._ensureAuthenticatedUserProfile',
          operation: 'ensureUserProfile',
          postgresCode: error.failure.postgresCode,
          details: error.failure.details,
          hint: error.failure.hint,
          cause: error,
        )..logDebug();
        throw mapped;
      }
      final mapped = SavedFoodPersistenceException.ensureUserProfileFailed(
        error,
      )..logDebug();
      throw mapped;
    }
  }

  Future<void> refreshSavedFoodsFromRemote() async {
    final authUser = _authenticationRepository?.currentUser;
    final dataSyncRepository = _dataSyncRepository;
    if (authUser == null || dataSyncRepository == null) {
      return;
    }

    await dataSyncRepository.pullSavedFoodsRemoteToLocal(authUser.id);
    notifyListeners();
  }

  Future<void> _persistToRemoteNow() async {
    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (userId == null || dataSyncRepository == null) {
      throw StateError('Cannot persist without authenticated remote sync.');
    }

    try {
      await _serialRemoteWrite(
        () => dataSyncRepository.pushLocalToRemote(userId),
      );
      _hasUnsentRecords = false;
    } on PartialPushException catch (error, stackTrace) {
      _hasUnsentRecords = true;
      debugPrint('[AYG] persist incomplete: $error');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
      rethrow;
    }
    _hasInitialSyncCompleted = true;
    _lastSyncFailed = false;
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

  Future<void> _migrateLocalOwnerData({required String toUserId}) async {
    final mealTemplateRepository = _mealTemplateRepository;
    if (mealTemplateRepository != null) {
      await mealTemplateRepository.reassignOwnerUserId(
        fromOwnerUserId: localOwnerUserId,
        toOwnerUserId: toUserId,
      );
    }

    final workoutTemplateRepository = _workoutTemplateRepository;
    if (workoutTemplateRepository != null) {
      await workoutTemplateRepository.reassignOwnerUserId(
        fromOwnerUserId: localOwnerUserId,
        toOwnerUserId: toUserId,
      );
    }
  }

  bool _remoteSyncInFlight = false;
  bool _remoteSyncQueued = false;

  /// 端末からサーバへの書き込み（送信と削除）を1本ずつ順に流す。
  ///
  /// 送信は端末の全件を読んでから送るので、その途中で削除が割り込むと、
  /// 読んだ時点の行（消した記録）が削除のあとにサーバへ書き戻される。
  /// 削除は送信の後ろに並べ、削除の途中で次の送信が端末を読まないようにする。
  Future<void> _remoteWriteTail = Future<void>.value();
  int _remoteWritesPending = 0;

  Future<T> _serialRemoteWrite<T>(Future<T> Function() action) {
    final previous = _remoteWriteTail;
    final idle = _remoteWritesPending == 0;
    _remoteWritesPending++;
    final done = Completer<void>();
    _remoteWriteTail = done.future;
    void finish() {
      _remoteWritesPending--;
      done.complete();
    }

    // 何も流れていなければ、その場で始める（待ち時間を足さない）。
    final run = idle ? Future<T>.sync(action) : previous.then((_) => action());
    return run.then(
      (value) {
        finish();
        return value;
      },
      onError: (Object error, StackTrace stackTrace) {
        finish();
        return Future<T>.error(error, stackTrace);
      },
    );
  }

  void _scheduleRemoteSync() {
    if (!_hasInitialSyncCompleted || _lastSyncFailed) {
      return;
    }

    final userId = _authenticationRepository?.currentUser?.id;
    final dataSyncRepository = _dataSyncRepository;
    if (userId == null || dataSyncRepository == null) {
      return;
    }

    if (_remoteSyncInFlight) {
      _remoteSyncQueued = true;
      return;
    }
    _remoteSyncInFlight = true;
    unawaited(_drainRemoteSync(dataSyncRepository, userId));
  }

  Future<void> _drainRemoteSync(
    DataSyncRepository dataSyncRepository,
    String userId,
  ) async {
    try {
      do {
        _remoteSyncQueued = false;
        try {
          await _serialRemoteWrite(
            () => dataSyncRepository.pushLocalToRemote(userId),
          );
          _hasUnsentRecords = false;
        } on PartialPushException catch (error, stackTrace) {
          _hasUnsentRecords = true;
          debugPrint('[AYG] remote sync incomplete: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      } while (_remoteSyncQueued &&
          _hasInitialSyncCompleted &&
          !_lastSyncFailed);
    } catch (error, stackTrace) {
      _hasUnsentRecords = true;
      debugPrint('[AYG] remote sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _remoteSyncInFlight = false;
      notifyListeners();
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _plusSubscription?.cancel();
    _entitlementSyncSubscription?.cancel();
    reviewPromptTick.dispose();
    super.dispose();
  }
}

enum WeightDataSource { manual, health, healthPending }
