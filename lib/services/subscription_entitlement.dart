import 'dart:convert';

import '../config/subscription_catalog.dart';

class SubscriptionEntitlementRecord {
  const SubscriptionEntitlementRecord({
    required this.productId,
    required this.expiresAt,
    this.signedTransaction,
    this.revoked = false,
    this.upgraded = false,
  });

  final String productId;

  /// Null when the store did not provide an expiry. That is not an active grant.
  final DateTime? expiresAt;

  /// StoreKit 2 の署名付き取引。端末の有料表示には使わず、サーバ検証にだけ渡す。
  /// 端末の保存には残さない。
  final String? signedTransaction;

  /// 返金・取り消し。有料の期限としては使わない。
  final bool revoked;

  /// 上位プランへ移ったあとの古い取引。今の加入としては送らない。
  final bool upgraded;
}

/// 商品ごとに、今有効な取引を1件だけ選ぶ。
///
/// Transaction.currentEntitlements に相当する。Transaction.all の並びは保証されない。
/// 取り消されていない、isUpgraded でもない取引のうち、期限が最も遅いものを送る。
/// 取り消し済みや isUpgraded は、その商品に今有効な取引があるあいだは送らない。
/// 今有効な取引が無く、一番新しい取引が取り消しまたはアップグレードなら、その1件だけを送る。
class EntitlementSyncSelection {
  const EntitlementSyncSelection({
    required this.active,
    required this.revocations,
  });

  final List<SubscriptionEntitlementRecord> active;
  final List<SubscriptionEntitlementRecord> revocations;
}

EntitlementSyncSelection selectEntitlementTransactions(
  Iterable<SubscriptionEntitlementRecord> records,
) {
  final groups = <String, List<SubscriptionEntitlementRecord>>{};
  for (final record in records) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      continue;
    }
    groups.putIfAbsent(record.productId, () => []).add(record);
  }
  final active = <SubscriptionEntitlementRecord>[];
  final revocations = <SubscriptionEntitlementRecord>[];
  for (final group in groups.values) {
    SubscriptionEntitlementRecord? current;
    SubscriptionEntitlementRecord? ended;
    for (final record in group) {
      if (record.expiresAt == null) {
        continue;
      }
      if (!record.revoked && !record.upgraded) {
        if (current == null || record.expiresAt!.isAfter(current.expiresAt!)) {
          current = record;
        }
        continue;
      }
      if (ended == null || record.expiresAt!.isAfter(ended.expiresAt!)) {
        ended = record;
      }
    }
    if (current != null) {
      active.add(current);
    } else if (ended != null) {
      revocations.add(ended);
    }
  }
  return EntitlementSyncSelection(active: active, revocations: revocations);
}

/// Plus access follows the latest unexpired subscription, not a sticky flag.
class SubscriptionEntitlementState {
  SubscriptionEntitlementState([Map<String, DateTime>? initial])
    : expiryByProduct = Map<String, DateTime>.of(initial ?? const {});

  final Map<String, DateTime> expiryByProduct;

  void apply(SubscriptionEntitlementRecord record) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      return;
    }
    if (record.revoked || record.upgraded || record.expiresAt == null) {
      expiryByProduct.remove(record.productId);
      return;
    }
    expiryByProduct[record.productId] = record.expiresAt!;
  }

  /// 同じ商品は最も遅い期限だけを残す。履歴の並びで古い期限が後から来ても、
  /// 新しい期限を消さない。期限の無い行は採用しない。入力に無い商品は消す。
  void replaceAll(Iterable<SubscriptionEntitlementRecord> records) {
    final best = <String, DateTime>{};
    for (final record in records) {
      if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
        continue;
      }
      if (record.revoked || record.upgraded) {
        continue;
      }
      final expiry = record.expiresAt;
      if (expiry == null) {
        continue;
      }
      final current = best[record.productId];
      if (current == null || expiry.isAfter(current)) {
        best[record.productId] = expiry;
      }
    }
    expiryByProduct
      ..clear()
      ..addAll(best);
  }

  DateTime? get latestExpiry {
    DateTime? best;
    for (final expiry in expiryByProduct.values) {
      if (best == null || expiry.isAfter(best)) {
        best = expiry;
      }
    }
    return best;
  }

  bool isActive(DateTime now) {
    final expiry = latestExpiry;
    return expiry != null && expiry.isAfter(now);
  }
}

DateTime? parseStoreExpiryMillis(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final millis = int.tryParse(raw);
  if (millis == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Apple's Transaction.jsonRepresentation `revocationDate`.
/// A value means the transaction was refunded or revoked and must not grant Plus.
DateTime? parseStoreRevocationDate(String? jsonRepresentation) {
  if (jsonRepresentation == null || jsonRepresentation.isEmpty) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(jsonRepresentation);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final raw = decoded['revocationDate'];
  if (raw == null) {
    return null;
  }
  if (raw is num) {
    return _dateFromEpoch(raw);
  }
  if (raw is String) {
    final asNum = num.tryParse(raw);
    if (asNum != null) {
      return _dateFromEpoch(asNum);
    }
    return DateTime.tryParse(raw);
  }
  return null;
}

/// Apple's Transaction.jsonRepresentation `isUpgraded`.
/// 上位プランへ移った古い取引で、今の加入にはしない。
bool parseStoreTransactionUpgraded(String? jsonRepresentation) {
  if (jsonRepresentation == null || jsonRepresentation.isEmpty) {
    return false;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(jsonRepresentation);
  } catch (_) {
    return false;
  }
  if (decoded is! Map) {
    return false;
  }
  return decoded['isUpgraded'] == true;
}

/// 購入通知の利用者照合に使う。レシート本文は残さない。
String? parseOriginalTransactionId(String? jsonRepresentation) {
  if (jsonRepresentation == null || jsonRepresentation.isEmpty) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(jsonRepresentation);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final raw = decoded['originalTransactionId'] ?? decoded['original_transaction_id'];
  if (raw is String && raw.isNotEmpty) {
    return raw;
  }
  return null;
}

DateTime _dateFromEpoch(num value) {
  final millis = value.abs() >= 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis.round(), isUtc: true);
}

/// 端末に商品IDと期限だけを残す。レシート本文、検証データ、トークンは書かない。
///
/// キーが無いときは null。空配列は「ストアが商品を返さなかった」で、期限だけの
/// 古いキーへは戻さない。
List<SubscriptionEntitlementRecord>? decodeConfirmedEntitlements(String? raw) {
  if (raw == null) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! List) {
    return null;
  }
  final records = <SubscriptionEntitlementRecord>[];
  for (final row in decoded) {
    if (row is! Map) {
      continue;
    }
    final productId = row['productId'];
    final millis = row['expiresAtMs'];
    if (productId is! String || !SubscriptionCatalog.isPlusProduct(productId)) {
      continue;
    }
    if (millis is! int) {
      continue;
    }
    records.add(
      SubscriptionEntitlementRecord(
        productId: productId,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(millis),
      ),
    );
  }
  return records;
}

String encodeConfirmedEntitlements(Map<String, DateTime> expiryByProduct) {
  return jsonEncode([
    for (final entry in expiryByProduct.entries)
      if (SubscriptionCatalog.isPlusProduct(entry.key))
        {
          'productId': entry.key,
          'expiresAtMs': entry.value.millisecondsSinceEpoch,
        },
  ]);
}
