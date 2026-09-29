import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sync_failure.dart';
import '../repositories/exceptions/food_master_exceptions.dart';

Future<T> runSyncStep<T>({
  required SyncStep step,
  required String repository,
  required String tableName,
  required String operation,
  required Future<T> Function() action,
}) async {
  try {
    return await action();
  } catch (error) {
    final failure = SyncFailure.from(
      step: step,
      error: error,
      repository: repository,
      tableName: tableName,
      operation: operation,
    )..logDebug();
    throw SyncStepException(failure);
  }
}

/// v1.1 テーブル未デプロイ時は同期失敗にせずスキップする。
Future<T?> runOptionalSyncStep<T>({
  required SyncStep step,
  required String repository,
  required String tableName,
  required String operation,
  required Future<T> Function() action,
}) async {
  try {
    return await runSyncStep(
      step: step,
      repository: repository,
      tableName: tableName,
      operation: operation,
      action: action,
    );
  } on SyncStepException catch (error) {
    if (isOptionalTableMissing(error.failure)) {
      if (kDebugMode) {
        debugPrint(
          '[AYG Sync] optional step skipped: ${step.code} '
          'table=$tableName',
        );
      }
      return null;
    }
    rethrow;
  }
}

bool isOptionalTableMissing(SyncFailure failure) {
  if (failure.errorCode.endsWith('_TABLE_MISSING')) {
    return true;
  }
  if (isOptionalTableMissingError(failure.cause ?? failure)) {
    return true;
  }
  final code = failure.postgresCode;
  return code == '42P01' || code == 'PGRST205';
}

bool isOptionalTableMissingError(Object error) {
  if (error is FoodMasterTableMissingException) {
    return true;
  }
  if (error is PostgrestException) {
    final code = error.code;
    return code == '42P01' || code == 'PGRST205';
  }
  if (error is SyncStepException) {
    return isOptionalTableMissing(error.failure);
  }
  if (error is FoodMasterException) {
    final message = error.message.toLowerCase();
    if (message.contains('does not exist') && message.contains('relation')) {
      return true;
    }
  }
  return false;
}
