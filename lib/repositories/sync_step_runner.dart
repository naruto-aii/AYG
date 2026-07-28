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
