import 'dart:async';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Analytics.onEmitForTest = null;
  });

  test('onboarding completion events are sent once', () async {
    final names = <String>[];
    Analytics.onEmitForTest = (name, _) => names.add(name);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 60,
        targetDate: DateTime(2026, 12, 31),
      ),
    );

    Future<void> finish() async {
      try {
        await controller.completeOnboarding();
      } on StateError {
        // このテストは送信回数だけを見る。遠隔の保存先は持たない。
      }
    }

    await finish();
    await finish();

    expect(
      names.where((name) => name == 'onboarding_step_complete'),
      hasLength(1),
    );
    expect(names.where((name) => name == 'onboarding_complete'), hasLength(1));
    expect(controller.onboardingComplete, isTrue);
  });

  testWidgets('paywall stays closed until store prices have loaded', (
    tester,
  ) async {
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'paywall_open') {
        events.add(props);
      }
    };
    final plus = _DelayedPrices();
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: plus),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('カロナビ+'), findsNothing);
    expect(find.byKey(const Key('plus-plans')), findsNothing);
    expect(events, isEmpty);

    plus.release();
    await tester.pumpAndSettle();

    expect(find.text('カロナビ+'), findsOneWidget);
    expect(find.text('¥980'), findsOneWidget);
    expect(events, hasLength(1));
    expect(events.single['products_loaded'], isTrue);
    expect(events.single['load_error'], isFalse);
  });

  testWidgets('a failed price load still opens with the fallback prices', (
    tester,
  ) async {
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'paywall_open') {
        events.add(props);
      }
    };
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(
          repository: UnavailableSubscriptionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.plusFallbackMonthlyPrice), findsWidgets);
    expect(events, hasLength(1));
    expect(events.single['products_loaded'], isFalse);
    expect(events.single['load_error'], isTrue);
  });
}

class _DelayedPrices extends UnavailableSubscriptionRepository {
  final _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    await _gate.future;
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥8,800',
      ),
      loadFailed: false,
    );
  }
}
