import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/exceptions/food_master_exceptions.dart';

/// 食品保存失敗のユーザー向けエラーコード。
enum SavedFoodErrorCode {
  authRequired('SAVED_FOOD_AUTH_REQUIRED'),
  userProfileRequired('SAVED_FOOD_USER_PROFILE_REQUIRED'),
  permissionDenied('SAVED_FOOD_PERMISSION_DENIED'),
  validationFailed('SAVED_FOOD_VALIDATION_FAILED'),
  networkFailed('SAVED_FOOD_NETWORK_FAILED'),
  conflict('SAVED_FOOD_CONFLICT'),
  tableMissing('SAVED_FOOD_TABLE_MISSING'),
  insertFailed('SAVED_FOOD_INSERT_FAILED');

  const SavedFoodErrorCode(this.code);

  final String code;
}

/// saved_foods 永続化失敗。PostgREST / Postgres 情報を安全に保持する。
class SavedFoodPersistenceException implements Exception {
  SavedFoodPersistenceException({
    required this.errorCode,
    required this.message,
    this.repositoryStep,
    this.tableName,
    this.operation,
    this.postgresCode,
    this.details,
    this.hint,
    this.cause,
  });

  final SavedFoodErrorCode errorCode;
  final String message;
  final String? repositoryStep;
  final String? tableName;
  final String? operation;
  final String? postgresCode;
  final String? details;
  final String? hint;
  final Object? cause;

  @override
  String toString() => message;

  void logDebug() {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[AYG SavedFood] step=${repositoryStep ?? '-'} '
      'repo=${tableName ?? 'saved_foods'} op=${operation ?? '-'} '
      'code=$postgresCode '
      'errorCode=${errorCode.code} message=$message '
      'details=$details hint=$hint',
    );
    if (cause != null) {
      debugPrint('[AYG SavedFood] cause=$cause');
    }
  }

  static SavedFoodPersistenceException fromPostgrest({
    required PostgrestException error,
    required String repositoryStep,
    required String operation,
    String tableName = 'saved_foods',
  }) {
    final combined =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();

    SavedFoodErrorCode errorCode;
    if (combined.contains('jwt') ||
        combined.contains('not authenticated') ||
        error.code == 'PGRST301') {
      errorCode = SavedFoodErrorCode.authRequired;
    } else if (error.code == '23503' ||
        combined.contains('foreign key') ||
        combined.contains('violates foreign key')) {
      errorCode = SavedFoodErrorCode.userProfileRequired;
    } else if (error.code == '42501' ||
        combined.contains('permission denied') ||
        combined.contains('row-level security')) {
      errorCode = SavedFoodErrorCode.permissionDenied;
    } else if (error.code == '23505' || combined.contains('duplicate')) {
      errorCode = SavedFoodErrorCode.conflict;
    } else if (error.code == '42P01' ||
        error.code == 'PGRST205' ||
        combined.contains('does not exist')) {
      errorCode = SavedFoodErrorCode.tableMissing;
    } else if (error.code == '23514' ||
        combined.contains('check constraint') ||
        combined.contains('base_amount') ||
        combined.contains('unit_type') ||
        combined.contains('invalid')) {
      errorCode = SavedFoodErrorCode.validationFailed;
    } else {
      errorCode = SavedFoodErrorCode.insertFailed;
    }

    return SavedFoodPersistenceException(
      errorCode: errorCode,
      message: error.message,
      repositoryStep: repositoryStep,
      tableName: tableName,
      operation: operation,
      postgresCode: error.code,
      details: error.details?.toString(),
      hint: error.hint?.toString(),
      cause: error,
    );
  }

  static SavedFoodPersistenceException fromFoodMaster({
    required FoodMasterException error,
    required String repositoryStep,
    required String operation,
  }) {
    final errorCode = switch (error) {
      FoodMasterAuthenticationException() => SavedFoodErrorCode.authRequired,
      FoodMasterPermissionException() => SavedFoodErrorCode.permissionDenied,
      FoodMasterValidationException() => SavedFoodErrorCode.validationFailed,
      FoodMasterConflictException() => SavedFoodErrorCode.conflict,
      FoodMasterTableMissingException() => SavedFoodErrorCode.tableMissing,
      FoodMasterNetworkException() => SavedFoodErrorCode.networkFailed,
      _ => SavedFoodErrorCode.insertFailed,
    };

    return SavedFoodPersistenceException(
      errorCode: errorCode,
      message: error.message,
      repositoryStep: repositoryStep,
      tableName: 'saved_foods',
      operation: operation,
      cause: error,
    );
  }

  static SavedFoodPersistenceException ensureUserProfileFailed(Object error) {
    if (error is PostgrestException) {
      return fromPostgrest(
        error: error,
        repositoryStep: 'SupabaseDataSyncRepository.ensureUserProfile',
        operation: 'insert/select',
        tableName: 'users',
      );
    }
    if (error is FoodMasterException) {
      return fromFoodMaster(
        error: error,
        repositoryStep: 'SupabaseDataSyncRepository.ensureUserProfile',
        operation: 'insert/select',
      );
    }
    return SavedFoodPersistenceException(
      errorCode: SavedFoodErrorCode.userProfileRequired,
      message: 'User profile could not be ensured.',
      repositoryStep: 'SupabaseDataSyncRepository.ensureUserProfile',
      tableName: 'users',
      operation: 'insert/select',
      cause: error,
    );
  }
}
