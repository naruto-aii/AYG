import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/settings/lock_screen_meal_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget figures move remaining as soon as a button is logged', () {
    const before = MealWidgetFigures(
      remainingKcal: 500,
      intakeKcal: 1000,
      burnKcal: 200,
    );
    final eaten = applyMealWidgetFigures(
      figures: before,
      intakeDelta: 168.4,
      burnDelta: 0,
    );
    expect(eaten.remainingKcal, 332);
    expect(eaten.intakeKcal, 1168);
    expect(eaten.burnKcal, 200);

    final moved = applyMealWidgetFigures(
      figures: eaten,
      intakeDelta: 0,
      burnDelta: 88.2,
    );
    expect(moved.remainingKcal, 420);
    expect(moved.burnKcal, 288);

    final clamped = applyMealWidgetFigures(
      figures: const MealWidgetFigures(
        remainingKcal: 10,
        intakeKcal: 0,
        burnKcal: 0,
      ),
      intakeDelta: 50,
      burnDelta: 0,
    );
    expect(clamped.remainingKcal, 0);
    expect(clamped.intakeKcal, 50);
  });

  test('widget figures keep the target and switch to overage below zero', () {
    final over = applyMealWidgetFigures(
      figures: const MealWidgetFigures(
        remainingKcal: 10,
        intakeKcal: 2000,
        burnKcal: 0,
        targetKcal: 2010,
      ),
      intakeDelta: 50,
      burnDelta: 0,
    );
    expect(over.remainingKcal, 0);
    expect(over.overageKcal, 40);
    expect(over.targetKcal, 2010);

    final back = applyMealWidgetFigures(
      figures: over,
      intakeDelta: 0,
      burnDelta: 100,
    );
    expect(back.remainingKcal, 60);
    expect(back.overageKcal, isNull);
    expect(back.targetKcal, 2010);
  });

  final loggedAt = DateTime(2026, 10, 1, 8, 30);

  MealTemplateItem rice() {
    return MealTemplateItem(
      itemId: 'rice',
      name: 'ご飯',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 168,
      proteinPerBase: 2.5,
      fatPerBase: 0.3,
      carbPerBase: 37,
      consumedAmount: 150,
      sortOrder: 1,
      snapshotSavedAt: loggedAt,
      savedFoodId: 'food-rice',
      sourceOwnerUserId: 'user-1',
    );
  }

  LockScreenMealButtonSnapshot breakfastButton() {
    return LockScreenMealButtonSnapshot(
      slot: 0,
      label: '朝',
      templateId: 'template-breakfast',
      templateName: 'いつもの朝',
      items: [rice()],
    );
  }

  group('LockScreenMealRegistrar', () {
    test('unpaid press does not create a meal', () {
      final result = LockScreenMealRegistrar.register(
        paid: false,
        button: breakfastButton(),
        ownerUserId: 'user-1',
        loggedAt: loggedAt,
        newId: () => 'id',
      );

      expect(result.status, LockScreenMealRegisterStatus.unpaid);
      expect(result.meal, isNull);
    });

    test('paid press records one meal at the press time', () {
      var next = 0;
      final result = LockScreenMealRegistrar.register(
        paid: true,
        button: breakfastButton(),
        ownerUserId: 'user-1',
        loggedAt: loggedAt,
        newId: () => 'id-${next++}',
      );

      expect(result.status, LockScreenMealRegisterStatus.registered);
      final meal = result.meal!;
      expect(meal.entries, hasLength(1));
      expect(meal.entries.single.mealGroupId, meal.mealGroupId);
      expect(meal.entries.single.loggedAt, loggedAt);
      expect(meal.entries.single.mealGroupName, 'いつもの朝');
      expect(meal.entries.single.totalKcal, 252);
      expect(meal.templateId, 'template-breakfast');
    });

    test('a button without a template does not register', () {
      final result = LockScreenMealRegistrar.register(
        paid: true,
        button: const LockScreenMealButtonSnapshot(slot: 1, label: '昼'),
        ownerUserId: 'user-1',
        loggedAt: loggedAt,
        newId: () => 'id',
      );

      expect(result.status, LockScreenMealRegisterStatus.unassigned);
      expect(result.meal, isNull);
    });
  });

  test('pending meal json keeps the press timestamp and one group', () {
    var next = 0;
    final meal = LockScreenMealRegistrar.register(
      paid: true,
      button: breakfastButton(),
      ownerUserId: 'user-1',
      loggedAt: loggedAt,
      newId: () => 'id-${next++}',
    ).meal!;

    final decoded = LockScreenMealCodec.decodePending(
      LockScreenMealCodec.encodePending([meal]),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.registrationId, meal.registrationId);
    expect(decoded.single.loggedAt, loggedAt);
    expect(decoded.single.entries.single.id, meal.entries.single.id);
    expect(decoded.single.entries.single.mealGroupId, meal.mealGroupId);
    expect(decoded.single.entries.single.savedFoodId, 'food-rice');
    expect(decoded.single.surface, isNull);

    final withSurface = PendingLockScreenMeal(
      registrationId: meal.registrationId,
      ownerUserId: meal.ownerUserId,
      slot: meal.slot,
      templateId: meal.templateId,
      mealGroupId: meal.mealGroupId,
      mealGroupName: meal.mealGroupName,
      loggedAt: meal.loggedAt,
      entries: meal.entries,
      surface: 'lock',
    );
    final surfaced = LockScreenMealCodec.decodePending(
      LockScreenMealCodec.encodePending([withSurface]),
    );
    expect(surfaced.single.surface, 'lock');
  });

  test('paid flag defaults to false', () {
    expect(LockScreenMealPaidFlag.readValue(null), isFalse);
    expect(LockScreenMealPaidFlag.readValue(false), isFalse);
    expect(LockScreenMealPaidFlag.readValue(true), isTrue);
  });

  test('import keeps another user queued and does not duplicate ids', () {
    var next = 0;
    final own = LockScreenMealRegistrar.register(
      paid: true,
      button: breakfastButton(),
      ownerUserId: 'user-1',
      loggedAt: loggedAt,
      newId: () => 'id-${next++}',
    ).meal!;
    final other = PendingLockScreenMeal(
      registrationId: 'other',
      ownerUserId: 'user-2',
      slot: 1,
      templateId: 'template-lunch',
      mealGroupId: 'group-other',
      mealGroupName: '昼',
      loggedAt: loggedAt,
      entries: own.entries,
    );

    final first = planLockScreenMealImport(
      pending: [own, other],
      ownerUserId: 'user-1',
      existingEntryIds: const {},
    );
    expect(first.entries, hasLength(1));
    expect(first.acknowledgeIds, [own.registrationId]);
    expect(first.templateIds, ['template-breakfast']);

    final second = planLockScreenMealImport(
      pending: [own, other],
      ownerUserId: 'user-1',
      existingEntryIds: first.entries.map((entry) => entry.id).toSet(),
    );
    expect(second.entries, isEmpty);
    expect(second.acknowledgeIds, [own.registrationId]);
  });

  test('gateway stores the paid flag without a purchase screen', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    const channel = MethodChannel(lockScreenMealMethodChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'readPending') {
            return '[]';
          }
          return null;
        });
    final gateway = LockScreenMealGatewayImpl(
      preferences: await SharedPreferences.getInstance(),
      channel: channel,
    );

    expect(await gateway.isPaid(), isFalse);
    await gateway.setPaid(true);
    expect(await gateway.isPaid(), isTrue);
    expect(calls.single.method, 'setPaid');
    expect(calls.single.arguments, {'paid': true});

    await gateway.publishSnapshot(
      const LockScreenMealSnapshot(
        ownerUserId: 'user-1',
        homeButtons: [],
        lockButtons: [],
        figures: MealWidgetFigures(
          remainingKcal: 1200,
          intakeKcal: 800,
          burnKcal: 300,
        ),
      ),
    );
    expect(calls.last.method, 'writeSnapshot');
    final args = calls.last.arguments! as Map;
    expect(args['paid'], isTrue);
    final snapshot = args['snapshot'] as String;
    expect(snapshot, contains('user-1'));
    expect(snapshot, contains('"remaining":1200'));
    expect(snapshot, contains('"intake":800'));
    expect(snapshot, contains('"burn":300'));
    expect(snapshot, contains('"home"'));
    expect(snapshot, contains('"lock"'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('controller imports a paid lock-screen meal once', () async {
    var next = 0;
    final meal = LockScreenMealRegistrar.register(
      paid: true,
      button: breakfastButton(),
      ownerUserId: 'user-1',
      loggedAt: loggedAt,
      newId: () => 'id-${next++}',
    ).meal!;
    final gateway = _MemoryGateway(pending: [meal]);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );

    await controller.syncLockScreenMeals();

    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.loggedAt, loggedAt);
    expect(controller.foodEntries.single.mealGroupName, 'いつもの朝');
    expect(gateway.acknowledged, [meal.registrationId]);

    await controller.syncLockScreenMeals();
    expect(controller.foodEntries, hasLength(1));
    await auth.dispose();
  });

  testWidgets('settings shows the lock screen row only when enabled', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(authenticationRepository: auth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );
    expect(find.text('ウィジェット'), findsOneWidget);
    expect(find.text('音声登録 (β)'), findsOneWidget);
    expect(find.text('声だけで食事・運動を登録'), findsOneWidget);
    expect(find.text('カロナビ+で使えます'), findsNothing);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('声だけで食事・運動を登録'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(find.text('ウィジェットの置き方'), findsNothing);
    expect(find.textContaining('自動では付きません'), findsNothing);
    expect(find.textContaining('左上「編集」'), findsNothing);
    expect(find.textContaining('時刻の上下の枠をタップ'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          supportEmail: '',
        ),
      ),
    );
    expect(find.text('ウィジェット'), findsNothing);
    expect(find.text('音声登録 (β)'), findsNothing);
    expect(find.textContaining('自動では付きません'), findsNothing);
    await auth.dispose();
  });

  test('home has five buttons and the lock screen keeps three', () {
    final config = LockScreenMealConfig.defaults();
    expect(config.homeButtons, hasLength(5));
    expect(config.lockButtons, hasLength(3));
    expect(config.homeAt(0).label, '朝ごはん');
    expect(config.homeAt(0).kind, WidgetPatternKind.meal);
    expect(config.homeAt(2).kind, WidgetPatternKind.meal);
    expect(config.homeAt(3).label, 'ウォーキング');
    expect(config.homeAt(3).kind, WidgetPatternKind.exercise);
    expect(config.homeAt(4).label, 'ジョギング');
    expect(config.homeAt(4).kind, WidgetPatternKind.exercise);
    expect(config.lockAt(0).label, '朝');
    expect(config.lockAt(0).kind, WidgetPatternKind.meal);
    expect(config.lockAt(2).label, '夜');

    final decoded = LockScreenMealCodec.decodeConfig(
      LockScreenMealCodec.encodeConfig(
        LockScreenMealConfig(
          homeButtons: [
            for (final button in config.homeButtons)
              button.slot == 4
                  ? button.copyWith(
                      label: '夜食',
                      exercises: [
                        const WidgetExercisePattern(
                          itemId: 'jog',
                          activityId: 'jogging',
                          name: 'ジョギング',
                          sortOrder: 1,
                          distanceKm: 3,
                        ),
                      ],
                    )
                  : button,
          ],
          lockButtons: config.lockButtons,
        ),
      ),
    );
    expect(decoded.homeButtons, hasLength(5));
    expect(decoded.homeAt(4).label, '夜食');
    expect(decoded.homeAt(4).kind, WidgetPatternKind.exercise);
    expect(decoded.homeAt(4).exercises.single.distanceKm, 3);
    expect(decoded.homeAt(4).exercises.single.activityId, 'jogging');
    expect(decoded.lockButtons, hasLength(3));
    expect(decoded.lockAt(0).kind, WidgetPatternKind.meal);
  });

  test('an older three-button config stays on the lock screen', () {
    final decoded = LockScreenMealCodec.decodeConfig(
      '{"version":1,"buttons":[{"slot":0,"label":"あさ","templateId":"t1"},{"slot":3,"label":"余分"}]}',
    );

    expect(decoded.lockAt(0).label, 'あさ');
    expect(decoded.lockAt(0).items, isEmpty);
    expect(decoded.lockAt(0).kind, WidgetPatternKind.meal);
    expect(decoded.lockButtons, hasLength(3));
    expect(decoded.lockAt(2).label, '夜');
    expect(decoded.homeAt(0).label, '朝ごはん');
    expect(decoded.homeAt(0).kind, WidgetPatternKind.meal);
    expect(decoded.homeAt(3).label, 'ウォーキング');
    expect(decoded.homeAt(3).kind, WidgetPatternKind.exercise);
    expect(decoded.homeButtons, hasLength(5));
  });

  testWidgets('creating a widget explains the paid flow', (tester) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(authenticationRepository: auth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('ウィジェット'), 200);
    await tester.tap(find.text('ウィジェット'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(
      find.text('ウィジェットは、残りカロリーに加え、食事3つと運動2つをワンタッチで登録します。カロナビ+です。'),
      findsOneWidget,
    );

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('¥5,400で始める'), findsOneWidget);
    expect(find.textContaining('¥580'), findsWidgets);
    expect(find.textContaining(r'$'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。登録した内容を読み上げます。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。「さっきの登録を取り消して」で直前を消せます。'),
      findsOneWidget,
    );
    expect(find.text('ホーム画面'), findsNothing);
    await auth.dispose();
  });

  testWidgets('voice registration is shown as paid and does not log', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(authenticationRepository: auth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('音声登録 (β)'), 200);
    await tester.tap(find.text('音声登録 (β)'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(find.textContaining(AppStrings.siriBetaNotice), findsOneWidget);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。登録した内容を読み上げます。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。「さっきの登録を取り消して」で直前を消せます。'),
      findsOneWidget,
    );
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。登録した内容を読み上げます。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。「さっきの登録を取り消して」で直前を消せます。'),
      findsOneWidget,
    );
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('¥5,400で始める'), findsOneWidget);
    expect(find.textContaining('¥580'), findsWidgets);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('ホーム画面'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    await auth.dispose();
  });

  testWidgets('a paid account reads the voice note without the unpaid dialog', (
    tester,
  ) async {
    final gateway = _MemoryGateway()..paid = true;
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('音声登録 (β)'), 200);
    await tester.tap(find.text('音声登録 (β)'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(find.text('購入を復元'), findsNothing);
    expect(find.text('ショートカットを開く'), findsOneWidget);
    expect(find.text('使い始める前'), findsOneWidget);
    expect(find.text('音声登録 (β)'), findsWidgets);
    expect(find.textContaining('ショートカットを自分で作る必要はありません'), findsWidgets);
    expect(find.textContaining('カロナビ+で使えます'), findsNothing);
    expect(find.textContaining('β版として先行公開'), findsNothing);
    expect(find.textContaining('Siriと検索'), findsOneWidget);
    final meal = find.textContaining(
      '食事：Hey Siri、カロナビで、食事にささみを300グラム。登録した内容を読み上げます。',
    );
    final registered = find.textContaining('登録：Hey Siri、カロナビに登録');
    expect(meal, findsOneWidget);
    expect(registered, findsOneWidget);
    expect(find.textContaining('食事ですか、運動ですか？'), findsWidgets);
    expect(
      find.textContaining('「○○を100g登録」のような言い方は、リマインダーに流れることがあるので非推奨。'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(registered).dy,
      greaterThan(tester.getTopLeft(meal).dy),
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。「さっきの登録を取り消して」で直前を消せます。'),
      findsOneWidget,
    );
    expect(find.text('ホーム画面'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    await auth.dispose();
  });

  testWidgets('development plus opens siri setup and the widget editor', (
    tester,
  ) async {
    final gateway = _MemoryGateway();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      subscriptionRepository: _PreviewPlus(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('音声登録 (β)'), 200);
    await tester.tap(find.text('音声登録 (β)'));
    await tester.pumpAndSettle();

    expect(gateway.paid, isTrue);
    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(find.text('購入を復元'), findsNothing);
    expect(find.text('ショートカットを開く'), findsOneWidget);
    expect(find.text('使い始める前'), findsOneWidget);
    expect(find.textContaining('Siriと検索'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ウィジェット'), -200);
    await tester.tap(find.text('ウィジェット'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(find.text('購入を復元'), findsNothing);
    expect(find.text('ウィジェットの置き方'), findsWidgets);
    expect(find.textContaining('自動では付きません'), findsWidgets);
    expect(find.textContaining('左上「編集」'), findsWidgets);
    expect(find.textContaining('時刻の上下の枠をタップ'), findsWidgets);
    await auth.dispose();
  });

  testWidgets('a paid account opens the widget editor', (tester) async {
    final gateway = _MemoryGateway()..paid = true;
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('ウィジェット'), 200);
    await tester.tap(find.text('ウィジェット'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(find.textContaining('食事テンプレートの4件とは別'), findsOneWidget);
    expect(find.text('ホーム画面'), findsWidgets);
    expect(find.text('ロック画面'), findsWidgets);
    expect(
      find.byKey(const Key('lock-screen-meal-label-home-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lock-screen-meal-label-lock-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lock-screen-meal-label-lock-3')),
      findsNothing,
    );
    await auth.dispose();
  });

  testWidgets('lock screen settings save three labels', (tester) async {
    final gateway = _MemoryGateway();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        LockScreenMealScreen(controller: controller),
                  ),
                );
              },
              child: const Text('開く'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.text('ホーム画面'), findsWidgets);
    expect(find.text('ロック画面'), findsWidgets);
    expect(find.text('ウィジェットの置き方'), findsOneWidget);
    expect(find.textContaining('自動では付きません'), findsOneWidget);
    expect(find.textContaining('左上「編集」'), findsOneWidget);
    expect(find.textContaining('時刻の上下の枠をタップ'), findsOneWidget);
    expect(find.textContaining('有料'), findsNothing);
    expect(
      find.byKey(const Key('lock-screen-meal-label-home-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lock-screen-meal-label-lock-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lock-screen-meal-label-home-5')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-home-4')),
      '夜食',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-lock-0')),
      'あさ',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-lock-1')),
      'ひる',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-lock-2')),
      'よる',
    );
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();

    expect(find.text('内容を保存しました'), findsOneWidget);
    expect(find.textContaining('左上「編集」'), findsWidgets);
    expect(find.textContaining('自動では付きません'), findsWidgets);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(gateway.saved?.homeAt(0).label, '朝ごはん');
    expect(gateway.saved?.homeAt(4).label, '夜食');
    expect(gateway.saved?.homeButtons, hasLength(5));
    expect(gateway.saved?.lockAt(0).label, 'あさ');
    expect(gateway.saved?.lockAt(1).label, 'ひる');
    expect(gateway.saved?.lockAt(2).label, 'よる');
    expect(gateway.saved?.lockButtons, hasLength(3));
    expect(gateway.published?.ownerUserId, 'user-1');
    expect(gateway.published?.homeButtons[4].label, '夜食');
    expect(gateway.published?.homeButtons[4].kind, WidgetPatternKind.exercise);
    expect(gateway.published?.homeButtons[4].templateId, isNull);
    expect(gateway.published?.homeButtons[0].kind, WidgetPatternKind.meal);
    expect(gateway.published?.lockButtons[0].label, 'あさ');
    expect(gateway.published?.lockButtons[0].kind, WidgetPatternKind.meal);
    await auth.dispose();
  });

  test('an exercise pattern registers without a meal template', () {
    var next = 0;
    final result = LockScreenMealRegistrar.register(
      paid: true,
      button: const LockScreenMealButtonSnapshot(
        slot: 4,
        label: 'ジョギング',
        kind: WidgetPatternKind.exercise,
        exercises: [
          WidgetExercisePattern(
            itemId: 'old',
            activityId: 'jogging',
            name: 'ジョギング',
            sortOrder: 1,
            distanceKm: 3,
          ),
        ],
      ),
      ownerUserId: 'user-1',
      loggedAt: loggedAt,
      newId: () => 'id-${next++}',
    );

    expect(result.status, LockScreenMealRegisterStatus.registered);
    final pending = result.meal!;
    expect(pending.kind, WidgetPatternKind.exercise);
    expect(pending.entries, isEmpty);
    expect(pending.exercises.single.distanceKm, 3);
    expect(pending.exercises.single.itemId, isNot('old'));
    expect(pending.templateId, 'widget-exercise-4');

    final decoded = LockScreenMealCodec.decodePending(
      LockScreenMealCodec.encodePending([pending]),
    );
    expect(decoded.single.kind, WidgetPatternKind.exercise);
    expect(decoded.single.exercises.single.activityId, 'jogging');
  });

  test('jogging distance uses weight and does not invent kcal without it', () {
    const pattern = WidgetExercisePattern(
      itemId: 'jog',
      activityId: 'jogging',
      name: 'ジョギング',
      sortOrder: 1,
      distanceKm: 3,
    );
    final entry = widgetExerciseEntry(
      pattern: pattern,
      weightKg: 60,
      id: 'jog',
      loggedAt: loggedAt,
    );
    expect(entry?.netKcal, 180);
    expect(entry?.distanceKm, 3);
    expect(
      widgetExerciseEntry(
        pattern: pattern,
        weightKg: null,
        id: 'jog',
        loggedAt: loggedAt,
      ),
      isNull,
    );
    expect(widgetExerciseWaitsForWeight(pattern, null), isTrue);
    expect(widgetExerciseWaitsForWeight(pattern, 60), isFalse);
  });

  test(
    'controller imports a widget exercise once and keeps it out of foods',
    () async {
      final gateway = _MemoryGateway(
        pending: [
          PendingLockScreenMeal(
            registrationId: 'run-1',
            ownerUserId: 'user-1',
            slot: 4,
            templateId: 'widget-exercise-4',
            mealGroupId: '',
            mealGroupName: 'ジョギング',
            loggedAt: loggedAt,
            entries: const [],
            surface: 'home',
            kind: WidgetPatternKind.exercise,
            exercises: const [
              WidgetExercisePattern(
                itemId: 'jog-1',
                activityId: 'jogging',
                name: 'ジョギング',
                sortOrder: 1,
                distanceKm: 2,
              ),
            ],
          ),
        ],
      );
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final controller = AppController(
        authenticationRepository: auth,
        lockScreenMealGateway: gateway,
      );
      controller.profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 60,
      );

      await controller.syncLockScreenMeals();

      expect(controller.foodEntries, isEmpty);
      expect(controller.exerciseEntries, hasLength(1));
      expect(controller.exerciseEntries.single.netKcal, 120);
      expect(controller.exerciseEntries.single.loggedAt, loggedAt);
      expect(gateway.acknowledged, ['run-1']);

      await controller.syncLockScreenMeals();
      expect(controller.exerciseEntries, hasLength(1));
      await auth.dispose();
    },
  );
}

class _PreviewPlus extends UnavailableSubscriptionRepository {
  @override
  bool get isPlusActive => true;
}

class _MemoryGateway implements LockScreenMealGateway {
  _MemoryGateway({List<PendingLockScreenMeal>? pending})
    : pending = pending ?? [];

  LockScreenMealConfig config = LockScreenMealConfig.defaults();
  bool paid = false;
  List<PendingLockScreenMeal> pending;
  LockScreenMealConfig? saved;
  LockScreenMealSnapshot? published;
  final List<String> acknowledged = [];

  @override
  Future<void> acknowledge(List<String> registrationIds) async {
    acknowledged.addAll(registrationIds);
    pending = pending
        .where((meal) => !registrationIds.contains(meal.registrationId))
        .toList();
  }

  @override
  Future<bool> isPaid() async => paid;

  @override
  Future<LockScreenMealConfig> loadConfig() async => config;

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {
    published = snapshot;
  }

  @override
  Future<List<PendingLockScreenMeal>> readPending() async => pending;

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {
    saved = config;
    this.config = config;
  }

  @override
  Future<void> setPaid(bool isPaid) async {
    paid = isPaid;
  }
}
