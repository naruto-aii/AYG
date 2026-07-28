import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/repositories/sync_step_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';

void main() {
  test('runOptionalSyncStep skips missing table', () async {
    var called = false;
    final result = await runOptionalSyncStep<int>(
      step: SyncStep.fetchSavedFoods,
      repository: 'test',
      tableName: 'saved_foods',
      operation: 'select',
      action: () async {
        called = true;
        throw const PostgrestException(
          message: 'relation "saved_foods" does not exist',
          code: '42P01',
        );
        return 1;
      },
    );

    expect(called, isTrue);
    expect(result, isNull);
  });

  test('runOptionalSyncStep rethrows non-missing errors', () async {
    expect(
      () => runOptionalSyncStep<void>(
        step: SyncStep.fetchSavedFoods,
        repository: 'test',
        tableName: 'saved_foods',
        operation: 'select',
        action: () async {
          throw const PostgrestException(
            message: 'permission denied',
            code: '42501',
          );
        },
      ),
      throwsA(isA<SyncStepException>()),
    );
  });
}
