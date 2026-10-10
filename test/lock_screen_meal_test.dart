import 'dart:convert';
import 'dart:io';

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/settings/lock_screen_meal_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/theme/app_typography.dart';
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

  MealTemplateItem dish(String id, String name) {
    return MealTemplateItem(
      itemId: id,
      name: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 100,
      consumedAmount: 100,
      sortOrder: 1,
      snapshotSavedAt: loggedAt,
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

  test('overlapping imports of one widget exercise tap save one row', () async {
    var next = 0;
    final meal = LockScreenMealRegistrar.register(
      paid: true,
      button: const LockScreenMealButtonSnapshot(
        slot: 4,
        label: 'ウォーキング',
        kind: WidgetPatternKind.exercise,
        exercises: [
          WidgetExercisePattern(
            itemId: 'old',
            activityId: 'walk_brisk',
            name: 'ウォーキング',
            sortOrder: 1,
            distanceKm: 3,
          ),
        ],
      ),
      ownerUserId: 'user-1',
      loggedAt: loggedAt,
      newId: () => 'id-${next++}',
    ).meal!;
    // 送信待ちの消し込みに失敗して、同じ登録が2回読まれる場合も含める。
    final gateway = _MemoryGateway(pending: [meal, meal]);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 60,
      ),
    );

    await Future.wait([
      controller.syncLockScreenMeals(),
      controller.syncLockScreenMeals(),
      controller.syncLockScreenMeals(),
    ]);
    await controller.syncLockScreenMeals();

    expect(controller.exerciseEntries, hasLength(1));
    expect(controller.exerciseEntries.single.id, meal.exercises.single.itemId);
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
    expect(find.text('ホーム画面とロック画面から登録'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('ホーム画面とロック画面から登録'))
          .didExceedMaxLines,
      isFalse,
    );
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
    expect(config.homeSlotCounts.meal, 3);
    expect(config.homeSlotCounts.exercise, 2);

    final allExercise = LockScreenMealConfig(
      homeButtons: [
        for (final button in config.homeButtons)
          button.copyWith(kind: WidgetPatternKind.exercise),
      ],
      lockButtons: config.lockButtons,
    );
    expect(allExercise.homeSlotCounts.meal, 0);
    expect(allExercise.homeSlotCounts.exercise, 5);

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

  test('stored kinds stay readable, including an exercise lock slot', () {
    final decoded = LockScreenMealCodec.decodeConfig(
      '{"version":3,"home":['
      '{"slot":0,"label":"朝ごはん","kind":"meal"},'
      '{"slot":1,"label":"昼ごはん","kind":"meal"},'
      '{"slot":2,"label":"夜ごはん","kind":"meal"},'
      '{"slot":3,"label":"夜食","kind":"meal"},'
      '{"slot":4,"label":"ジョギング","kind":"exercise","exercises":[{"id":"jog","name":"ジョギング","activityId":"jogging","durationMin":20,"sortOrder":1}]}'
      '],"lock":['
      '{"slot":0,"label":"朝ラン","kind":"exercise","exercises":[{"id":"walk","name":"ウォーキング","activityId":"walking","durationMin":10,"sortOrder":1}]},'
      '{"slot":1,"label":"昼","kind":"meal"},'
      '{"slot":2,"label":"夜","kind":"meal"}'
      ']}',
    );

    expect(decoded.homeAt(3).kind, WidgetPatternKind.meal);
    expect(decoded.homeAt(4).kind, WidgetPatternKind.exercise);
    expect(decoded.homeAt(4).exercises.single.activityId, 'jogging');
    expect(decoded.lockAt(0).kind, WidgetPatternKind.exercise);
    expect(decoded.lockAt(0).label, '朝ラン');
    expect(decoded.lockAt(0).exercises.single.activityId, 'walking');
    expect(decoded.lockAt(1).kind, WidgetPatternKind.meal);
    expect(decoded.lockAt(2).kind, WidgetPatternKind.meal);
  });

  test('a saved meal slot does not keep an exercise name', () {
    final decoded = LockScreenMealCodec.decodeConfig(
      '{"version":3,"home":['
      '{"slot":0,"label":"夜食","kind":"meal"},'
      '{"slot":1,"label":"昼ごはん","kind":"meal"},'
      '{"slot":2,"label":"夜ごはん","kind":"meal"},'
      '{"slot":3,"label":"ウォーキング","kind":"meal"},'
      '{"slot":4,"label":"ジョギング","kind":"exercise"}'
      '],"lock":['
      '{"slot":0,"label":"朝ごはん","kind":"exercise"},'
      '{"slot":1,"label":"昼","kind":"meal"},'
      '{"slot":2,"label":"ジョギング","kind":"meal"}'
      ']}',
    );

    expect(decoded.homeAt(0).label, '夜食');
    expect(decoded.homeAt(1).label, '昼ごはん');
    expect(decoded.homeAt(3).kind, WidgetPatternKind.meal);
    expect(decoded.homeAt(3).label, isEmpty);
    expect(decoded.homeAt(4).kind, WidgetPatternKind.exercise);
    expect(decoded.homeAt(4).label, 'ジョギング');
    expect(decoded.lockAt(0).kind, WidgetPatternKind.exercise);
    expect(decoded.lockAt(0).label, isEmpty);
    expect(decoded.lockAt(1).label, '昼');
    expect(decoded.lockAt(2).kind, WidgetPatternKind.meal);
    expect(decoded.lockAt(2).label, isEmpty);
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
      find.text(
        'ホーム画面とロック画面のウィジェットから、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。カロナビ+です。',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(find.textContaining('¥980'), findsWidgets);
    expect(find.textContaining(r'$'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    await _openMoreFeatures(tester);
    expect(
      find.textContaining(
        '食事：Hey Siri、カロナビで食事を記録。Siriの短い質問に、食べたものと量を答えます。登録した内容を読み上げます。',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '運動：Hey Siri、カロナビで運動を記録。Siriの短い質問に、した運動と量を答えます。登録した内容を読み上げます。',
      ),
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
    expect(find.textContaining('カロナビ+で使えます'), findsNothing);
    expect(
      find.textContaining(
        '食事：Hey Siri、カロナビで食事を記録。Siriの短い質問に、食べたものと量を答えます。登録した内容を読み上げます。',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '運動：Hey Siri、カロナビで運動を記録。Siriの短い質問に、した運動と量を答えます。登録した内容を読み上げます。',
      ),
      findsOneWidget,
    );
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    await _openMoreFeatures(tester);
    expect(
      find.textContaining(
        '食事：Hey Siri、カロナビで食事を記録。Siriの短い質問に、食べたものと量を答えます。登録した内容を読み上げます。',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '運動：Hey Siri、カロナビで運動を記録。Siriの短い質問に、した運動と量を答えます。登録した内容を読み上げます。',
      ),
      findsOneWidget,
    );
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('¥8,800で始める'), findsOneWidget);
    expect(find.textContaining('¥980'), findsWidgets);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('ホーム画面'), findsNothing);
    expect(controller.foodEntries, isEmpty);
    expect(controller.exerciseEntries, isEmpty);
    await auth.dispose();
  });

  testWidgets('a leftover paid flag still confirms before the paywall', (
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
    await tester.scrollUntilVisible(find.text('ウィジェット'), 200);
    await tester.tap(find.text('ウィジェット'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'カロナビ+を見る'));
    await tester.pumpAndSettle();
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('ホーム画面'), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('音声登録 (β)'), 200);
    await tester.tap(find.text('音声登録 (β)'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'カロナビ+を見る'));
    await tester.pumpAndSettle();
    expect(find.text('購入を復元'), findsOneWidget);
    expect(find.text('ショートカットを開く'), findsNothing);
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
      '食事：Hey Siri、カロナビで食事を記録。Siriの短い質問に、食べたものと量を答えます。登録した内容を読み上げます。',
    );
    final registered = find.textContaining('登録：Hey Siri、カロナビに登録');
    expect(meal, findsOneWidget);
    expect(registered, findsOneWidget);
    expect(find.textContaining('食事ですか、運動ですか？'), findsWidgets);
    expect(find.textContaining('Hey Siri、カロナビ登録'), findsOneWidget);
    expect(find.textContaining('Hey Siri、カロナビで食事にささみ'), findsOneWidget);
    expect(find.textContaining('Hey Siri、カロナビで運動にウォーキング'), findsOneWidget);
    expect(find.textContaining('Hey Siri、カロナビで今登録したやつ消して'), findsOneWidget);
    expect(
      find.textContaining('「○○を100g登録」のような言い方は、リマインダーに流れることがあるので非推奨。'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(registered).dy,
      greaterThan(tester.getTopLeft(meal).dy),
    );
    expect(
      find.textContaining(
        '運動：Hey Siri、カロナビで運動を記録。Siriの短い質問に、した運動と量を答えます。登録した内容を読み上げます。',
      ),
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
    await tester.scrollUntilVisible(find.text('ウィジェット'), 200);
    await tester.tap(find.text('ウィジェット'));
    await tester.pumpAndSettle();

    expect(find.text('こちらは有料の機能です'), findsNothing);
    expect(find.textContaining('元のテンプレートは変わらず'), findsOneWidget);
    expect(find.text('ホーム画面'), findsWidgets);
    expect(find.text('ロック画面'), findsWidgets);
    expect(
      find.byKey(const Key('lock-screen-meal-label-home-4')),
      findsOneWidget,
    );
    expect(find.text('枠1・食事'), findsOneWidget);
    expect(find.text('枠5・運動'), findsOneWidget);
    expect(find.text('食事パターン 1'), findsNothing);
    expect(find.text('運動パターン 1'), findsNothing);
    expect(
      find.byKey(const Key('lock-screen-meal-label-lock-2')),
      findsNothing,
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
    expect(find.text('枠4・運動'), findsOneWidget);
    expect(find.text('枠5・運動'), findsOneWidget);
    expect(find.byKey(const Key('lock-screen-meal-preview-2')), findsOneWidget);
    expect(find.text('枠3 · 食事 · 夜ごはん'), findsOneWidget);
    expect(
      find.byKey(const Key('lock-screen-meal-label-home-5')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('lock-screen-meal-label-lock-2')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-home-0')),
      'あさごは',
    );
    await tester.enterText(
      find.byKey(const Key('lock-screen-meal-label-home-4')),
      '夜食',
    );
    final mealOnFourth = find.byKey(const Key('widget-slot-kind-3-meal'));
    await tester.ensureVisible(mealOnFourth);
    await tester.tap(mealOnFourth);
    await tester.pumpAndSettle();
    expect(find.text('枠4・食事'), findsOneWidget);
    expect(find.text('枠4・運動'), findsNothing);
    expect(find.text('枠5・運動'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();

    expect(find.text('内容を保存しました'), findsOneWidget);
    expect(find.textContaining('左上「編集」'), findsWidgets);
    expect(find.textContaining('自動では付きません'), findsWidgets);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(gateway.saved?.homeAt(0).label, 'あさごは');
    expect(gateway.saved?.homeAt(0).kind, WidgetPatternKind.meal);
    expect(gateway.saved?.homeAt(3).kind, WidgetPatternKind.meal);
    expect(gateway.saved?.homeAt(3).exercises, isEmpty);
    expect(gateway.saved?.homeAt(4).label, '夜食');
    expect(gateway.saved?.homeAt(4).kind, WidgetPatternKind.exercise);
    expect(gateway.saved?.homeButtons, hasLength(5));
    expect(gateway.saved?.lockAt(0).label, 'あさごは');
    expect(gateway.saved?.lockAt(0).kind, WidgetPatternKind.meal);
    expect(gateway.saved?.lockAt(1).label, '昼ごはん');
    expect(gateway.saved?.lockAt(1).kind, WidgetPatternKind.meal);
    expect(gateway.saved?.lockAt(2).label, '夜ごはん');
    expect(gateway.saved?.lockAt(2).kind, WidgetPatternKind.meal);
    expect(gateway.saved?.lockButtons, hasLength(3));
    expect(gateway.published?.ownerUserId, 'user-1');
    expect(gateway.published?.homeButtons[3].kind, WidgetPatternKind.meal);
    expect(gateway.published?.homeButtons[4].label, '夜食');
    expect(gateway.published?.homeButtons[4].kind, WidgetPatternKind.exercise);
    expect(gateway.published?.homeButtons[4].templateId, isNull);
    expect(gateway.published?.homeButtons[0].kind, WidgetPatternKind.meal);
    expect(gateway.published?.lockButtons[0].label, 'あさごは');
    expect(gateway.published?.lockButtons[0].kind, WidgetPatternKind.meal);
    expect(gateway.published?.lockButtons[2].kind, WidgetPatternKind.meal);
    await auth.dispose();
  });

  testWidgets('five home slots can all be meals', (tester) async {
    final gateway = _MemoryGateway();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    await _openWidgetEditor(tester, controller);

    for (final slot in [3, 4]) {
      final chip = find.byKey(Key('widget-slot-kind-$slot-meal'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(find.text('枠5・食事'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    for (var slot = 0; slot < 5; slot++) {
      expect(gateway.saved?.homeAt(slot).kind, WidgetPatternKind.meal);
    }
    for (var slot = 0; slot < 3; slot++) {
      expect(gateway.saved?.lockAt(slot).kind, WidgetPatternKind.meal);
      expect(
        gateway.saved?.lockAt(slot).label,
        gateway.saved?.homeAt(slot).label,
      );
    }
    await auth.dispose();
  });

  testWidgets('home slots can be exercise only and the lock screen follows', (
    tester,
  ) async {
    final gateway = _MemoryGateway();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    await _openWidgetEditor(tester, controller);

    for (final slot in [0, 1, 2]) {
      final chip = find.byKey(Key('widget-slot-kind-$slot-exercise'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(find.text('枠1・運動'), findsOneWidget);
    expect(find.text('枠1 · 運動 · 文字なし'), findsOneWidget);
    expect(find.text('枠1 · 運動 · 朝ごはん'), findsNothing);
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    for (var slot = 0; slot < 5; slot++) {
      expect(gateway.saved?.homeAt(slot).kind, WidgetPatternKind.exercise);
      expect(gateway.saved?.homeAt(slot).items, isEmpty);
      if (slot < 3) {
        expect(gateway.saved?.homeAt(slot).label, isEmpty);
      }
    }
    for (var slot = 0; slot < 3; slot++) {
      expect(gateway.saved?.lockAt(slot).kind, WidgetPatternKind.exercise);
      expect(gateway.saved?.lockAt(slot).items, isEmpty);
      expect(
        gateway.published?.lockButtons[slot].kind,
        WidgetPatternKind.exercise,
      );
    }
    await auth.dispose();
  });

  testWidgets('changing a slot kind clears its previous contents', (
    tester,
  ) async {
    final gateway = _MemoryGateway();
    gateway.config = LockScreenMealConfig(
      homeButtons: [
        for (final button in LockScreenMealConfig.defaults().homeButtons)
          button.slot == 0
              ? LockScreenMealButtonConfig(
                  slot: 0,
                  label: '朝ごはん',
                  kind: WidgetPatternKind.meal,
                  contentName: 'いつもの朝',
                  items: [rice()],
                )
              : button,
      ],
      lockButtons: [
        LockScreenMealButtonConfig(slot: 0, label: '朝', items: [rice()]),
        for (final button in LockScreenMealConfig.defaults().lockButtons)
          if (button.slot != 0) button,
      ],
    );
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    await _openWidgetEditor(tester, controller);

    expect(find.text('ご飯'), findsOneWidget);
    final chip = find.byKey(const Key('widget-slot-kind-0-exercise'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('ご飯'), findsNothing);
    expect(find.text('運動の内容を入れる'), findsWidgets);
    expect(find.text('枠1 · 運動 · 文字なし'), findsOneWidget);
    expect(_homeLabel(tester, 0), isEmpty);
    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(gateway.saved?.homeAt(0).kind, WidgetPatternKind.exercise);
    expect(gateway.saved?.homeAt(0).items, isEmpty);
    expect(gateway.saved?.homeAt(0).exercises, isEmpty);
    expect(gateway.saved?.homeAt(0).contentName, isNull);
    expect(gateway.saved?.homeAt(0).label, isEmpty);
    expect(gateway.saved?.lockAt(0).kind, WidgetPatternKind.exercise);
    expect(gateway.saved?.lockAt(0).label, isEmpty);
    expect(gateway.saved?.lockAt(0).items, isEmpty);
    await auth.dispose();
  });

  testWidgets('opening settings clears an exercise name left on a meal slot', (
    tester,
  ) async {
    final gateway = _MemoryGateway();
    gateway.config = LockScreenMealConfig(
      homeButtons: [
        for (final button in LockScreenMealConfig.defaults().homeButtons)
          button.slot == 3
              ? const LockScreenMealButtonConfig(
                  slot: 3,
                  label: 'ウォーキング',
                  kind: WidgetPatternKind.meal,
                )
              : button,
      ],
      lockButtons: LockScreenMealConfig.defaults().lockButtons,
    );
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    await _openWidgetEditor(tester, controller);

    expect(_homeLabel(tester, 3), isEmpty);
    expect(find.text('枠4・食事'), findsOneWidget);
    expect(find.text('ウォーキング'), findsNothing);
    await auth.dispose();
  });

  testWidgets('widget settings can show four meals and one exercise', (
    tester,
  ) async {
    await _loadZenMaru();
    final gateway = _MemoryGateway();
    gateway.config = LockScreenMealConfig(
      homeButtons: [
        LockScreenMealButtonConfig(
          slot: 0,
          label: '朝ごはん',
          items: [dish('rice', 'ご飯'), dish('miso', 'みそ汁')],
        ),
        LockScreenMealButtonConfig(
          slot: 1,
          label: '昼ごはん',
          items: [dish('bento', '弁当')],
        ),
        LockScreenMealButtonConfig(
          slot: 2,
          label: '夜ごはん',
          items: [dish('salmon', '鮭'), dish('rice-night', 'ご飯')],
        ),
        LockScreenMealButtonConfig(
          slot: 3,
          label: '夜食',
          kind: WidgetPatternKind.meal,
          items: [dish('yogurt', 'ヨーグルト')],
        ),
        const LockScreenMealButtonConfig(
          slot: 4,
          label: 'ジョギング',
          kind: WidgetPatternKind.exercise,
          exercises: [
            WidgetExercisePattern(
              itemId: 'jog',
              activityId: 'jogging',
              name: 'ジョギング',
              sortOrder: 1,
              distanceKm: 3,
            ),
          ],
        ),
      ],
      lockButtons: LockScreenMealConfig.defaults().lockButtons,
    );
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
    );
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _widgetShotTheme(),
          home: LockScreenMealScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('枠4・食事'), findsOneWidget);
    expect(find.text('枠5・運動'), findsOneWidget);
    expect(_homeLabel(tester, 3), '夜食');
    expect(_homeLabel(tester, 4), 'ジョギング');
    expect(find.text('ヨーグルト'), findsOneWidget);
    expect(find.text('ジョギング 3km'), findsOneWidget);
    expect(find.text('ウォーキング'), findsNothing);

    await _alignSlotToTop(tester, 0);
    // 枠ごとにテンプレートのプルダウンが増えたので、1画面に入るのは枠1〜2まで。
    await _keepLabelAboveFold(tester, 1);
    expect(tester.getTopLeft(find.text('枠1・食事')).dy, greaterThan(0));
    expect(find.text('ご飯、みそ汁'), findsOneWidget);
    expect(find.text('弁当'), findsOneWidget);
    expect(find.text('夜ごはん'), findsWidgets);
    expect(find.text('鮭、ご飯'), findsOneWidget);
    await _saveWidgetShot(tester, key, 'widget-slots-top');

    await _alignSlotToTop(tester, 3);
    expect(find.text('枠4・食事'), findsOneWidget);
    expect(find.text('夜食'), findsWidgets);
    expect(find.text('ヨーグルト'), findsOneWidget);
    expect(find.text('枠5・運動'), findsOneWidget);
    await _saveWidgetShot(tester, key, 'widget-slots-bottom');
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

String _homeLabel(WidgetTester tester, int slot) {
  final finder = find.descendant(
    of: find.byKey(Key('lock-screen-meal-label-home-$slot')),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(finder).controller.text;
}

Future<void> _keepLabelAboveFold(WidgetTester tester, int slot) async {
  final scrollable = find.descendant(
    of: find.byType(LockScreenMealScreen),
    matching: find.byType(SingleChildScrollView),
  );
  final label = find.byKey(Key('lock-screen-meal-label-home-$slot'));
  final overflow =
      tester.getBottomLeft(label).dy - tester.getBottomLeft(scrollable).dy;
  if (overflow <= 8) {
    return;
  }
  await tester.drag(scrollable, Offset(0, -(overflow + 8)));
  await tester.pumpAndSettle();
}

Future<void> _alignSlotToTop(WidgetTester tester, int slot) async {
  final scrollable = find.descendant(
    of: find.byType(LockScreenMealScreen),
    matching: find.byType(SingleChildScrollView),
  );
  final target = find.byKey(Key('widget-slot-card-$slot'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final delta = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy;
  if (delta.abs() < 1) {
    return;
  }
  await tester.drag(scrollable, Offset(0, -delta));
  await tester.pumpAndSettle();
}

Future<void> _saveWidgetShot(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final directory = Platform.environment['MEAL_SEARCH_SHOTS'];
  if (directory == null || directory.isEmpty) {
    return;
  }
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
  );
  expect(bytes, isNotNull);
  Directory(directory).createSync(recursive: true);
  File('$directory/$name.png').writeAsBytesSync(bytes!);
}

Future<void> _openWidgetEditor(
  WidgetTester tester,
  AppController controller,
) async {
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
}

ThemeData _widgetShotTheme() {
  final theme = AppTheme.light;
  final zen = AppTypography.labelM.copyWith(fontFamily: 'ZenMaruGothic');
  return theme.copyWith(
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.chipTheme.labelStyle?.copyWith(
        fontFamily: 'ZenMaruGothic',
      ),
      secondaryLabelStyle: theme.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: 'ZenMaruGothic',
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(zen),
      ),
    ),
  );
}

Future<void> _loadZenMaru() async {
  final loader = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    return;
  }
  final decoded = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>;
  for (final package in packages) {
    final map = package as Map<String, dynamic>;
    if (map['name'] != 'material_symbols_icons') {
      continue;
    }
    final rootUri = map['rootUri'] as String;
    final root = rootUri.contains(':')
        ? Uri.parse(rootUri).toFilePath()
        : Directory('.dart_tool').uri.resolve(rootUri).toFilePath();
    final file = File('$root/lib/fonts/MaterialSymbolsRounded.ttf');
    if (!file.existsSync()) {
      return;
    }
    final symbols = FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    );
    symbols.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
    await symbols.load();
  }
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

/// 課金画面の「その他の機能を見る」を開く。音声登録の話し方はシートに出る。
Future<void> _openMoreFeatures(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('plus-more-features')));
  await tester.tap(find.byKey(const Key('plus-more-features')));
  await tester.pumpAndSettle();
  expect(find.text('カロナビ+のその他の機能'), findsOneWidget);
}
