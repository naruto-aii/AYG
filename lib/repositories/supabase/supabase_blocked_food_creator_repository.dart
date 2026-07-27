import 'package:supabase_flutter/supabase_flutter.dart';

import '../contracts/blocked_food_creator_repository_base.dart';
import 'supabase_error_mapper.dart';

class SupabaseBlockedFoodCreatorRepository
    implements BlockedFoodCreatorRepositoryBase {
  SupabaseBlockedFoodCreatorRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> block({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    try {
      await _client.from('blocked_food_creators').upsert({
        'blocker_user_id': blockerUserId,
        'blocked_user_id': blockedUserId,
      }, onConflict: 'blocker_user_id,blocked_user_id');
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'blocked_food_creators block',
      );
    }
  }

  @override
  Future<void> unblock({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    try {
      await _client
          .from('blocked_food_creators')
          .delete()
          .eq('blocker_user_id', blockerUserId)
          .eq('blocked_user_id', blockedUserId);
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'blocked_food_creators unblock',
      );
    }
  }

  @override
  Future<List<String>> getBlockedUserIds(String blockerUserId) async {
    try {
      final rows = await _client
          .from('blocked_food_creators')
          .select('blocked_user_id')
          .eq('blocker_user_id', blockerUserId);
      return rows.map((row) => row['blocked_user_id'] as String).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'blocked_food_creators list',
      );
    }
  }

  @override
  Future<bool> isBlocked({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    try {
      final row = await _client
          .from('blocked_food_creators')
          .select('blocked_user_id')
          .eq('blocker_user_id', blockerUserId)
          .eq('blocked_user_id', blockedUserId)
          .maybeSingle();
      return row != null;
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'blocked_food_creators isBlocked',
      );
    }
  }
}
