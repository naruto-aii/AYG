import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 有料案内と購入の記録。売上の集計に使う。広告には使わない。
enum PlusFunnelEvent {
  paywallOpen('paywall_open'),
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
}

class NoOpPlusFunnelRepository implements PlusFunnelRepository {
  const NoOpPlusFunnelRepository();

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {}
}

/// 送信に失敗しても、画面の操作は止めない。
class SupabasePlusFunnelRepository implements PlusFunnelRepository {
  SupabasePlusFunnelRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {
    // plus_funnel_events への書き込みは app_events に置き換えた。表は残す。
  }
}

Map<String, dynamic> plusFunnelInsertRow({
  required PlusFunnelEvent event,
  PlusFunnelFeature? feature,
  String? productId,
}) {
  return {
    'event': event.storageValue,
    if (feature != null) 'feature': feature.storageValue,
    if (productId != null && productId.isNotEmpty) 'product_id': productId,
    'advertising_use': false,
  };
}
