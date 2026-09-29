import 'package:ayg/models/saved_food_persistence_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';

void main() {
  group('SavedFoodPersistenceException', () {
    test('maps foreign key violation to userProfileRequired', () {
      final mapped = SavedFoodPersistenceException.fromPostgrest(
        error: const PostgrestException(
          message:
              'insert or update on table "saved_foods" violates foreign key constraint',
          code: '23503',
          details: 'Key (user_id)=(...) is not present in table "users".',
        ),
        repositoryStep: 'SupabaseSavedFoodRepository.upsertOwnPrivate',
        operation: 'upsert',
      );

      expect(mapped.errorCode, SavedFoodErrorCode.userProfileRequired);
      expect(mapped.postgresCode, '23503');
    });

    test('maps RLS denial to permissionDenied', () {
      final mapped = SavedFoodPersistenceException.fromPostgrest(
        error: const PostgrestException(
          message: 'permission denied for table saved_foods',
          code: '42501',
        ),
        repositoryStep: 'SupabaseSavedFoodRepository.upsertOwnPrivate',
        operation: 'upsert',
      );

      expect(mapped.errorCode, SavedFoodErrorCode.permissionDenied);
    });
  });
}
