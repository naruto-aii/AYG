import 'dart:async';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/repositories/subscription_repository.dart';
import 'package:ayg/services/subscription_offer.dart';

class MockSubscriptionRepository extends SubscriptionRepository {
  bool plus = false;
  bool purchaseUnavailable = false;
  bool monthlyCalled = false;
  bool yearlyCalled = false;
  bool restoreCalled = false;
  SubscriptionOfferings offerings = const SubscriptionOfferings(
    monthly: SubscriptionProductOffer(
      productId: SubscriptionCatalog.monthlyProductId,
      period: PlusBillingPeriod.month,
      localizedPrice: r'US$2.99',
    ),
    yearly: SubscriptionProductOffer(
      productId: SubscriptionCatalog.yearlyProductId,
      period: PlusBillingPeriod.year,
      localizedPrice: r'US$29.99',
    ),
    loadFailed: false,
  );

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isPlusActive => plus;

  @override
  Stream<bool> get plusChanges => _controller.stream;

  @override
  Future<SubscriptionOfferings> loadOfferings() async => offerings;

  void setPlus(bool value) {
    plus = value;
    _controller.add(value);
  }

  @override
  Future<void> restore() async {
    restoreCalled = true;
  }

  @override
  Future<void> purchaseMonthly() async {
    monthlyCalled = true;
    if (purchaseUnavailable) {
      throw SubscriptionPurchaseUnavailableException();
    }
    setPlus(true);
  }

  @override
  Future<void> purchaseYearly() async {
    yearlyCalled = true;
    if (purchaseUnavailable) {
      throw SubscriptionPurchaseUnavailableException();
    }
    setPlus(true);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
