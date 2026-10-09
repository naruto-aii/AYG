import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/storekit_subscription_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/screens/subscription/plus_gate.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart'
    show SKSubscriptionPeriodUnit;
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_health_repository.dart';

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    zen.addFont(
      Future<ByteData>.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await zen.load();
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final entry = (config['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'material_symbols_icons');
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final file = File(
    '${configUri.resolveUri(root).toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}

class _Offers extends UnavailableSubscriptionRepository {
  _Offers({this.trialDays});

  final int? trialDays;

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
        freeTrialDays: trialDays,
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥4,900',
        freeTrialDays: trialDays,
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥8,800',
        freeTrialDays: trialDays,
      ),
      loadFailed: false,
    );
  }
}

class _Store implements StorePurchaseClient {
  PurchaseParam? lastParam;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    const prices = {
      SubscriptionCatalog.monthlyProductId: '¥980',
      SubscriptionCatalog.halfYearProductId: '¥4,900',
      SubscriptionCatalog.yearlyProductId: '¥8,800',
    };
    return ProductDetailsResponse(
      productDetails: [
        for (final id in identifiers)
          ProductDetails(
            id: id,
            title: 'カロナビ+',
            description: 'カロナビ+',
            price: prices[id] ?? '¥980',
            rawPrice: 980,
            currencyCode: 'JPY',
          ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastParam = purchaseParam;
    return false;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);
  final bool active;
  @override
  bool get isPlusActive => active;
}

Future<void> _pumpPaywall(
  WidgetTester tester,
  UnavailableSubscriptionRepository repository, {
  Size size = const Size(390, 844),
  GlobalKey? key,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: key,
        child: CalonaviPlusEntryScreen(repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoBannedWording() {
  expect(find.textContaining('β版'), findsNothing);
  expect(find.textContaining('先行アクセス'), findsNothing);
  expect(find.textContaining('メモ'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('StoreKit free trial', () {
    test('trial days come from day and week periods only', () {
      expect(
        freeTrialDaysFor(
          unit: SKSubscriptionPeriodUnit.day,
          numberOfUnits: 3,
          numberOfPeriods: 1,
        ),
        3,
      );
      expect(
        freeTrialDaysFor(
          unit: SKSubscriptionPeriodUnit.week,
          numberOfUnits: 1,
          numberOfPeriods: 1,
        ),
        7,
      );
      expect(
        freeTrialDaysFor(
          unit: SKSubscriptionPeriodUnit.month,
          numberOfUnits: 1,
          numberOfPeriods: 1,
        ),
        isNull,
      );
    });

    test('offerings carry the trial only for products the store reports', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = StoreKitSubscriptionRepository(
        purchaseClient: _Store(),
        preferences: prefs,
        purchaseUpdates: const Stream<List<PurchaseDetails>>.empty(),
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: false),
        loadFreeTrialDays: (ids) async => {
          SubscriptionCatalog.monthlyProductId: 3,
          SubscriptionCatalog.yearlyProductId: 3,
        },
      );
      final offerings = await repository.loadOfferings();
      expect(offerings.loadFailed, isFalse);
      expect(offerings.monthly!.freeTrialDays, 3);
      expect(offerings.yearly!.hasFreeTrial, isTrue);
      expect(offerings.halfYear!.freeTrialDays, isNull);
      expect(offerings.halfYear!.localizedPrice, '¥4,900');
      await repository.dispose();
    });

    test('a failing trial lookup falls back to price only', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = StoreKitSubscriptionRepository(
        purchaseClient: _Store(),
        preferences: prefs,
        purchaseUpdates: const Stream<List<PurchaseDetails>>.empty(),
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: false),
        loadFreeTrialDays: (ids) async => throw StateError('no offer'),
      );
      final offerings = await repository.loadOfferings();
      expect(offerings.loadFailed, isFalse);
      for (final plan in PlusPlan.values) {
        expect(offerings.offerFor(plan)!.hasFreeTrial, isFalse);
        expect(offerings.offerFor(plan)!.canPurchase, isTrue);
      }
      await repository.dispose();
    });

    test('purchase does not skip the introductory offer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _Store();
      final repository = StoreKitSubscriptionRepository(
        purchaseClient: store,
        preferences: prefs,
        purchaseUpdates: const Stream<List<PurchaseDetails>>.empty(),
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: false),
      );
      await repository.initialize();
      await expectLater(
        repository.purchasePlan(PlusPlan.monthly),
        throwsA(anything),
      );
      final param = store.lastParam;
      expect(param, isA<Sk2PurchaseParam>());
      final sk2 = param! as Sk2PurchaseParam;
      expect(sk2.promotionalOffer, isNull);
      expect(sk2.winBackOfferId, isNull);
      expect(sk2.introductoryOfferEligibilityCompactJWS, isNull);
      await repository.dispose();
    });
  });

  group('paywall', () {
    testWidgets('shows trial copy when the store returns a free trial', (
      tester,
    ) async {
      final key = GlobalKey();
      await _pumpPaywall(
        tester,
        _Offers(trialDays: 3),
        size: const Size(430, 932),
        key: key,
      );
      expect(find.text('3日間無料ではじめる'), findsOneWidget);
      expect(find.text('¥8,800で始める'), findsNothing);
      expect(
        find.text('3日間無料 → そのあと月額¥980で自動更新 ・ いつでも解約できます'),
        findsOneWidget,
      );
      expect(
        find.text('3日間無料 → そのあと年額¥8,800で自動更新 ・ 月あたり約733円'),
        findsOneWidget,
      );
      expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);
      expect(find.text(AppStrings.plusTrialNotice(3)), findsOneWidget);
      expect(
        AppStrings.plusTrialNotice(3),
        contains('選んだプランの料金で自動的に有料の定期購入に切り替わり'),
      );
      _expectNoBannedWording();

      // 1290×2796（6.9インチ）。プランと無料お試しの文が見える位置で撮る。
      await tester.scrollUntilVisible(find.text('プランを選ぶ'), 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('年額'));
      await tester.pumpAndSettle();
      final bytes = await tester.runAsync(
        () => pngBytesFromBoundary(key, pixelRatio: 3),
      );
      final directory = Directory('/workspace/screenshots');
      if (directory.existsSync()) {
        File('${directory.path}/paywall_trial.png').writeAsBytesSync(bytes!);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('shows price only when the store has no trial', (tester) async {
      await _pumpPaywall(tester, _Offers());
      expect(find.text('¥8,800で始める'), findsOneWidget);
      expect(find.textContaining('日間無料'), findsNothing);
      expect(find.byKey(const Key('plus-trial-notice')), findsNothing);
      expect(find.text('¥8,800 ・ 月あたり約733円'), findsOneWidget);
      expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);
      _expectNoBannedWording();
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('fallback prices never claim a free trial', (tester) async {
      await _pumpPaywall(tester, UnavailableSubscriptionRepository());
      expect(find.text('¥8,800で始める'), findsOneWidget);
      expect(find.textContaining('日間無料'), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('ensureCalonaviPlus', () {
    Future<bool?> runGate(WidgetTester tester, bool plus) async {
      final controller = AppController(
        nutritionEngine: NutritionEngine(),
        healthRepository: MockHealthRepository(isAvailable: false),
        subscriptionRepository: _Plus(plus),
      );
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ensureCalonaviPlus(
                  context,
                  controller,
                  message: 'テスト',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('free users see the paid prompt every time', (tester) async {
      for (var i = 0; i < 2; i++) {
        await runGate(tester, false);
        expect(find.text('こちらは有料の機能です'), findsOneWidget);
        await tester.tap(find.text('閉じる'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('free users are not let through', (tester) async {
      final controller = AppController(
        nutritionEngine: NutritionEngine(),
        healthRepository: MockHealthRepository(isAvailable: false),
        subscriptionRepository: _Plus(false),
      );
      final completer = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                completer.complete(
                  await ensureCalonaviPlus(context, controller, message: 'x'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(await completer.future, isFalse);
    });

    testWidgets('plus users go straight through', (tester) async {
      final result = await runGate(tester, true);
      expect(result, isTrue);
      expect(find.text('こちらは有料の機能です'), findsNothing);
    });
  });
}
