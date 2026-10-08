import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/subscription_catalog.dart';
import '../services/analytics/analytics.dart';
import '../services/subscription_entitlement.dart';
import '../services/subscription_offer.dart';
import 'subscription_exceptions.dart';
import 'subscription_repository.dart';

/// 購入API。本番は [InAppPurchase]、テストは偽の実装を渡す。
abstract class StorePurchaseClient {
  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> completePurchase(PurchaseDetails purchase);

  Future<void> restorePurchases();
}

class _InAppPurchaseClient implements StorePurchaseClient {
  _InAppPurchaseClient(this._store);

  final InAppPurchase _store;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) {
    return _store.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _store.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _store.completePurchase(purchase);
  }

  @override
  Future<void> restorePurchases() => _store.restorePurchases();
}

class EntitlementLoad {
  const EntitlementLoad({required this.records, required this.authoritative});

  final List<SubscriptionEntitlementRecord> records;

  /// True when the store answered. A failure must not wipe a still-valid expiry.
  final bool authoritative;
}

/// `purchase_result` は StoreKit の購入更新だけが送る。
void emitStoreKitPurchaseResult({
  required String productId,
  required String status,
  String? errorCode,
}) {
  Analytics.emit('purchase_result', {
    'product_id':
        SubscriptionCatalog.planKeyForProduct(productId) ?? productId,
    'status': status,
    if (errorCode != null && errorCode.isNotEmpty) 'error_code': errorCode,
  });
}

/// App Store の自動更新サブスクリプション。
class StoreKitSubscriptionRepository extends SubscriptionRepository {
  StoreKitSubscriptionRepository({
    InAppPurchase? store,
    StorePurchaseClient? purchaseClient,
    SharedPreferences? preferences,
    Stream<List<PurchaseDetails>>? purchaseUpdates,
    Future<EntitlementLoad> Function()? loadEntitlements,
    DateTime Function()? clock,
    this.developmentPlusPreview = false,
    this.testPurchaseEnabled = false,
  }) : _store = store,
       _purchaseClient = purchaseClient,
       _preferences = preferences,
       _purchaseUpdates = purchaseUpdates,
       _loadEntitlements = loadEntitlements,
       _clock = clock ?? DateTime.now;

  static const expiryKey = 'calonavi_plus_expires_at_ms';
  static const legacyPlusKey = 'calonavi_plus_active';
  static const entitlementsKey = 'calonavi_plus_entitlements_v1';

  /// ストアの加入とは別キー。フラグの無いビルドは読まない。
  static const testPlusKey = 'calonavi_plus_test_override';

  /// テスト加入の期限。本番の期限キーには書かない。
  static final testPurchaseExpiry = DateTime.utc(2099, 1, 1);

  final InAppPurchase? _store;
  final StorePurchaseClient? _purchaseClient;
  final SharedPreferences? _preferences;

  static const _purchaseResultTimeout = Duration(minutes: 2);
  final Stream<List<PurchaseDetails>>? _purchaseUpdates;
  final Future<EntitlementLoad> Function()? _loadEntitlements;
  final DateTime Function() _clock;

  /// 開発用ビルドで、購入せずに有料画面を見る。ストアの購入結果は上書きしない。
  /// テスト購入フラグがあるときは false にして、購入ボタンと無料化で切り替える。
  final bool developmentPlusPreview;

  /// 実機テスト用。true のとき購入ボタンは StoreKit を開かず、即時に有料へする。
  final bool testPurchaseEnabled;

  final StreamController<bool> _plusController =
      StreamController<bool>.broadcast();
  final StreamController<void> _entitlementSignals =
      StreamController<void>.broadcast();
  final SubscriptionEntitlementState _entitlement =
      SubscriptionEntitlementState();
  final Set<String> _confirmedIds = {};
  final Set<String> _revokedIds = {};
  final Map<String, DateTime> _lastExpiry = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _expiryTimer;
  bool _plus = false;
  bool _testPlus = false;
  bool _testOverridePresent = false;
  bool _productsConfirmed = false;
  bool _authoritative = false;
  bool _suppressAuthoritativeSweep = false;
  String? _applicationUserName;
  String? _originalTransactionId;
  final Map<String, String> _signedByProduct = {};
  final Map<String, String> _revocationSigned = {};
  Completer<PurchaseStatus>? _purchaseWaiter;
  String? _purchaseWaitProductId;

  @override
  bool get reportsEntitlementAnalytics => true;

  @override
  String? get storeOriginalTransactionId => _originalTransactionId;

  @override
  void bindStoreAccountToken(String? userId) {
    final trimmed = userId?.trim().toLowerCase();
    _applicationUserName = trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<SubscriptionEntitlementRecord> get confirmedEntitlements => [
    for (final id in _confirmedIds)
      if (_entitlement.expiryByProduct[id] != null)
        SubscriptionEntitlementRecord(
          productId: id,
          expiresAt: _entitlement.expiryByProduct[id],
          signedTransaction: _signedByProduct[id],
        ),
    ?_testConfirmed,
  ];

  @override
  List<SubscriptionEntitlementRecord> get inactiveEntitlements => [
    for (final id in _revokedIds)
      if (SubscriptionCatalog.isPlusProduct(id))
        SubscriptionEntitlementRecord(
          productId: id,
          expiresAt: _lastExpiry[id],
          signedTransaction: _revocationSigned[id] ?? _signedByProduct[id],
          revoked: _revocationSigned.containsKey(id),
        ),
    for (final entry in _revocationSigned.entries)
      if (!_revokedIds.contains(entry.key) &&
          SubscriptionCatalog.isPlusProduct(entry.key))
        SubscriptionEntitlementRecord(
          productId: entry.key,
          expiresAt: null,
          signedTransaction: entry.value,
          revoked: true,
        ),
    ?_testInactive,
  ];

  SubscriptionEntitlementRecord? get _testConfirmed {
    if (!testPurchaseEnabled || !_testPlus) {
      return null;
    }
    return SubscriptionEntitlementRecord(
      productId: SubscriptionCatalog.testPurchaseProductId,
      expiresAt: testPurchaseExpiry,
    );
  }

  SubscriptionEntitlementRecord? get _testInactive {
    if (!testPurchaseEnabled || !_testOverridePresent || _testPlus) {
      return null;
    }
    return const SubscriptionEntitlementRecord(
      productId: SubscriptionCatalog.testPurchaseProductId,
      expiresAt: null,
    );
  }

  @override
  bool get entitlementAuthoritative =>
      _suppressAuthoritativeSweep ? false : _authoritative;

  @override
  Stream<void> get entitlementChanges => _entitlementSignals.stream;

  @override
  bool get testPurchaseToggleEnabled => testPurchaseEnabled;

  @override
  bool get isPlusActive =>
      _plus || developmentPlusPreview || (testPurchaseEnabled && _testPlus);

  @override
  Stream<bool> get plusChanges => _plusController.stream;

  Future<void> initialize() async {
    final prefs = await _prefs();
    await prefs.remove(legacyPlusKey);
    final confirmed = decodeConfirmedEntitlements(
      prefs.getString(entitlementsKey),
    );
    if (confirmed != null) {
      _entitlement.replaceAll(confirmed);
      _confirmedIds
        ..clear()
        ..addAll(_entitlement.expiryByProduct.keys);
      _lastExpiry
        ..clear()
        ..addAll(_entitlement.expiryByProduct);
      _productsConfirmed = true;
    } else {
      final stored = prefs.getInt(expiryKey);
      if (stored != null) {
        // 古い期限キーには商品IDが無い。有料判定だけ月額として扱い、サーバには送らない。
        _entitlement.replaceAll([
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: DateTime.fromMillisecondsSinceEpoch(stored),
          ),
        ]);
      }
      _productsConfirmed = false;
      _confirmedIds.clear();
    }
    _plus = _entitlement.isActive(_clock());
    if (testPurchaseEnabled) {
      final stored = prefs.getBool(testPlusKey);
      _testOverridePresent = stored != null;
      _testPlus = stored ?? false;
    }
    _purchaseSubscription ??= _updates.listen(_onPurchases);
    try {
      await _refreshEntitlement();
    } catch (_) {}
  }

  Stream<List<PurchaseDetails>> get _updates {
    final updates = _purchaseUpdates;
    if (updates != null) {
      return updates;
    }
    return (_store ?? InAppPurchase.instance).purchaseStream;
  }

  StorePurchaseClient? get _purchases {
    final client = _purchaseClient;
    if (client != null) {
      return client;
    }
    final store = _store;
    if (store != null) {
      return _InAppPurchaseClient(store);
    }
    if (_purchaseUpdates != null) {
      return null;
    }
    return _InAppPurchaseClient(InAppPurchase.instance);
  }

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    if (testPurchaseEnabled) {
      return SubscriptionOfferings.failed;
    }
    final store = _purchases ?? _InAppPurchaseClient(InAppPurchase.instance);
    try {
      final available = await store.isAvailable();
      if (!available) {
        return SubscriptionOfferings.failed;
      }
      final response = await store.queryProductDetails(
        SubscriptionCatalog.plusProductIds,
      );
      if (response.error != null) {
        return SubscriptionOfferings.failed;
      }
      return SubscriptionOfferings(
        monthly: _offerFor(
          response.productDetails,
          SubscriptionCatalog.productIdFor(PlusPlan.monthly),
        ),
        halfYear: _offerFor(
          response.productDetails,
          SubscriptionCatalog.productIdFor(PlusPlan.halfYear),
        ),
        yearly: _offerFor(
          response.productDetails,
          SubscriptionCatalog.productIdFor(PlusPlan.yearly),
        ),
        loadFailed: false,
      );
    } catch (_) {
      return SubscriptionOfferings.failed;
    }
  }

  @override
  Future<void> restore() async {
    final store = _purchases ?? _InAppPurchaseClient(InAppPurchase.instance);
    await store.restorePurchases();
    await _refreshEntitlement();
  }

  @override
  Future<void> refreshEntitlement() async {
    try {
      await _refreshEntitlement();
    } catch (_) {
      await _persist();
    }
  }

  @override
  Future<void> purchaseMonthly() {
    return purchasePlan(PlusPlan.monthly);
  }

  @override
  Future<void> purchaseYearly() {
    return purchasePlan(PlusPlan.yearly);
  }

  @override
  Future<void> purchasePlan(PlusPlan plan) {
    if (testPurchaseEnabled) {
      return _setTestPlus(true);
    }
    return _buy(SubscriptionCatalog.productIdFor(plan));
  }

  @override
  Future<void> clearTestPurchase() async {
    if (!testPurchaseEnabled || !_testPlus) {
      return;
    }
    await _setTestPlus(false);
  }

  Future<void> _setTestPlus(bool active) async {
    _testPlus = active;
    _testOverridePresent = true;
    final prefs = await _prefs();
    await prefs.setBool(testPlusKey, active);
    _emitPlus();
    if (_entitlementSignals.isClosed) {
      return;
    }
    // テスト切替では、ストアが空でも本物の加入行を消さない。
    // 通知は次のマイクロタスクで届くので、フラグはその後に戻す。
    _suppressAuthoritativeSweep = true;
    _entitlementSignals.add(null);
    scheduleMicrotask(() {
      _suppressAuthoritativeSweep = false;
    });
  }

  void _emitPlus() {
    if (_plusController.isClosed) {
      return;
    }
    _plusController.add(isPlusActive);
  }

  Future<void> _buy(String productId) async {
    final store = _purchases ?? _InAppPurchaseClient(InAppPurchase.instance);
    final available = await store.isAvailable();
    if (!available) {
      throw SubscriptionPurchaseUnavailableException();
    }
    final response = await store.queryProductDetails({productId});
    if (response.error != null) {
      throw SubscriptionPurchaseFailedException(response.error!.message);
    }
    ProductDetails? product;
    for (final item in response.productDetails) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null || product.price.trim().isEmpty) {
      throw SubscriptionPurchaseFailedException(
        '購入商品が見つかりません。App Store Connect で商品を作成してください。',
      );
    }
    _purchaseSubscription ??= _updates.listen(_onPurchases);
    if (_purchaseWaiter != null) {
      throw SubscriptionPurchaseFailedException('別の購入を処理しています。');
    }
    final waiter = Completer<PurchaseStatus>();
    _purchaseWaiter = waiter;
    _purchaseWaitProductId = productId;
    try {
      final launched = await store.buyNonConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: product,
          applicationUserName: _applicationUserName,
        ),
      );
      if (!launched) {
        throw SubscriptionPurchaseFailedException('購入画面を開けませんでした。');
      }
      try {
        await waiter.future.timeout(_purchaseResultTimeout);
      } on TimeoutException {
        throw SubscriptionPurchaseFailedException('購入結果を確認できませんでした。');
      }
    } finally {
      if (identical(_purchaseWaiter, waiter)) {
        _purchaseWaiter = null;
        _purchaseWaitProductId = null;
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final store = _purchases;
    for (final purchase in purchases) {
      final original = parseOriginalTransactionId(
        purchase.verificationData.localVerificationData,
      );
      if (original != null) {
        _originalTransactionId = original;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final revoked =
            parseStoreRevocationDate(
              purchase.verificationData.localVerificationData,
            ) !=
            null;
        _applyIncoming(
          SubscriptionEntitlementRecord(
            productId: purchase.productID,
            expiresAt: _expiryOf(purchase),
            signedTransaction: purchase.verificationData.serverVerificationData,
            revoked: revoked,
          ),
        );
        emitStoreKitPurchaseResult(
          productId: purchase.productID,
          status: 'purchased',
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        emitStoreKitPurchaseResult(
          productId: purchase.productID,
          status: 'cancelled',
        );
      } else if (purchase.status == PurchaseStatus.error) {
        emitStoreKitPurchaseResult(
          productId: purchase.productID,
          status: 'failed',
          errorCode: purchase.error?.code,
        );
      } else if (purchase.status == PurchaseStatus.pending) {
        emitStoreKitPurchaseResult(
          productId: purchase.productID,
          status: 'pending',
        );
      }
      if (purchase.pendingCompletePurchase && store != null) {
        await store.completePurchase(purchase);
      }
    }
    try {
      await _persist();
      _completePurchaseWait(purchases);
    } catch (error, stackTrace) {
      if (_failPurchaseWait(purchases, error, stackTrace)) {
        return;
      }
      rethrow;
    }
  }

  /// 購入シートが閉じたあと、同じ商品の purchased / restored / canceled / error
  /// （Ask to Buy の pending も含む）が期限の保存まで終わってから [_buy] を返す。
  void _completePurchaseWait(List<PurchaseDetails> purchases) {
    final waiter = _purchaseWaiter;
    if (waiter == null || waiter.isCompleted || !_purchaseMatches(purchases)) {
      return;
    }
    PurchaseStatus? matched;
    for (final purchase in purchases) {
      if (purchase.productID != _purchaseWaitProductId) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
        case PurchaseStatus.pending:
          matched = purchase.status;
      }
    }
    if (matched != null) {
      waiter.complete(matched);
    }
  }

  bool _failPurchaseWait(
    List<PurchaseDetails> purchases,
    Object error,
    StackTrace stackTrace,
  ) {
    final waiter = _purchaseWaiter;
    if (waiter == null || waiter.isCompleted || !_purchaseMatches(purchases)) {
      return false;
    }
    waiter.completeError(error, stackTrace);
    return true;
  }

  bool _purchaseMatches(List<PurchaseDetails> purchases) {
    final waitingFor = _purchaseWaitProductId;
    if (waitingFor == null) {
      return false;
    }
    for (final purchase in purchases) {
      if (purchase.productID == waitingFor) {
        return true;
      }
    }
    return false;
  }

  Future<void> _refreshEntitlement() async {
    final load = _loadEntitlements ?? _loadStoreEntitlements;
    final result = await load();
    _authoritative = result.authoritative;
    if (!result.authoritative) {
      await _persist();
      return;
    }
    final previous = Set<String>.from(_confirmedIds);
    final remembered = {
      for (final id in previous) id: _entitlement.expiryByProduct[id],
    };
    final selection = selectEntitlementTransactions(result.records);
    final activeIds = {for (final record in selection.active) record.productId};
    _signedByProduct.removeWhere((id, _) => !activeIds.contains(id));
    _revocationSigned
      ..clear()
      ..addEntries(
        selection.revocations
            .where((record) => (record.signedTransaction ?? '').trim().isNotEmpty)
            .map((record) => MapEntry(record.productId, record.signedTransaction!.trim())),
      );
    for (final record in selection.active) {
      _rememberSigned(record.productId, record.signedTransaction);
    }
    _entitlement.replaceAll(selection.active);
    _confirmedIds
      ..clear()
      ..addAll(_entitlement.expiryByProduct.keys);
    for (final id in _confirmedIds) {
      final expiry = _entitlement.expiryByProduct[id];
      if (expiry != null) {
        _lastExpiry[id] = expiry;
      }
      _revokedIds.remove(id);
    }
    for (final id in previous.difference(_confirmedIds)) {
      final expiry = remembered[id];
      if (expiry != null) {
        _lastExpiry[id] = expiry;
      }
      _revokedIds.add(id);
    }
    for (final record in result.records) {
      if (record.expiresAt == null &&
          SubscriptionCatalog.isPlusProduct(record.productId) &&
          !_confirmedIds.contains(record.productId)) {
        _revokedIds.add(record.productId);
      }
    }
    _productsConfirmed = true;
    await _persist();
    _emitEntitlementObserved(changed: previous.length != _confirmedIds.length);
  }

  void _emitEntitlementObserved({required bool changed}) {
    final active = isPlusActive;
    final expiry = _entitlement.latestExpiry;
    String? productId;
    for (final id in _confirmedIds) {
      productId = id;
      break;
    }
    Analytics.emit('entitlement_observed', {
      'status': active ? 'active' : 'inactive',
      'product_id': productId,
      'expires_at': expiry?.toUtc().toIso8601String(),
      'original_transaction_id': _originalTransactionId,
      'changed': changed,
    });
  }

  /// 古い更新が後から来ても、期限も署名も戻さない。取り消しが今の期限より遅ければ無効にする。
  void _applyIncoming(SubscriptionEntitlementRecord record) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      return;
    }
    final signed = record.signedTransaction?.trim() ?? '';
    final current = _entitlement.expiryByProduct[record.productId];
    if (record.revoked) {
      if (current != null &&
          record.expiresAt != null &&
          record.expiresAt!.isBefore(current)) {
        return;
      }
      if (signed.isNotEmpty) {
        _revocationSigned[record.productId] = signed;
      }
      _applyRecord(
        SubscriptionEntitlementRecord(
          productId: record.productId,
          expiresAt: null,
          revoked: true,
        ),
      );
      return;
    }
    if (record.expiresAt != null &&
        current != null &&
        !record.expiresAt!.isAfter(current)) {
      return;
    }
    _revocationSigned.remove(record.productId);
    _rememberSigned(record.productId, signed);
    _applyRecord(record);
  }

  void _rememberSigned(String productId, String? signedTransaction) {
    final signed = signedTransaction?.trim() ?? '';
    if (signed.isEmpty || !SubscriptionCatalog.isPlusProduct(productId)) {
      return;
    }
    _signedByProduct[productId] = signed;
  }

  void _applyRecord(SubscriptionEntitlementRecord record) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      return;
    }
    final before = _entitlement.expiryByProduct[record.productId];
    _entitlement.apply(record);
    if (record.expiresAt == null) {
      if (before != null) {
        _lastExpiry[record.productId] = before;
      }
      _confirmedIds.remove(record.productId);
      _revokedIds.add(record.productId);
    } else {
      _lastExpiry[record.productId] = record.expiresAt!;
      _confirmedIds.add(record.productId);
      _revokedIds.remove(record.productId);
    }
    _productsConfirmed = true;
  }

  /// [SK2Transaction.transactions] は Transaction.all。並びは保証されない。
  /// 商品ごとに、取り消されていない取引のうち期限が最も遅いものだけを送る。
  ///
  /// Transaction.currentEntitlements は in_app_purchase_storekit 0.4.13 では
  /// restorePurchases の中だけで使われ、読み取り専用の API は無い。
  /// ここでは Transaction.all から同じ選び方（最新の有効期限、返金は除外）をする。
  /// 課金猶予（期限は過ぎているが currentEntitlements に残る）は、ここで判定しない。
  Future<EntitlementLoad> _loadStoreEntitlements() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return const EntitlementLoad(records: [], authoritative: false);
    }
    try {
      final transactions = await SK2Transaction.transactions();
      return EntitlementLoad(
        records: [
          for (final transaction in transactions)
            SubscriptionEntitlementRecord(
              productId: transaction.productId,
              expiresAt: parseStoreExpiryMillis(transaction.expirationDate),
              signedTransaction: transaction.receiptData,
              revoked:
                  parseStoreRevocationDate(transaction.jsonRepresentation) !=
                  null,
            ),
        ],
        authoritative: true,
      );
    } catch (_) {
      return const EntitlementLoad(records: [], authoritative: false);
    }
  }

  SubscriptionProductOffer? _offerFor(
    List<ProductDetails> products,
    String productId,
  ) {
    for (final product in products) {
      if (product.id != productId || product.price.trim().isEmpty) {
        continue;
      }
      return SubscriptionProductOffer(
        productId: product.id,
        period: periodForProduct(
          productId: product.id,
          storePeriod: _storePeriod(product),
        ),
        localizedPrice: product.price,
      );
    }
    return null;
  }

  PlusBillingPeriod? _storePeriod(ProductDetails product) {
    if (product is! AppStoreProduct2Details) {
      return null;
    }
    final period = product.sk2Product.subscription?.subscriptionPeriod;
    if (period == null) {
      return null;
    }
    return switch (period.unit) {
      SK2SubscriptionPeriodUnit.month when period.value == 1 =>
        PlusBillingPeriod.month,
      SK2SubscriptionPeriodUnit.month when period.value == 6 =>
        PlusBillingPeriod.halfYear,
      SK2SubscriptionPeriodUnit.year when period.value == 1 =>
        PlusBillingPeriod.year,
      _ => PlusBillingPeriod.other,
    };
  }

  DateTime? _expiryOf(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      return parseStoreExpiryMillis(purchase.expirationDate);
    }
    return null;
  }

  Future<void> _persist() async {
    final expiry = _entitlement.latestExpiry;
    final prefs = await _prefs();
    if (expiry == null) {
      await prefs.remove(expiryKey);
    } else {
      await prefs.setInt(expiryKey, expiry.millisecondsSinceEpoch);
    }
    if (_productsConfirmed) {
      await prefs.setString(
        entitlementsKey,
        encodeConfirmedEntitlements(_entitlement.expiryByProduct),
      );
    }
    _scheduleExpiryCheck();
    _signalEntitlementSync();
    final active = _entitlement.isActive(_clock());
    if (active == _plus) {
      return;
    }
    _plus = active;
    if (!_plusController.isClosed) {
      _plusController.add(active);
    }
  }

  void _scheduleExpiryCheck() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final expiry = _entitlement.latestExpiry;
    if (expiry == null) {
      return;
    }
    final remaining = expiry.difference(_clock());
    if (remaining <= Duration.zero) {
      return;
    }
    _expiryTimer = Timer(remaining, () {
      unawaited(_persist());
    });
  }

  void _signalEntitlementSync() {
    if (!_productsConfirmed && _revokedIds.isEmpty) {
      return;
    }
    if (_entitlementSignals.isClosed) {
      return;
    }
    _entitlementSignals.add(null);
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? await SharedPreferences.getInstance();
  }

  Future<void> dispose() async {
    _expiryTimer?.cancel();
    await _purchaseSubscription?.cancel();
    await _plusController.close();
    await _entitlementSignals.close();
  }
}
