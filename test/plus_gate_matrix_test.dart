import 'dart:typed_data';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/repositories/contracts/meal_template_repository_base.dart';
import 'package:ayg/repositories/contracts/workout_template_repository_base.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/repositories/subscription_repository.dart';
import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/food/chain_food_lookup_screen.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/meal_food_search_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/meal_template/meal_template_list_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/workout_template/workout_template_screens.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/plus_gate_retry.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:ayg/widgets/food/ai_food_lookup_row.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:functions_client/functions_client.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deadEnd = 'こちらはカロナビ+の機能です。手入力で記録できます。';
  const deadEndShort = 'こちらはカロナビ+の機能です。';

  setUp(() {
    PlusGateRetry.bind(null);
  });

  Future<void> show(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> expectDialogThenPaywall(WidgetTester tester) async {
    expect(find.text('こちらは有料の機能です'), findsOneWidget);
    expect(find.text(deadEnd), findsNothing);
    expect(find.text(deadEndShort), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'カロナビ+を見る'));
    await tester.pumpAndSettle();
    expect(find.text('購入を復元'), findsOneWidget);
  }

  void prepareHome(AppController controller) {
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
  }

  AppController unpaid() {
    final controller = AppController();
    addTearDown(controller.dispose);
    return controller;
  }

  AppController plus() {
    final controller = AppController(subscriptionRepository: _GatePlus(active: true));
    addTearDown(controller.dispose);
    return controller;
  }

  group('未加入は確認ダイアログのあと課金画面', () {
    testWidgets('AIで探す（0件）', (tester) async {
      final controller = unpaid();
      await show(
        tester,
        MealFoodSearchScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
        ),
      );
      await tester.enterText(find.byKey(const Key('meal-food-search-field')), '牛丼');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-food-lookup-empty')), findsOneWidget);
      await tapLabel(tester, find.text(AiFoodLookupRow.label));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('AIで探す（検索結果の行）', (tester) async {
      final controller = unpaid();
      await show(
        tester,
        MealFoodSearchScreen(
          controller: controller,
          searchOverrides: _hitSearch(),
        ),
      );
      await tester.enterText(find.byKey(const Key('meal-food-search-field')), 'おにぎり');
      await tester.pumpAndSettle();
      await tapLabel(tester, find.text(AiFoodLookupRow.label));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('外食・コンビニ', (tester) async {
      final controller = unpaid();
      await show(tester, MealFoodSearchScreen(controller: controller));
      await tapLabel(tester, find.byKey(const Key('chain-food-lookup-row')));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('写真で登録', (tester) async {
      final controller = unpaid();
      await show(
        tester,
        FoodFormScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      );
      await tapLabel(tester, find.text('写真で登録'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('パーソナルコーチ（ホーム）', (tester) async {
      final controller = unpaid();
      prepareHome(controller);
      await show(
        tester,
        HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      );
      await tapLabel(tester, find.text('パーソナルコーチ (β)'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('パーソナルコーチ（設定）', (tester) async {
      final auth = _auth();
      final controller = AppController(authenticationRepository: auth);
      addTearDown(controller.dispose);
      await show(
        tester,
        SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          supportEmail: '',
        ),
      );
      await tapLabel(tester, find.text('パーソナルコーチ (β)'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('自炊コーチ', (tester) async {
      final controller = unpaid();
      await show(tester, CookCoachScreen(controller: controller, now: _now));
      await tapLabel(tester, find.text('カロナビ+を見る'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('直近3日の食品', (tester) async {
      final controller = unpaid();
      prepareHome(controller);
      await show(
        tester,
        HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      );
      await tapLabel(tester, find.text('直近3日の食品'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('食事テンプレートの作成', (tester) async {
      final auth = _auth();
      final meals = _MemoryMeals()..seedFour();
      final controller = AppController(
        authenticationRepository: auth,
        mealTemplateRepository: meals,
      );
      addTearDown(controller.dispose);
      await show(tester, MealTemplateListScreen(controller: controller));
      await tapLabel(tester, find.text('テンプレートを作成'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('運動テンプレートの作成', (tester) async {
      final auth = _auth();
      final workouts = _MemoryWorkouts()..seedFour();
      final controller = AppController(
        authenticationRepository: auth,
        workoutTemplateRepository: workouts,
      );
      addTearDown(controller.dispose);
      await show(tester, WorkoutTemplateListScreen(controller: controller));
      await tapLabel(tester, find.byIcon(Icons.add));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('ウィジェット', (tester) async {
      final auth = _auth();
      final controller = AppController(authenticationRepository: auth);
      addTearDown(controller.dispose);
      await show(
        tester,
        SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      );
      await tapLabel(tester, find.text('ウィジェット'));
      await expectDialogThenPaywall(tester);
    });

    testWidgets('音声登録', (tester) async {
      final auth = _auth();
      final controller = AppController(authenticationRepository: auth);
      addTearDown(controller.dispose);
      await show(
        tester,
        SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      );
      await tapLabel(tester, find.text('音声登録 (β)'));
      await expectDialogThenPaywall(tester);
    });
  });

  group('加入中は確認を出さず機能を開く', () {
    testWidgets('AIで探す', (tester) async {
      final controller = plus();
      await show(
        tester,
        MealFoodSearchScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
          aiLookup: _aiOk(),
        ),
      );
      await tester.enterText(find.byKey(const Key('meal-food-search-field')), '牛丼');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-food-lookup-empty')), findsOneWidget);
      await tapLabel(tester, find.text(AiFoodLookupRow.label));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.text('牛丼'), findsWidgets);
    });

    testWidgets('外食・コンビニ', (tester) async {
      final controller = plus();
      await show(tester, MealFoodSearchScreen(controller: controller));
      await tapLabel(tester, find.byKey(const Key('chain-food-lookup-row')));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.byKey(const Key('chain-food-lookup-field')), findsOneWidget);
    });

    testWidgets('写真で登録', (tester) async {
      final controller = plus();
      await show(
        tester,
        FoodFormScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      );
      await tapLabel(tester, find.text('写真で登録'));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.text('写真で登録 (β)'), findsOneWidget);
    });

    testWidgets('パーソナルコーチと自炊コーチ', (tester) async {
      final controller = plus();
      await show(
        tester,
        DailyCoachScreen(
          controller: controller,
          now: _now,
          introStore: _SeenIntro(),
        ),
      );
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.byKey(const Key('cook_coach_entry')), findsOneWidget);
      await tapLabel(tester, find.byKey(const Key('cook_coach_entry')));
      expect(find.text('自炊コーチ (β)'), findsOneWidget);
      expect(find.text('カロナビ+を見る'), findsNothing);
    });

    testWidgets('直近3日の食品', (tester) async {
      final controller = plus();
      prepareHome(controller);
      await show(
        tester,
        HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      );
      await tapLabel(tester, find.text('直近3日の食品'));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.text('直近3日に登録した食品はありません'), findsOneWidget);
    });

    testWidgets('食事テンプレートの作成', (tester) async {
      final auth = _auth();
      final controller = AppController(
        authenticationRepository: auth,
        subscriptionRepository: _GatePlus(active: true),
        mealTemplateRepository: _MemoryMeals()..seedFour(),
      );
      addTearDown(controller.dispose);
      await show(tester, MealTemplateListScreen(controller: controller));
      await tapLabel(tester, find.text('テンプレートを作成'));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.text('登録する食品'), findsOneWidget);
    });

    testWidgets('運動テンプレートの作成', (tester) async {
      final auth = _auth();
      final controller = AppController(
        authenticationRepository: auth,
        subscriptionRepository: _GatePlus(active: true),
        workoutTemplateRepository: _MemoryWorkouts()..seedFour(),
      );
      addTearDown(controller.dispose);
      await show(tester, WorkoutTemplateListScreen(controller: controller));
      await tapLabel(tester, find.byIcon(Icons.add));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.text('テンプレート作成'), findsOneWidget);
    });

    testWidgets('ウィジェットと音声登録', (tester) async {
      final auth = _auth();
      final controller = AppController(
        authenticationRepository: auth,
        subscriptionRepository: _GatePlus(active: true),
      );
      addTearDown(controller.dispose);
      await show(
        tester,
        SettingsScreen(
          controller: controller,
          authenticationRepository: auth,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: '',
        ),
      );
      await tapLabel(tester, find.text('ウィジェット'));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.textContaining('ウィジェットでワンタップ記録です'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tapLabel(tester, find.text('音声登録 (β)'));
      expect(find.text('こちらは有料の機能です'), findsNothing);
      expect(find.textContaining('Siriをオンにする'), findsOneWidget);
    });
  });

  group('ストアは有料でサーバが not_plus のときは同じ確認から復元へ', () {
    testWidgets('AIで探すは黙って同期し、拒否されたら課金画面', (tester) async {
      final gate = _GatePlus(active: true);
      final controller = AppController(subscriptionRepository: gate);
      addTearDown(controller.dispose);
      var calls = 0;
      await show(
        tester,
        MealFoodSearchScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
          aiLookup: _aiNotPlus(onCall: () => calls += 1),
        ),
      );
      await tester.enterText(find.byKey(const Key('meal-food-search-field')), '牛丼');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-food-lookup-empty')), findsOneWidget);
      await tapLabel(tester, find.text(AiFoodLookupRow.label));
      expect(gate.recovers, 1);
      expect(calls, 2);
      await expectDialogThenPaywall(tester);
    });

    testWidgets('外食・コンビニも同じ', (tester) async {
      final gate = _GatePlus(active: true);
      final controller = AppController(subscriptionRepository: gate);
      addTearDown(controller.dispose);
      await show(
        tester,
        ChainFoodLookupScreen(
          controller: controller,
          loggedAt: _now,
          client: _aiNotPlus(),
        ),
      );
      await tester.enterText(find.byKey(const Key('chain-food-lookup-field')), '吉野家 牛丼');
      await tester.pumpAndSettle();
      await tapLabel(tester, find.text('推定する'));
      expect(gate.recovers, 1);
      await expectDialogThenPaywall(tester);
    });

    testWidgets('写真で登録も同じ', (tester) async {
      final gate = _GatePlus(active: true);
      final controller = AppController(subscriptionRepository: gate);
      addTearDown(controller.dispose);
      await show(
        tester,
        PhotoMealScreen(
          controller: controller,
          loggedAt: _now,
          client: _photoNotPlus(),
          initialJpeg: _jpeg,
        ),
      );
      await tapLabel(tester, find.text('推定する'));
      expect(gate.recovers, 1);
      await expectDialogThenPaywall(tester);
    });

    testWidgets('自炊コーチも同じ', (tester) async {
      final gate = _GatePlus(active: true);
      final controller = AppController(subscriptionRepository: gate);
      addTearDown(controller.dispose);
      await show(
        tester,
        CookCoachScreen(
          controller: controller,
          now: _now,
          target: _cookTarget,
          client: _cookNotPlus(),
        ),
      );
      await tester.tap(find.byKey(const Key('cook_choice_卵')));
      await tester.pumpAndSettle();
      await tapLabel(tester, find.byKey(const Key('cook_generate')));
      expect(gate.recovers, 1);
      await expectDialogThenPaywall(tester);
    });
  });
}

final _now = DateTime(2026, 10, 8, 18);

const _cookTarget = CookCoachMealTarget(
  slot: MealSlot.dinner,
  kcal: 650,
  proteinG: 32,
  fatG: 18,
  carbG: 75,
  remainingKcal: 650,
  remainingProteinG: 32,
  remainingFatG: 18,
  remainingCarbG: 75,
);

/// 1x1 の JPEG。プレビューが例外を出さないため。
final Uint8List _jpeg = Uint8List.fromList(const [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, //
  0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, //
  0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, //
  0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, //
  0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, //
  0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, //
  0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, //
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x03, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, //
  0x7F, 0x00, 0xFF, 0xD9,
]);

MockAuthenticationRepository _auth() {
  final auth = MockAuthenticationRepository(
    currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
  );
  addTearDown(auth.dispose);
  return auth;
}

CombinedFoodSearchOverrides _emptySearch() {
  return CombinedFoodSearchOverrides(
    debounce: Duration.zero,
    searchSaved: (_) async => const [],
    searchOfficial: (_) async => const OfficialFoodSearchResult(matches: []),
    searchPublic: (_) async => const [],
  );
}

CombinedFoodSearchOverrides _hitSearch() {
  final now = _now;
  return CombinedFoodSearchOverrides(
    debounce: Duration.zero,
    searchSaved: (_) async => [
      SavedFood(
        foodId: 'saved-1',
        ownerUserId: 'user-1',
        name: 'おにぎり',
        normalizedName: 'おにぎり',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        servingUnitLabel: 'g',
        kcalPerBase: 168,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    searchOfficial: (_) async => const OfficialFoodSearchResult(matches: []),
    searchPublic: (_) async => const [],
  );
}

AiFoodLookupClient _aiOk() {
  return AiFoodLookupClient(
    invoke: (_) async => {
      'ok': true,
      'candidates': [
        {
          'name': '牛丼',
          'amount': '1人前',
          'kcal': 700,
          'protein_g': 20,
          'fat_g': 25,
          'carb_g': 90,
          'known_product': false,
        },
      ],
    },
  );
}

AiFoodLookupClient _aiNotPlus({void Function()? onCall}) {
  return AiFoodLookupClient(
    invoke: (_) async {
      try {
        return await PlusGateRetry.callOnce(() async {
          onCall?.call();
          throw const FunctionException(
            status: 403,
            details: {
              'code': 'not_plus',
              'message': 'こちらはカロナビ+の機能です。手入力で記録できます。',
            },
          );
        });
      } on FunctionException catch (error) {
        throw photoMealFailureFromBody(error.details);
      }
    },
  );
}

PhotoMealClient _photoNotPlus() {
  return PhotoMealClient(
    invoke: (_) async {
      try {
        return await PlusGateRetry.callOnce(() async {
          throw const FunctionException(
            status: 403,
            details: {
              'code': 'not_plus',
              'message': 'こちらはカロナビ+の機能です。手入力で記録できます。',
            },
          );
        });
      } on FunctionException catch (error) {
        throw photoMealFailureFromBody(error.details);
      }
    },
  );
}

CookCoachClient _cookNotPlus() {
  return CookCoachClient(
    invoke: (_) async {
      try {
        return await PlusGateRetry.callOnce(() async {
          throw const FunctionException(
            status: 403,
            details: {
              'code': 'not_plus',
              'message': 'こちらはカロナビ+の機能です。',
            },
          );
        });
      } on FunctionException catch (error) {
        throw CookCoachFailure(
          cookCoachMessageFromBody(error.details),
          code: cookCoachCodeFromBody(error.details),
        );
      }
    },
  );
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _GatePlus extends SubscriptionRepository {
  _GatePlus({required this.active});

  bool active;
  int recovers = 0;
  List<SubscriptionEntitlementRecord> confirmed = const [];

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => const Stream.empty();

  @override
  List<SubscriptionEntitlementRecord> get confirmedEntitlements => confirmed;

  @override
  Future<void> recoverMissingSignedTransactions({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    recovers += 1;
    confirmed = [
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: DateTime.utc(2099),
        signedTransaction: 'header.payload.sig',
      ),
    ];
  }

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return SubscriptionOfferings.failed;
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> refreshEntitlement() async {}

  @override
  Future<void> purchaseMonthly() async {}

  @override
  Future<void> purchaseYearly() async {}

  @override
  Future<void> purchasePlan(PlusPlan plan) async {}
}

class _MemoryMeals implements MealTemplateRepositoryBase {
  final List<MealTemplate> _templates = [];

  void seedFour() {
    for (var i = 0; i < 4; i++) {
      final now = DateTime(2026, 10, 8);
      _templates.add(
        MealTemplate(
          templateId: 'meal-$i',
          ownerUserId: 'user-1',
          name: '定食$i',
          normalizedName: '定食$i',
          totalKcal: 100,
          totalProteinG: 1,
          totalFatG: 1,
          totalCarbG: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async => [
    for (final template in _templates)
      if (template.ownerUserId == ownerUserId) template,
  ];

  @override
  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final all = await getAll(ownerUserId);
    if (query.trim().isEmpty) {
      return all;
    }
    return [
      for (final template in all)
        if (template.name.contains(query)) template,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryWorkouts implements WorkoutTemplateRepositoryBase {
  final List<WorkoutTemplate> _templates = [];

  void seedFour() {
    for (var i = 0; i < 4; i++) {
      final now = DateTime(2026, 10, 8);
      _templates.add(
        WorkoutTemplate(
          templateId: 'work-$i',
          ownerUserId: 'user-1',
          name: '運動$i',
          normalizedName: '運動$i',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  @override
  Future<List<WorkoutTemplate>> getAll(String ownerUserId) async => [
    for (final template in _templates)
      if (template.ownerUserId == ownerUserId) template,
  ];

  @override
  Future<List<WorkoutTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final all = await getAll(ownerUserId);
    if (query.trim().isEmpty) {
      return all;
    }
    return [
      for (final template in all)
        if (template.name.contains(query)) template,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
