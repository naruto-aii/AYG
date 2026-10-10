import 'dart:async';

import 'package:ayg/models/sync_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';

void main() {
  test('maps table missing to step-specific code', () {
    final failure = SyncFailure.from(
      step: SyncStep.fetchMealTemplates,
      error: const PostgrestException(
        message: 'relation "meal_templates" does not exist',
        code: '42P01',
      ),
      repository: 'SupabaseDataSyncRepository',
      tableName: 'meal_templates',
      operation: 'select',
    );

    expect(failure.errorCode, 'FETCH_MEAL_TEMPLATES_TABLE_MISSING');
    expect(failure.userMessage, 'データを読み込めませんでした');
  });

  test('a timed out sync tells the user the connection failed', () {
    final failure = SyncFailure.from(
      step: SyncStep.applyRemoteData,
      error: TimeoutException('initial sync budget'),
      repository: 'AppController',
      tableName: 'local_cache',
      operation: 'sync',
    );

    expect(failure.userMessage, '通信に失敗しました');
    expect(failure.userMessage, isNot(contains('TimeoutException')));
  });

  test('copy text excludes secrets', () {
    final failure = SyncFailure.from(
      step: SyncStep.fetchSavedFoods,
      error: StateError('failed'),
      repository: 'SupabaseDataSyncRepository',
      tableName: 'saved_foods',
      operation: 'select',
    );

    expect(failure.copyText, contains('failed_step=FETCH_SAVED_FOODS'));
    expect(failure.copyText, isNot(contains('token')));
  });
}
