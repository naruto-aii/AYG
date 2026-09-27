import 'dart:async';

import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/repositories/subscription_repository.dart';

class MockSubscriptionRepository extends SubscriptionRepository {
  bool plus = false;
  bool purchaseUnavailable = false;
  bool monthlyCalled = false;
  bool yearlyCalled = false;
  bool restoreCalled = false;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isPlusActive => plus;

  @override
  Stream<bool> get plusChanges => _controller.stream;

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
