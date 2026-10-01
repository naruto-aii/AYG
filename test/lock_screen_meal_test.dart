import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/settings/lock_screen_meal_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.text('音声登録'), findsOneWidget);
    expect(find.text('カロナビ+の機能です'), findsOneWidget);

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
    expect(find.text('音声登録'), findsNothing);
    await auth.dispose();
  });

  test('home has five buttons and the lock screen keeps three', () {
    final config = LockScreenMealConfig.defaults();
    expect(config.homeButtons, hasLength(5));
    expect(config.lockButtons, hasLength(3));
    expect(config.homeAt(0).label, '朝ごはん');
    expect(config.homeAt(4).label, 'ジョギング');
    expect(config.lockAt(0).label, '朝');
    expect(config.lockAt(2).label, '夜');

    final decoded = LockScreenMealCodec.decodeConfig(
      LockScreenMealCodec.encodeConfig(
        LockScreenMealConfig(
          homeButtons: [
            for (final button in config.homeButtons)
              button.slot == 4
                  ? button.copyWith(label: '夜食', templateId: 'snack')
                  : button,
          ],
          lockButtons: config.lockButtons,
        ),
      ),
    );
    expect(decoded.homeButtons, hasLength(5));
    expect(decoded.homeAt(4).label, '夜食');
    expect(decoded.homeAt(4).templateId, 'snack');
    expect(decoded.lockButtons, hasLength(3));
  });

  test('an older three-button config stays on the lock screen', () {
    final decoded = LockScreenMealCodec.decodeConfig(
      '{"version":1,"buttons":[{"slot":0,"label":"あさ","templateId":"t1"},{"slot":3,"label":"余分"}]}',
    );

    expect(decoded.lockAt(0).label, 'あさ');
    expect(decoded.lockAt(0).templateId, 't1');
    expect(decoded.lockButtons, hasLength(3));
    expect(decoded.lockAt(2).label, '夜');
    expect(decoded.homeAt(0).label, '朝ごはん');
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
    expect(find.text('ウィジェットからの登録は、カロナビ+です。'), findsOneWidget);

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('購入と復元は、カロナビ+の購入画面で行います。'), findsOneWidget);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。復唱してはいで登録。'),
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
    await tester.scrollUntilVisible(find.text('音声登録'), 200);
    await tester.tap(find.text('音声登録'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(find.text('購入と復元は、カロナビ+の購入画面で行います。'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('音声登録'), 200);
    await tester.tap(find.text('音声登録'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(
      find.textContaining('食事：Hey Siri、カロナビで、食事にささみを300グラム。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(
      find.textContaining('運動：Hey Siri、カロナビで、運動にジョギングを30分。復唱してはいで登録。'),
      findsOneWidget,
    );
    expect(find.text('ホーム画面'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
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

    expect(gateway.saved?.homeAt(0).label, '朝ごはん');
    expect(gateway.saved?.homeAt(4).label, '夜食');
    expect(gateway.saved?.homeButtons, hasLength(5));
    expect(gateway.saved?.lockAt(0).label, 'あさ');
    expect(gateway.saved?.lockAt(1).label, 'ひる');
    expect(gateway.saved?.lockAt(2).label, 'よる');
    expect(gateway.saved?.lockButtons, hasLength(3));
    expect(gateway.published?.ownerUserId, 'user-1');
    expect(gateway.published?.homeButtons[4].label, '夜食');
    expect(gateway.published?.lockButtons[0].label, 'あさ');
    await auth.dispose();
  });
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
