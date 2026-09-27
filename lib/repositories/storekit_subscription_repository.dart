import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/subscription_catalog.dart';
import 'subscription_exceptions.dart';
import 'subscription_repository.dart';

/// App Store の自動更新サブスクリプション。
class StoreKitSubscriptionRepository extends SubscriptionRepository {
  StoreKitSubscriptionRepository({
    InAppPurchase? store,
    SharedPreferences? preferences,
  }) : _store = store ?? InAppPurchase.instance,
       _preferences = preferences;

  static const _plusKey = 'calonavi_plus_active';

  final InAppPurchase _store;
  final SharedPreferences? _preferences;
  final StreamController<bool> _plusController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _plus = false;

  @override
  bool get isPlusActive => _plus;

  @override
  Stream<bool> get plusChanges => _plusController.stream;

  Future<void> initialize() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _plus = prefs.getBool(_plusKey) ?? false;
    _purchaseSubscription ??= _store.purchaseStream.listen(_onPurchases);
    try {
      await restore();
    } catch (_) {}
  }

  @override
  Future<void> restore() async {
    await _store.restorePurchases();
  }

  @override
  Future<void> purchaseMonthly() {
    return _buy(SubscriptionCatalog.monthlyProductId);
  }

  @override
  Future<void> purchaseYearly() {
    return _buy(SubscriptionCatalog.yearlyProductId);
  }

  Future<void> _buy(String productId) async {
    final available = await _store.isAvailable();
    if (!available) {
      throw SubscriptionPurchaseUnavailableException();
    }
    final response = await _store.queryProductDetails({
      SubscriptionCatalog.monthlyProductId,
      SubscriptionCatalog.yearlyProductId,
    });
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
    if (product == null) {
      throw SubscriptionPurchaseFailedException(
        '購入商品が見つかりません。App Store Connect で商品を作成してください。',
      );
    }
    final launched = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!launched) {
      throw SubscriptionPurchaseFailedException('購入画面を開けませんでした。');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final isPlusProduct =
          purchase.productID == SubscriptionCatalog.monthlyProductId ||
          purchase.productID == SubscriptionCatalog.yearlyProductId;
      if (isPlusProduct &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        await _setPlus(true);
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (purchase.status == PurchaseStatus.error &&
          purchase.error != null &&
          purchase.error!.message.isNotEmpty) {
        // 購入失敗は画面側のタイムアウトやキャンセルと別に、ストアが通知する。
      }
    }
  }

  Future<void> _setPlus(bool value) async {
    _plus = value;
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(_plusKey, value);
    _plusController.add(value);
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _plusController.close();
  }
}
