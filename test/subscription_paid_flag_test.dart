import 'dart:async';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  test(
    'an active purchase unlocks the paid flag and expiry clears it',
    () async {
      final gateway = _FlagGateway();
      final plus = _Plus(false);
      final controller = AppController(
        lockScreenMealGateway: gateway,
        subscriptionRepository: plus,
      );

      await controller.initialize();
      expect(gateway.paid, isFalse);

      plus.active = true;
      plus.changes.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.paid, isTrue);
      expect(await controller.isMealWidgetPaid(), isTrue);

      plus.active = false;
      plus.changes.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.paid, isFalse);
      expect(await controller.isMealWidgetPaid(), isFalse);

      plus.active = true;
      await controller.refreshPaidEntitlement();
      expect(gateway.paid, isTrue);

      plus.active = false;
      await controller.refreshPaidEntitlement();
      expect(gateway.paid, isFalse);

      await plus.changes.close();
      controller.dispose();
    },
  );

  test('widgets follow the server, not a StoreKit purchase on another account', () async {
    final gateway = _FlagGateway();
    final plus = _Plus(true);
    final usage = _ServerUsage(StoreVerifyOutcome.notSent);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'reviewer', email: 'reviewer@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      subscriptionRepository: plus,
      usageRecordRepository: usage,
    );

    await controller.refreshPaidEntitlement();
    expect(gateway.paid, isFalse);
    expect(await controller.ensurePaidShortcutsReady(), isFalse);

    usage.outcome = StoreVerifyOutcome.accepted;
    expect(await controller.ensurePaidShortcutsReady(), isTrue);
    expect(gateway.paid, isTrue);

    usage.outcome = StoreVerifyOutcome.boundToOtherAccount;
    expect(await controller.ensurePaidShortcutsReady(), isFalse);
    expect(gateway.paid, isFalse);

    usage.outcome = StoreVerifyOutcome.rejected;
    plus.active = true;
    await controller.syncPlusEntitlementToServer();
    expect(gateway.paid, isFalse);

    await plus.changes.close();
    await auth.dispose();
    controller.dispose();
  });

  testWidgets(
    'the purchase screen uses the store price and does not set the flag',
    (tester) async {
      final gateway = _FlagGateway();
      final plus = _PricedPlus();
      final controller = AppController(
        lockScreenMealGateway: gateway,
        subscriptionRepository: plus,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showCalonaviPlus(context, repository: plus),
                child: const Text('開く'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('plus-more-features')));
      await tester.tap(find.byKey(const Key('plus-more-features')));
      await tester.pumpAndSettle();
      expect(find.text('カロナビ+のその他の機能'), findsOneWidget);
      expect(
        find.textContaining(AppStrings.siriVoiceFoodPhrase),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('plus-more-features-close')));
      await tester.pumpAndSettle();
      expect(find.text('カロナビ+のその他の機能'), findsNothing);
      expect(find.textContaining('¥980'), findsWidgets);
      expect(find.text('半年'), findsOneWidget);
      expect(find.text('年額'), findsOneWidget);
      expect(find.text('¥8,800で始める'), findsOneWidget);
      expect(find.textContaining('380'), findsNothing);
      expect(gateway.paid, isFalse);
      expect(plus.monthlyPurchases, 0);

      await tester.ensureVisible(find.byKey(const Key('plus-plan-monthly')));
      await tester.tap(find.byKey(const Key('plus-plan-monthly')));
      await tester.pumpAndSettle();
      expect(plus.monthlyPurchases, 0);
      expect(find.text('¥980で始める'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plus-purchase')));
      await tester.pumpAndSettle();

      expect(plus.monthlyPurchases, 1);
      expect(gateway.paid, isFalse);
      expect(controller.subscriptionRepository.isPlusActive, isFalse);
      controller.dispose();
    },
  );
}

class _ServerUsage extends NoOpUsageRecordRepository {
  _ServerUsage(this.outcome);

  StoreVerifyOutcome outcome;

  @override
  bool get syncsStoreEntitlements => true;

  @override
  Future<StoreVerifyOutcome> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {
    return outcome;
  }
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  bool active;
  final StreamController<bool> changes = StreamController<bool>.broadcast();

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => changes.stream;
}

class _PricedPlus extends UnavailableSubscriptionRepository {
  int monthlyPurchases = 0;

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      yearly: null,
      loadFailed: false,
    );
  }

  @override
  Future<void> purchasePlan(PlusPlan plan) async {
    if (plan == PlusPlan.monthly) {
      monthlyPurchases += 1;
    }
  }
}

class _FlagGateway implements LockScreenMealGateway {
  bool paid = false;

  @override
  Future<void> acknowledge(List<String> registrationIds) async {}

  @override
  Future<bool> isPaid() async => paid;

  @override
  Future<LockScreenMealConfig> loadConfig() async {
    return LockScreenMealConfig.defaults();
  }

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async => const [];

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {}

  @override
  Future<void> setPaid(bool isPaid) async {
    paid = isPaid;
  }
}
