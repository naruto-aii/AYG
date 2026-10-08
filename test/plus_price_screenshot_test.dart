import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';

import 'mocks/mock_health_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    zen.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await zen.load();

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('paywall plans show the new tax-included prices', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);

    await _capture(
      tester,
      UnavailableSubscriptionRepository(),
      File('${directory.path}/paywall_top.png'),
      scrollToPlans: false,
    );
    expect(find.text('¥8,800で始める'), findsOneWidget);

    await _capture(
      tester,
      UnavailableSubscriptionRepository(),
      File('${directory.path}/paywall_plans_fallback.png'),
      scrollToPlans: true,
    );
    expect(find.text('¥980 ・ いつでも解約できます'), findsOneWidget);
    expect(find.text('¥4,900 ・ 月あたり約817円'), findsOneWidget);
    expect(find.text('¥8,800 ・ 月あたり約733円'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(find.text('お得'), findsOneWidget);
    expect(find.text('一番お得'), findsOneWidget);

    await _capture(
      tester,
      _StorePrices(),
      File('${directory.path}/paywall_plans_store.png'),
      scrollToPlans: true,
    );
    expect(find.text('¥8,800で始める'), findsOneWidget);

    await _captureFull(
      tester,
      UnavailableSubscriptionRepository(),
      File('${directory.path}/paywall_full.png'),
    );
    expect(find.text('ウィジェットでワンタップ記録'), findsOneWidget);
    expect(find.text('写真で登録 (β)'), findsOneWidget);
    expect(find.text('外食・コンビニ (β)'), findsOneWidget);
    expect(find.text('AIで探す (β)'), findsOneWidget);
    expect(find.text('パーソナルコーチ (β)'), findsOneWidget);
    expect(find.textContaining('セブン サラダチキン'), findsOneWidget);
    expect(find.textContaining('自炊コーチ'), findsOneWidget);
    expect(find.textContaining('あわせて1日15回までです'), findsOneWidget);
    expect(find.text('ホーム画面とロック画面のウィジェットから、アプリを開かずに食事と運動を登録できます。枠は食事と運動を自由に組み合わせられます。'), findsOneWidget);
    expect(find.text('β版機能に先行アクセス出来ます！'), findsOneWidget);
    expect(find.text('食事・運動の記録にメモを追加'), findsNothing);
    expect(find.textContaining('精度検証中'), findsNothing);
    expect(find.text('プランを選ぶ'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: key,
          child: const LegalDocumentScreen(document: LegalDocument.tokushoho),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('月額980円'), findsOneWidget);
    expect(find.textContaining('半年4,900円'), findsOneWidget);
    expect(find.textContaining('年額8,800円'), findsOneWidget);
    expect(find.textContaining('約817円'), findsOneWidget);
    expect(find.textContaining('約733円'), findsOneWidget);
    expect(find.textContaining('1か月分お得'), findsOneWidget);
    expect(find.textContaining('約25%お得'), findsOneWidget);
    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 2),
    );
    File('${directory.path}/tokushoho_price.png').writeAsBytesSync(bytes!);
  });

  testWidgets('a free user can add a meal memo', (tester) async {
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    addTearDown(controller.dispose);
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 60,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 60,
        targetDate: DateTime(2026, 12, 1),
      ),
    );
    controller.foodEntries.add(
      FoodEntry(
        id: 'today',
        name: 'ささみ',
        kcalPerBase: 100,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 200,
        loggedAt: DateTime.now(),
      ),
    );

    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => RepaintBoundary(
          key: key,
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.subscriptionRepository.isPlusActive, isFalse);
    await tester.scrollUntilVisible(
      find.text('メモ'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('メモ'));
    await tester.pumpAndSettle();
    expect(find.text('こちらは有料の機能です'), findsNothing);
    await tester.enterText(find.byType(TextField), '少し多かったから明日は150');
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 3),
    );
    expect(bytes, isNotNull);
    final shot = Directory('/opt/cursor/artifacts/screenshots')
      ..createSync(recursive: true);
    File('${shot.path}/free_user_memo.png').writeAsBytesSync(bytes!);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(controller.foodEntries.single.memo, '少し多かったから明日は150');
    expect(find.text('少し多かったから明日は150'), findsOneWidget);
    expect(find.text('メモを編集'), findsOneWidget);
  });

  testWidgets('app store review shots are single 6.7-inch screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.systemGestureInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    final directory = Directory('/opt/cursor/artifacts/screenshots')
      ..createSync(recursive: true);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              systemGestureInsets: EdgeInsets.zero,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: RepaintBoundary(
          key: key,
          child: CalonaviPlusEntryScreen(
            repository: UnavailableSubscriptionRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9:41'), findsNothing);
    expect(find.textContaining('Carrier'), findsNothing);
    expect(tester.takeException(), isNull);

    await _writeAsc(
      tester,
      key,
      File('${directory.path}/asc-review-paywall-features.png'),
    );
    expect(find.text('カロナビ+'), findsOneWidget);
    expect(find.text('β版機能に先行アクセス出来ます！'), findsOneWidget);
    expect(find.text('ウィジェットでワンタップ記録'), findsOneWidget);
    expect(find.text('写真で登録 (β)'), findsOneWidget);
    _expectAbovePurchase(tester, 'ウィジェットでワンタップ記録');
    _expectAbovePurchase(tester, '写真で登録 (β)');

    await _alignPlans(tester);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    _expectPlansOnScreen(tester);
    await _writeAsc(
      tester,
      key,
      File('${directory.path}/asc-review-paywall-annual.png'),
    );

    await tester.tap(find.byKey(const Key('plus-plan-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('¥980で始める'), findsOneWidget);
    _expectPlansOnScreen(tester);
    await _writeAsc(
      tester,
      key,
      File('${directory.path}/asc-review-paywall-monthly.png'),
    );

    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    expect(find.text('¥4,900で始める'), findsOneWidget);
    _expectPlansOnScreen(tester);
    await _writeAsc(
      tester,
      key,
      File('${directory.path}/asc-review-paywall-half-year.png'),
    );
  });
}

Future<void> _captureFull(
  WidgetTester tester,
  UnavailableSubscriptionRepository repository,
  File file,
) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
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
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final height = 844 + position.maxScrollExtent;
  await tester.binding.setSurfaceSize(Size(390, height));
  await tester.pumpAndSettle();
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 3),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
}

Future<void> _capture(
  WidgetTester tester,
  UnavailableSubscriptionRepository repository,
  File file, {
  required bool scrollToPlans,
  Size surface = const Size(390, 844),
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(surface);
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
  if (scrollToPlans) {
    await tester.scrollUntilVisible(find.text('プランを選ぶ'), 400);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('年額'));
    await tester.pumpAndSettle();
  }
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 2),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, greaterThan(100));
}

Future<void> _writeAsc(WidgetTester tester, GlobalKey key, File file) async {
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 3),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    codec.dispose();
    return image;
  });
  expect(image!.width, 1290);
  expect(image.height, 2796);
  image.dispose();
}

Future<void> _alignPlans(WidgetTester tester) async {
  final heading = find.text('プランを選ぶ');
  await tester.scrollUntilVisible(heading, 500);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(heading),
    alignment: 0,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
}

void _expectPlansOnScreen(WidgetTester tester) {
  final buttonTop = tester.getTopLeft(find.byKey(const Key('plus-purchase'))).dy;
  final headingTop = tester.getTopLeft(find.text('プランを選ぶ')).dy;
  expect(headingTop, greaterThanOrEqualTo(0));
  expect(headingTop, lessThan(buttonTop));
  for (final label in ['月額', '半年', '年額']) {
    final rect = tester.getRect(find.text(label));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(buttonTop));
  }
  for (final price in [
    '¥980 ・ いつでも解約できます',
    '¥4,900 ・ 月あたり約817円',
    '¥8,800 ・ 月あたり約733円',
  ]) {
    final rect = tester.getRect(find.text(price));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(buttonTop));
  }
}

void _expectAbovePurchase(WidgetTester tester, String text) {
  final buttonTop = tester.getTopLeft(find.byKey(const Key('plus-purchase'))).dy;
  final rect = tester.getRect(find.text(text));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThan(buttonTop));
}

class _StorePrices extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥4,900',
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
