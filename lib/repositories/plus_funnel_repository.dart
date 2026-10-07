import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/subscription_catalog.dart';

/// 有料案内と購入の記録。売上の集計に使う。広告には使わない。
enum PlusFunnelEvent {
  paywallOpen('paywall_open'),
  planSelect('plan_select'),
  purchaseTap('purchase_tap'),
  purchaseSuccess('purchase_success'),
  purchaseCancel('purchase_cancel'),
  purchaseFailed('purchase_failed'),
  restoreTap('restore_tap'),
  gateShown('gate_shown'),
  gateTap('gate_tap');

  const PlusFunnelEvent(this.storageValue);

  final String storageValue;
}

/// どの機能の案内か。案内が機能に紐づかないときは null。
enum PlusFunnelFeature {
  mealTemplateLimit('meal_template_limit'),
  workoutTemplateLimit('workout_template_limit'),
  recentFoods('recent_foods'),
  memo('memo'),
  widget('widget'),
  siri('siri'),
  coach('coach');

  const PlusFunnelFeature(this.storageValue);

  final String storageValue;
}

abstract class PlusFunnelRepository {
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  });

  /// 送れなかった行を、セッションがあるうちに再送する。
  Future<void> flushPending() async {}
}

class NoOpPlusFunnelRepository implements PlusFunnelRepository {
  const NoOpPlusFunnelRepository();

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {}

  @override
  Future<void> flushPending() async {}
}

/// 送信に失敗しても、画面の操作は止めない。
class SupabasePlusFunnelRepository implements PlusFunnelRepository {
  SupabasePlusFunnelRepository({
    SupabaseClient? client,
    SharedPreferences? preferences,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _client = client,
       _preferences = preferences,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final SupabaseClient? _client;
  final SharedPreferences? _preferences;
  final DateTime Function() _clock;
  final String Function() _newId;
  static const _queueKey = 'plus_funnel_outbox';

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    final row = plusFunnelQueuedRow(
      id: _newId(),
      event: event,
      feature: feature,
      productId: productId,
      occurredAt: _clock().toUtc(),
      userId: userId,
    );
    if (userId == null) {
      await _enqueue(row);
      return;
    }
    final sent = await _insert(row, userId);
    if (!sent) {
      await _enqueue(row);
    }
  }

  @override
  Future<void> flushPending() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    final pending = await _readQueue();
    final left = <Map<String, dynamic>>[];
    for (final row in pending) {
      final owner = row['user_id'];
      if (owner is String &&
          owner.isNotEmpty &&
          owner.toLowerCase() != userId.toLowerCase()) {
        left.add(row);
        continue;
      }
      final sent = await _insert(row, userId);
      if (!sent) {
        left.add(row);
      }
    }
    await _writeQueue(left);
  }

  Future<bool> _insert(Map<String, dynamic> row, String userId) async {
    final payload = <String, dynamic>{
      'id': row['id'],
      'user_id': userId,
      'event': row['event'],
      if (row['feature'] != null) 'feature': row['feature'],
      if (row['product_id'] != null) 'product_id': row['product_id'],
      'occurred_at': row['occurred_at'],
      'advertising_use': false,
    };
    try {
      await _supabase.from('plus_funnel_events').insert(payload);
      return true;
    } on PostgrestException catch (error, stackTrace) {
      if (error.code == '23505') {
        return true;
      }
      debugPrint('[AYG] plus funnel record failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[AYG] plus funnel record failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> row) async {
    final pending = await _readQueue();
    pending.add(row);
    await _writeQueue(pending);
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final raw = preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> rows) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(_queueKey, jsonEncode(rows));
  }
}

/// 購入に関係する記録は、月額・半年・年額の product_id を必ず持つ。
bool plusFunnelEventNeedsPlan(PlusFunnelEvent event) {
  return switch (event) {
    PlusFunnelEvent.planSelect ||
    PlusFunnelEvent.purchaseTap ||
    PlusFunnelEvent.purchaseSuccess ||
    PlusFunnelEvent.purchaseCancel ||
    PlusFunnelEvent.purchaseFailed ||
    PlusFunnelEvent.restoreTap => true,
    PlusFunnelEvent.paywallOpen ||
    PlusFunnelEvent.gateShown ||
    PlusFunnelEvent.gateTap => false,
  };
}

Map<String, dynamic> plusFunnelInsertRow({
  required PlusFunnelEvent event,
  PlusFunnelFeature? feature,
  String? productId,
}) {
  final plan = SubscriptionCatalog.planKeyForProduct(productId);
  final storedProduct = plusFunnelEventNeedsPlan(event)
      ? plan
      : (productId != null && productId.isNotEmpty ? productId : null);
  return {
    'event': event.storageValue,
    if (feature != null) 'feature': feature.storageValue,
    if (storedProduct != null) 'product_id': storedProduct,
    'advertising_use': false,
  };
}

Map<String, dynamic> plusFunnelQueuedRow({
  required String id,
  required PlusFunnelEvent event,
  PlusFunnelFeature? feature,
  String? productId,
  required DateTime occurredAt,
  String? userId,
}) {
  return {
    'id': id,
    if (userId != null && userId.isNotEmpty) 'user_id': userId,
    ...plusFunnelInsertRow(
      event: event,
      feature: feature,
      productId: productId,
    ),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}
