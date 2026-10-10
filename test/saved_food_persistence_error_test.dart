import 'package:ayg/models/saved_food_persistence_error.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
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

    test('banned public food text wins over the generic check failure', () {
      final mapped = SavedFoodPersistenceException.fromPostgrest(
        error: const PostgrestException(
          message: 'moderation banned public food text',
          code: '23514',
        ),
        repositoryStep: 'SupabaseSavedFoodRepository.publish',
        operation: 'publish',
      );

      expect(mapped.errorCode, SavedFoodErrorCode.bannedText);
      expect(
        mapped.userMessage,
        'この内容は公開できません。食品名、読み、ブランド、単位、補足、バーコード、出典を変えてください',
      );
    });

    test('a publish exception for banned text keeps that message', () {
      final mapped = SavedFoodPersistenceException.fromFoodMaster(
        error: const PublishSavedFoodException(
          kind: PublishFailureKind.bannedText,
          message: 'moderation banned public food text',
        ),
        repositoryStep: 'AppController.createSavedFood',
        operation: 'publish',
      );

      expect(mapped.errorCode, SavedFoodErrorCode.bannedText);
      expect(mapped.userMessage, contains('食品名、読み、ブランド'));
    });

    test('other moderation failures stay on the generic save message', () {
      final mapped = SavedFoodPersistenceException.fromFoodMaster(
        error: const PublishSavedFoodException(
          kind: PublishFailureKind.moderationBlocked,
          message: 'moderation status blocks publish',
        ),
        repositoryStep: 'AppController.createSavedFood',
        operation: 'publish',
      );

      expect(mapped.errorCode, SavedFoodErrorCode.insertFailed);
      expect(mapped.userMessage, '食品の保存に失敗しました。しばらく待ってからお試しください。');
    });
  });
}
