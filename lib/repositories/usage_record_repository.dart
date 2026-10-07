import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/subscription_catalog.dart';
import '../services/subscription_entitlement.dart';
import '../services/usage_record.dart';
import 'persistent_event_outbox.dart';

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
    SharedPreferences? preferences,
    this.settle = const Duration(milliseconds: 400),
    DateTime Function()? clock,
    this.currentUserId,
    this.insertRow,
    this.upsertRow,
    PersistentEventOutbox? outbox,
  }) : _client = client,
       _clock = clock ?? DateTime.now,
       _outbox =
           outbox ??
           PersistentEventOutbox(
             preferences: preferences,
             key: usageEventOutboxKey,
           );

  final SupabaseClient? _client;
  final Duration settle;
  final DateTime Function() _clock;
  final String? Function()? currentUserId;
  final Future<void> Function(String table, Map<String, dynamic> row)?
  insertRow;
  final Future<void> Function(String table, Map<String, dynamic> row)?
  upsertRow;
  final PersistentEventOutbox _outbox;
  final Map<String, Timer> _foodTimers = {};
  final Map<String, _PendingSearch> _foodPending = {};
  final Map<String, Timer> _exerciseTimers = {};
  final Map<String, _PendingSearch> _exercisePending = {};

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String? _userId() {
    final override = currentUserId;
    if (override != null) {
      return override();
    }
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> flushPending() async {
    final userId = _userId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final pending = await _outbox.read();
    final left = <Map<String, dynamic>>[];
    for (final row in pending) {
      if (outboxRowBelongsToOtherUser(row, userId)) {
        left.add(row);
        continue;
      }
      final sent = await _deliverQueued(row, userId);
      if (!sent) {
        left.add(row);
      }
    }
    await _outbox.replace(left);
  }

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
      hold: (query, id) => _holdSearch(
        table: 'food_search_queries',
        source: source,
        query: query,
        eventId: id,
      ),
      insert: (settled, id) =>
          _insert('food_search_queries', source, settled, id),
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
      hold: (query, id) => _holdSearch(
        table: 'exercise_search_queries',
        source: source,
        query: query,
        eventId: id,
      ),
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
    required Future<void> Function(String query, String eventId) hold,
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
    final held = pending[source]!;
    unawaited(hold(held.query, held.eventId));
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

  Future<void> _holdSearch({
    required String table,
    required String source,
    required String query,
    required String eventId,
  }) async {
    final userId = _userId();
    final kind = table == 'food_search_queries'
        ? 'food_search'
        : 'exercise_search';
    await _outbox.append({
      'id': eventId,
      'kind': kind,
      'source': source,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'payload': {
        'id': eventId,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'source': source,
        'query_text': query,
        'advertising_use': false,
      },
    });
  }

  Future<void> _insert(
    String table,
    String source,
    String query,
    String eventId,
  ) async {
    final userId = _userId();
    final kind = table == 'food_search_queries'
        ? 'food_search'
        : 'exercise_search';
    final payload = <String, dynamic>{
      'id': eventId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'source': source,
      'query_text': query,
      'advertising_use': false,
    };
    await _outbox.append({
      'id': eventId,
      'kind': kind,
      'source': source,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'payload': payload,
    });
    if (userId == null || userId.isEmpty) {
      return;
    }
    final sent = await _deliver(
      table: table,
      payload: payload,
      required: const {'id', 'user_id', 'source', 'query_text'},
    );
    if (sent) {
      await _removeQueued(eventId);
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
    final userId = _userId();
    final id = eventId ?? const Uuid().v4();
    final payload = <String, dynamic>{
      'id': id,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'screen': screen,
      'action': action,
      'advertising_use': false,
    };
    await _outbox.append({
      'id': id,
      'kind': 'screen_action',
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'payload': payload,
    });
    if (userId == null || userId.isEmpty) {
      return;
    }
    final sent = await _deliver(
      table: 'app_screen_actions',
      payload: payload,
      required: const {'id', 'user_id', 'screen', 'action'},
    );
    if (sent) {
      await _removeQueued(id);
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
    final userId = _userId();
    if (userId == null || userId.isEmpty) {
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
        await _queueEntitlement(
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
        await _queueEntitlement(
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
        await _queueEntitlement(
          userId: userId,
          productId: productId,
          expiresAt: null,
          status: UsageEntitlementStatus.inactive,
          statusOnly: true,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[AYG] plus entitlement sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _queueEntitlement({
    required String userId,
    required String productId,
    required DateTime? expiresAt,
    required String status,
    bool statusOnly = false,
  }) async {
    final payload = plusEntitlementPayload(
      userId: userId,
      productId: productId,
      expiresAt: expiresAt,
      status: status,
    );
    if (expiresAt == null) {
      payload.remove('expires_at');
    }
    final id = '$userId|$productId';
    await _outbox.append({
      'id': id,
      'kind': statusOnly ? 'entitlement_status' : 'entitlement',
      'user_id': userId,
      'payload': payload,
    });
    final sent = await _deliverQueued({
      'id': id,
      'kind': statusOnly ? 'entitlement_status' : 'entitlement',
      'user_id': userId,
      'payload': payload,
    }, userId);
    if (sent) {
      await _removeQueued(id);
    }
  }

  Future<bool> _deliverQueued(Map<String, dynamic> row, String userId) async {
    final kind = row['kind'];
    final payload = outboxPayloadForUser(row, userId);
    if (kind == 'food_search') {
      return _deliver(
        table: 'food_search_queries',
        payload: payload,
        required: const {'id', 'user_id', 'source', 'query_text'},
      );
    }
    if (kind == 'exercise_search') {
      return _deliver(
        table: 'exercise_search_queries',
        payload: payload,
        required: const {'id', 'user_id', 'source', 'query_text'},
      );
    }
    if (kind == 'screen_action') {
      return _deliver(
        table: 'app_screen_actions',
        payload: payload,
        required: const {'id', 'user_id', 'screen', 'action'},
      );
    }
    if (kind == 'entitlement' || kind == 'entitlement_status') {
      return _deliver(
        table: 'calonavi_plus_entitlements',
        payload: payload,
        required: const {'user_id', 'product_id', 'status'},
        upsert: kind == 'entitlement',
        onConflict: 'user_id,product_id',
      );
    }
    return false;
  }

  Future<bool> _deliver({
    required String table,
    required Map<String, dynamic> payload,
    required Set<String> required,
    bool upsert = false,
    String? onConflict,
  }) {
    return deliverPersistentRow(
      table: table,
      payload: payload,
      requiredColumns: required,
      send: (row) async {
        if (upsert) {
          final hook = upsertRow;
          if (hook != null) {
            await hook(table, row);
            return;
          }
          await _supabase.from(table).upsert(row, onConflict: onConflict);
          return;
        }
        final hook = insertRow;
        if (hook != null) {
          await hook(table, row);
          return;
        }
        await _supabase.from(table).insert(row);
      },
    );
  }

  Future<void> _removeQueued(String id) async {
    final rows = await _outbox.read();
    rows.removeWhere((row) => row['id'] == id);
    await _outbox.replace(rows);
  }
}

const usageEventOutboxKey = 'usage_event_outbox';

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
