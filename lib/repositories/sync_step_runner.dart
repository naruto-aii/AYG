import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';

import '../models/sync_failure.dart';

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
  final code = failure.postgresCode;
  return code == '42P01' || code == 'PGRST205';
}

bool isOptionalTableMissingError(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    return code == '42P01' || code == 'PGRST205';
  }
  if (error is SyncStepException) {
    return isOptionalTableMissing(error.failure);
  }
  return false;
}
