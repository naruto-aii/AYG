/// ウィジェットと Siri が記録してよいか。
///
/// Swift の `ShortcutAccessRules.decide` と同じ順で判定する。
/// 解約しても、保存した期限の終わりまでは使える。返金・取り消しはそこで止める。
/// 課金ではない付与（complimentary）と、アプリが書いた見本（preview）は
/// StoreKit の取り消しより先に残す。source の無い古い有料フラグは preview にしない。
enum ShortcutGrantSource { none, store, complimentary, preview, revoked }

extension ShortcutGrantSourceWire on ShortcutGrantSource {
  String get wire => name;
}

/// App Group に書く加入。期限は store のときだけ。
class ShortcutGrant {
  const ShortcutGrant._(this.source, this.expiresAt);

  const ShortcutGrant.none() : this._(ShortcutGrantSource.none, null);

  const ShortcutGrant.complimentary()
    : this._(ShortcutGrantSource.complimentary, null);

  const ShortcutGrant.preview() : this._(ShortcutGrantSource.preview, null);

  const ShortcutGrant.revoked() : this._(ShortcutGrantSource.revoked, null);

  const ShortcutGrant.store(DateTime? expiresAt)
    : this._(ShortcutGrantSource.store, expiresAt);

  final ShortcutGrantSource source;
  final DateTime? expiresAt;

  /// 端末の有料フラグ。拡張はこれだけでは記録せず、[decideShortcutAccess] を見る。
  bool get allows {
    return decideShortcutAccess(
          source: source,
          expiresAt: expiresAt,
          store: const PlusStoreFailed(),
          now: DateTime.now(),
        ) ==
        ShortcutAccess.paid;
  }
}

/// StoreKit 2 の取引を、拡張が読んだ結果。
sealed class PlusStoreSnapshot {
  const PlusStoreSnapshot();
}

/// 取り消しの無い取引が残っている。[expiresAt] が今より前なら期限切れ。
final class PlusStoreActive extends PlusStoreSnapshot {
  const PlusStoreActive({this.expiresAt});

  final DateTime? expiresAt;
}

/// 返金または取り消し（revocationDate）が見えた。
final class PlusStoreRevoked extends PlusStoreSnapshot {
  const PlusStoreRevoked();
}

/// この端末の取引履歴にカロナビ+が無い。
final class PlusStoreNone extends PlusStoreSnapshot {
  const PlusStoreNone();
}

/// 読めなかった。期限の保存値で判断し、返金とは扱わない。
final class PlusStoreFailed extends PlusStoreSnapshot {
  const PlusStoreFailed();
}

enum ShortcutAccess { paid, unpaid, expired, refunded }

const String shortcutPlusSpeech = 'こちらはカロナビ+の機能です';

const String widgetHomeGalleryDescription =
    'カロナビ+の機能です。残りカロリーに加え、食事と運動をワンタッチで登録します。枠は食事と運動を自由に組み合わせられます。';

const String widgetLockGalleryDescription =
    'カロナビ+の機能です。残りカロリーに加え、ホームの1〜3枠目をワンタッチで登録します。';

ShortcutAccess decideShortcutAccess({
  required ShortcutGrantSource source,
  DateTime? expiresAt,
  required PlusStoreSnapshot store,
  required DateTime now,
}) {
  final explicitGrant =
      source == ShortcutGrantSource.complimentary ||
      source == ShortcutGrantSource.preview;
  if (store is PlusStoreRevoked && !explicitGrant) {
    return ShortcutAccess.refunded;
  }
  if (source == ShortcutGrantSource.revoked) {
    if (store is PlusStoreActive) {
      final storeExpiry = store.expiresAt;
      if (storeExpiry != null && !storeExpiry.isAfter(now)) {
        return ShortcutAccess.expired;
      }
      return ShortcutAccess.paid;
    }
    return ShortcutAccess.refunded;
  }
  if (explicitGrant) {
    return ShortcutAccess.paid;
  }
  if (store is PlusStoreActive) {
    final storeExpiry = store.expiresAt;
    if (storeExpiry != null && !storeExpiry.isAfter(now)) {
      return ShortcutAccess.expired;
    }
    return ShortcutAccess.paid;
  }
  if (expiresAt != null) {
    return expiresAt.isAfter(now)
        ? ShortcutAccess.paid
        : ShortcutAccess.expired;
  }
  return ShortcutAccess.unpaid;
}

String shortcutAnalyticsResult(ShortcutAccess access) {
  return switch (access) {
    ShortcutAccess.paid => 'registered',
    ShortcutAccess.unpaid => 'unpaid',
    ShortcutAccess.expired => 'expired',
    ShortcutAccess.refunded => 'refunded',
  };
}

String shortcutStopReason(ShortcutAccess access) {
  return switch (access) {
    ShortcutAccess.paid => 'committed',
    ShortcutAccess.unpaid => 'unpaid',
    ShortcutAccess.expired => 'expired',
    ShortcutAccess.refunded => 'refunded',
  };
}

/// 有料の見た目は記録ボタン。それ以外は鍵と「カロナビ+」。
class WidgetChrome {
  const WidgetChrome({
    required this.showsRecordButtons,
    required this.showsTapHint,
    required this.showsPlusLock,
  });

  final bool showsRecordButtons;
  final bool showsTapHint;
  final bool showsPlusLock;
}

WidgetChrome widgetChromeFor(ShortcutAccess access) {
  if (access == ShortcutAccess.paid) {
    return const WidgetChrome(
      showsRecordButtons: true,
      showsTapHint: true,
      showsPlusLock: false,
    );
  }
  return const WidgetChrome(
    showsRecordButtons: false,
    showsTapHint: false,
    showsPlusLock: true,
  );
}

/// ボタンを押したときの動き。記録するか、購入画面を開くか。
class WidgetPress {
  const WidgetPress({
    required this.access,
    required this.records,
    required this.opensPaywall,
    required this.result,
    required this.entryPoint,
    required this.chrome,
  });

  final ShortcutAccess access;
  final bool records;
  final bool opensPaywall;
  final String result;
  final String? entryPoint;
  final WidgetChrome chrome;
}

WidgetPress widgetPress({
  required ShortcutAccess access,
  required bool hasPattern,
}) {
  final chrome = widgetChromeFor(access);
  if (access != ShortcutAccess.paid) {
    return WidgetPress(
      access: access,
      records: false,
      opensPaywall: true,
      result: shortcutAnalyticsResult(access),
      entryPoint: 'widget',
      chrome: chrome,
    );
  }
  if (!hasPattern) {
    return WidgetPress(
      access: access,
      records: false,
      opensPaywall: false,
      result: 'unassigned',
      entryPoint: null,
      chrome: chrome,
    );
  }
  return WidgetPress(
    access: access,
    records: true,
    opensPaywall: false,
    result: 'registered',
    entryPoint: null,
    chrome: chrome,
  );
}

/// Siri が聞き返す前の判定。無料なら質問せず、今の文のあと購入画面を開く。
class SiriLogStart {
  const SiriLogStart({
    required this.asks,
    required this.opensPaywall,
    required this.records,
    required this.speech,
    required this.entryPoint,
    required this.stopReason,
  });

  final bool asks;
  final bool opensPaywall;
  final bool records;
  final String? speech;
  final String? entryPoint;
  final String? stopReason;
}

SiriLogStart startSiriLog(ShortcutAccess access) {
  if (access != ShortcutAccess.paid) {
    return SiriLogStart(
      asks: false,
      opensPaywall: true,
      records: false,
      speech: shortcutPlusSpeech,
      entryPoint: 'siri',
      stopReason: shortcutStopReason(access),
    );
  }
  return const SiriLogStart(
    asks: true,
    opensPaywall: false,
    records: true,
    speech: null,
    entryPoint: null,
    stopReason: null,
  );
}
