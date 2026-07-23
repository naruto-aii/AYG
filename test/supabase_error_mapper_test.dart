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
  });
}
