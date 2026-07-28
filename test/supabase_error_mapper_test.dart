import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/supabase/supabase_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseErrorMapper', () {
    test('maps duplicate publish failure', () {
      final mapped = SupabaseErrorMapper.mapPublishFailure(
        const PostgrestException(message: 'duplicate public food exists'),
      );
      expect(mapped.kind, PublishFailureKind.duplicate);
    });

    test('maps hourly rate limit', () {
      final mapped = SupabaseErrorMapper.mapPublishFailure(
        const PostgrestException(message: 'hourly publish rate limit exceeded'),
      );
      expect(mapped.kind, PublishFailureKind.rateLimitHourly);
    });

    test('maps not authenticated', () {
      final mapped = SupabaseErrorMapper.map(
        const PostgrestException(message: 'not authenticated'),
        context: 'publish_saved_food',
      );
      expect(mapped, isA<FoodMasterAuthenticationException>());
    });

    test('maps self rating rejection', () {
      final mapped = SupabaseErrorMapper.map(
        const PostgrestException(message: 'self rating is not allowed'),
      );
      expect(mapped, isA<SelfRatingNotAllowedException>());
    });

    test('maps duplicate report conflict', () {
      final mapped = SupabaseErrorMapper.map(
        PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        ),
      );
      expect(mapped, isA<FoodMasterConflictException>());
    });

    test('maps permission denied to permission exception', () {
      final mapped = SupabaseErrorMapper.map(
        PostgrestException(
          message: 'permission denied for table saved_foods',
          code: '42501',
        ),
      );
      expect(mapped, isA<FoodMasterPermissionException>());
    });

    test('maps missing relation to table missing exception', () {
      final mapped = SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'relation "saved_foods" does not exist',
          code: '42P01',
        ),
        context: 'saved_foods pull',
      );
      expect(mapped, isA<FoodMasterTableMissingException>());
      expect((mapped as FoodMasterTableMissingException).postgresCode, '42P01');
      expect(mapped.tableName, 'saved_foods');
    });

    test('maps PGRST205 schema cache miss to table missing exception', () {
      final mapped = SupabaseErrorMapper.map(
        const PostgrestException(
          message:
              "Could not find the table 'public.saved_foods' in the schema cache",
          code: 'PGRST205',
          details: 'Not Found',
        ),
        context: 'saved_foods pull',
      );
      expect(mapped, isA<FoodMasterTableMissingException>());
      expect(
        (mapped as FoodMasterTableMissingException).postgresCode,
        'PGRST205',
      );
    });
  });
}
