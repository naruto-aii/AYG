import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/subscription_catalog.dart';
import '../services/subscription_entitlement.dart';
import '../services/usage_record.dart';

/// 用途別の利用記録。失敗しても食事の保存や購入判定は止めない。
abstract class UsageRecordRepository {
  Future<void> recordFoodSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  });

  Future<void> recordExerciseSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  });

  Future<void> recordScreenAction({
    required String screen,
    required String action,
    String? eventId,
  });

  Future<void> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  });

  /// 送れなかった検索・操作・加入を、セッションがあるうちに再送する。
  Future<void> flushPending() async {}
}

class NoOpUsageRecordRepository implements UsageRecordRepository {
  const NoOpUsageRecordRepository();

  @override
  Future<void> recordFoodSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {}

  @override
  Future<void> recordExerciseSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {}

  @override
  Future<void> recordScreenAction({
    required String screen,
    required String action,
    String? eventId,
  }) async {}

  @override
  Future<void> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {}

  @override
  Future<void> flushPending() async {}
}

class SupabaseUsageRecordRepository implements UsageRecordRepository {
  SupabaseUsageRecordRepository({
    SupabaseClient? client,
    this.settle = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  final SupabaseClient? _client;
  final Duration settle;
  final DateTime Function() _clock;
  final Map<String, Timer> _foodTimers = {};
  final Map<String, _PendingSearch> _foodPending = {};
  final Map<String, Timer> _exerciseTimers = {};
  final Map<String, _PendingSearch> _exercisePending = {};

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<void> flushPending() async {}

  @override
  Future<void> recordFoodSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {
    _schedule(
      source: source,
      query: query,
      eventId: eventId,
      onSettled: onSettled,
      allowed: foodSearchSourceAllowed,
      timers: _foodTimers,
      pending: _foodPending,
      insert: (settled, id) => _insert('food_search_queries', source, settled, id),
    );
  }

  @override
  Future<void> recordExerciseSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {
    _schedule(
      source: source,
      query: query,
      eventId: eventId,
      onSettled: onSettled,
      allowed: exerciseSearchSourceAllowed,
      timers: _exerciseTimers,
      pending: _exercisePending,
      insert: (settled, id) =>
          _insert('exercise_search_queries', source, settled, id),
    );
  }

  void _schedule({
    required String source,
    required String query,
    required String? eventId,
    required void Function(String query, String eventId)? onSettled,
    required bool Function(String source) allowed,
    required Map<String, Timer> timers,
    required Map<String, _PendingSearch> pending,
    required Future<void> Function(String query, String eventId) insert,
  }) {
    if (!allowed(source)) {
      return;
    }
    final capped = capUsageQuery(query);
    if (capped.isEmpty) {
      return;
    }
    timers[source]?.cancel();
    pending[source] = _PendingSearch(
      query: capped,
      eventId: eventId ?? const Uuid().v4(),
      onSettled: onSettled,
    );
    timers[source] = Timer(settle, () {
      final settled = pending.remove(source);
      timers.remove(source);
      if (settled == null || settled.query.isEmpty) {
        return;
      }
      settled.onSettled?.call(settled.query, settled.eventId);
      unawaited(insert(settled.query, settled.eventId));
    });
  }

  Future<void> _insert(
    String table,
    String source,
    String query,
    String eventId,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await _supabase.from(table).insert({
        'id': eventId,
        'user_id': userId,
        'source': source,
        'query_text': query,
        'advertising_use': false,
      });
    } catch (error, stackTrace) {
      debugPrint('[AYG] usage search record failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> recordScreenAction({
    required String screen,
    required String action,
    String? eventId,
  }) async {
    if (!screenActionAllowed(screen: screen, action: action)) {
      return;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await _supabase.from('app_screen_actions').insert({
        if (eventId != null) 'id': eventId,
        'user_id': userId,
        'screen': screen,
        'action': action,
        'advertising_use': false,
      });
    } catch (error, stackTrace) {
      debugPrint('[AYG] usage screen record failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {
    if (confirmed.isEmpty && inactive.isEmpty && !authoritative) {
      return;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    final clock = now ?? _clock();
    try {
      final currentIds = <String>{};
      for (final record in confirmed) {
        if (!SubscriptionCatalog.syncsEntitlement(record.productId)) {
          continue;
        }
        if (record.expiresAt == null) {
          continue;
        }
        currentIds.add(record.productId);
        await _upsertEntitlement(
          userId: userId,
          productId: record.productId,
          expiresAt: record.expiresAt,
          status: statusForEntitlement(
            expiresAt: record.expiresAt,
            now: clock,
            inactive: false,
          ),
        );
      }
      for (final record in inactive) {
        if (!SubscriptionCatalog.syncsEntitlement(record.productId)) {
          continue;
        }
        if (currentIds.contains(record.productId)) {
          continue;
        }
        await _upsertEntitlement(
          userId: userId,
          productId: record.productId,
          expiresAt: record.expiresAt,
          status: UsageEntitlementStatus.inactive,
        );
      }
      if (!authoritative) {
        return;
      }
      final rows = await _supabase
          .from('calonavi_plus_entitlements')
          .select('product_id')
          .eq('user_id', userId);
      for (final row in rows) {
        final productId = row['product_id'];
        if (productId is! String || currentIds.contains(productId)) {
          continue;
        }
        await _supabase
            .from('calonavi_plus_entitlements')
            .update({
              'status': UsageEntitlementStatus.inactive,
              'advertising_use': false,
            })
            .eq('user_id', userId)
            .eq('product_id', productId);
      }
    } catch (error, stackTrace) {
      debugPrint('[AYG] plus entitlement sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _upsertEntitlement({
    required String userId,
    required String productId,
    required DateTime? expiresAt,
    required String status,
  }) async {
    final payload = plusEntitlementPayload(
      userId: userId,
      productId: productId,
      expiresAt: expiresAt,
      status: status,
    );
    // 期限が分からない取り消しでは、既にある期限を null で消さない。
    if (expiresAt == null) {
      payload.remove('expires_at');
      final updated = await _supabase
          .from('calonavi_plus_entitlements')
          .update({'status': status, 'advertising_use': false})
          .eq('user_id', userId)
          .eq('product_id', productId)
          .select('product_id');
      if (updated.isEmpty) {
        await _supabase.from('calonavi_plus_entitlements').insert(payload);
      }
      return;
    }
    await _supabase
        .from('calonavi_plus_entitlements')
        .upsert(payload, onConflict: 'user_id,product_id');
  }
}

class _PendingSearch {
  _PendingSearch({
    required this.query,
    required this.eventId,
    required this.onSettled,
  });

  final String query;
  final String eventId;
  final void Function(String query, String eventId)? onSettled;
}
