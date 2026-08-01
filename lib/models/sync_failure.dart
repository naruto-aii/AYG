import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/exceptions/food_master_exceptions.dart';

/// 初期同期の各ステップ。
enum SyncStep {
  authRestore('AUTH_RESTORE'),
  ensureUserProfile('ENSURE_USER_PROFILE'),
  fetchUserProfile('FETCH_USER_PROFILE'),
  fetchGoal('FETCH_GOAL'),
  fetchNutritionSettings('FETCH_NUTRITION_SETTINGS'),
  fetchHealthSnapshot('FETCH_HEALTH_SNAPSHOT'),
  fetchAppSettings('FETCH_APP_SETTINGS'),
  fetchFoodEntries('FETCH_FOOD_ENTRIES'),
  deleteFoodEntry('DELETE_FOOD_ENTRY'),
  fetchExerciseEntries('FETCH_EXERCISE_ENTRIES'),
  fetchWeightEntries('FETCH_WEIGHT_ENTRIES'),
  fetchSavedFoods('FETCH_SAVED_FOODS'),
  fetchMealTemplates('FETCH_MEAL_TEMPLATES'),
  applyRemoteData('APPLY_REMOTE_DATA');

  const SyncStep(this.code);

  final String code;

  String get failedCode => '${code}_FAILED';
}

/// 同期失敗の安全な表示情報。
class SyncFailure {
  SyncFailure({
    required this.step,
    required this.errorCode,
    required this.message,
    required this.userMessage,
    this.postgresCode,
    this.details,
    this.hint,
    this.repository,
    this.tableName,
    this.operation,
    this.cause,
  });

  final SyncStep step;
  final String errorCode;
  final String message;
  final String userMessage;
  final String? postgresCode;
  final String? details;
  final String? hint;
  final String? repository;
  final String? tableName;
  final String? operation;
  final Object? cause;

  String get copyText {
    return [
      'error_code=$errorCode',
      'failed_step=${step.code}',
      'postgres_code=${postgresCode ?? '-'}',
      'repository=${repository ?? '-'}',
      'table=${tableName ?? '-'}',
      'operation=${operation ?? '-'}',
      'cause_type=${cause?.runtimeType ?? '-'}',
      'timestamp=${DateTime.now().toUtc().toIso8601String()}',
    ].join('\n');
  }

  void logDebug() {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[AYG Sync] step=${step.code} code=$errorCode '
      'postgres=$postgresCode repo=$repository table=$tableName '
      'op=$operation message=$message details=$details hint=$hint',
    );
    if (cause != null) {
      debugPrint('[AYG Sync] cause=$cause');
    }
  }

  static SyncFailure from({
    required SyncStep step,
    required Object error,
    String? repository,
    String? tableName,
    String? operation,
  }) {
    if (error is SyncFailure) {
      return error;
    }

    String? postgresCode;
    String? details;
    String? hint;
    String message = error.toString();
    String userMessage = 'データを読み込めませんでした';
    String errorCode = step.failedCode;

    if (error is PostgrestException) {
      postgresCode = error.code;
      details = error.details?.toString();
      hint = error.hint?.toString();
      message = error.message;
      errorCode = _errorCodeForPostgrest(step, error);
      userMessage = _userMessageForPostgrest(error);
    } else if (error is FoodMasterTableMissingException) {
      postgresCode = error.postgresCode;
      message = error.message;
      errorCode = '${step.code}_TABLE_MISSING';
      userMessage = 'データを読み込めませんでした';
    } else if (error is AuthException) {
      errorCode = 'AUTH_SESSION_INVALID';
      userMessage = 'ログイン状態を確認できませんでした';
      message = error.message;
    } else if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('ClientException')) {
      userMessage = '通信に失敗しました';
    } else if (error is FormatException || error is TypeError) {
      errorCode = '${step.code}_PARSE_FAILED';
      userMessage = 'データを読み込めませんでした';
    }

    return SyncFailure(
      step: step,
      errorCode: errorCode,
      message: message,
      userMessage: userMessage,
      postgresCode: postgresCode,
      details: details,
      hint: hint,
      repository: repository,
      tableName: tableName,
      operation: operation,
      cause: error,
    );
  }

  static String _errorCodeForPostgrest(
    SyncStep step,
    PostgrestException error,
  ) {
    final code = error.code;
    if (code == '42501') {
      return '${step.code}_FORBIDDEN';
    }
    if (code == 'PGRST116') {
      return '${step.code}_NOT_FOUND';
    }
    if (code == 'PGRST205' || code == '42P01') {
      return '${step.code}_TABLE_MISSING';
    }
    return step.failedCode;
  }

  static String _userMessageForPostgrest(PostgrestException error) {
    final combined =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (combined.contains('jwt') || combined.contains('not authenticated')) {
      return 'ログイン状態を確認できませんでした';
    }
    if (error.code == '42501' ||
        combined.contains('permission denied') ||
        combined.contains('row-level security')) {
      return 'データを読み込めませんでした';
    }
    if (combined.contains('socket') ||
        combined.contains('network') ||
        combined.contains('failed host lookup')) {
      return '通信に失敗しました';
    }
    return 'データを読み込めませんでした';
  }
}

class SyncStepException implements Exception {
  SyncStepException(this.failure);

  final SyncFailure failure;

  @override
  String toString() => failure.message;
}
