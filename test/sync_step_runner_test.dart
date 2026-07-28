import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/supabase/supabase_error_mapper.dart';
import 'package:ayg/repositories/sync_step_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';

void main() {
  test('runOptionalSyncStep skips raw PostgrestException', () async {
    final result = await runOptionalSyncStep<int>(
      step: SyncStep.fetchSavedFoods,
      repository: 'test',
      tableName: 'saved_foods',
      operation: 'select',
      action: () async {
        throw const PostgrestException(
          message: 'relation "saved_foods" does not exist',
          code: '42P01',
        );
      },
    );

    expect(result, isNull);
  });

  test(
    'runOptionalSyncStep skips SupabaseErrorMapper wrapped missing table',
    () async {
      final result = await runOptionalSyncStep<int>(
        step: SyncStep.fetchSavedFoods,
        repository: 'SupabaseSavedFoodRepository',
        tableName: 'saved_foods',
        operation: 'select',
        action: () async {
          throw SupabaseErrorMapper.map(
            const PostgrestException(
              message: 'relation "saved_foods" does not exist',
              code: '42P01',
            ),
            context: 'saved_foods pull',
          );
        },
      );

      expect(result, isNull);
    },
  );

  test('SyncFailure maps wrapped table missing to TABLE_MISSING code', () {
    final failure = SyncFailure.from(
      step: SyncStep.fetchSavedFoods,
      error: const FoodMasterTableMissingException(
        postgresCode: '42P01',
        message: 'relation "saved_foods" does not exist',
        tableName: 'saved_foods',
      ),
      repository: 'SupabaseSavedFoodRepository',
      tableName: 'saved_foods',
      operation: 'select',
    );

    expect(failure.errorCode, 'FETCH_SAVED_FOODS_TABLE_MISSING');
    expect(failure.postgresCode, '42P01');
    expect(isOptionalTableMissing(failure), isTrue);
  });

  test('runOptionalSyncStep rethrows permission errors', () async {
    expect(
      () => runOptionalSyncStep<void>(
        step: SyncStep.fetchSavedFoods,
        repository: 'test',
        tableName: 'saved_foods',
        operation: 'select',
        action: () async {
          throw SupabaseErrorMapper.map(
            const PostgrestException(
              message: 'permission denied for table saved_foods',
              code: '42501',
            ),
            context: 'saved_foods pull',
          );
        },
      ),
      throwsA(isA<SyncStepException>()),
    );
  });
}
