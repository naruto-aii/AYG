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
      const LockScreenMealSnapshot(ownerUserId: 'user-1', buttons: []),
    );
    expect(calls.last.method, 'writeSnapshot');
    final args = calls.last.arguments! as Map;
    expect(args['paid'], isTrue);
    expect(args['snapshot'], contains('user-1'));

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
    expect(find.text('ロック画面'), findsOneWidget);

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
    expect(find.text('ロック画面'), findsNothing);
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

    expect(find.text('ボタン1'), findsOneWidget);
    expect(find.text('ボタン2'), findsOneWidget);
    expect(find.text('ボタン3'), findsOneWidget);
    expect(find.textContaining('有料機能'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-0')),
      '朝',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-1')),
      '昼',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-2')),
      '夜',
    );
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();

    expect(gateway.saved?.buttonAt(0).label, '朝');
    expect(gateway.saved?.buttonAt(1).label, '昼');
    expect(gateway.saved?.buttonAt(2).label, '夜');
    expect(gateway.published?.ownerUserId, 'user-1');
    expect(gateway.published?.buttons[0].label, '朝');
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
