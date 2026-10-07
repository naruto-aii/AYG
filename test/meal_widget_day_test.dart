import 'dart:convert';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const yesterdayFigures = MealWidgetFigures(
    remainingKcal: 0,
    intakeKcal: 2300,
    burnKcal: 0,
    targetKcal: 2000,
    overageKcal: 300,
    day: '2026-10-07',
  );
  final afterMidnight = DateTime(2026, 10, 8, 0, 10);
  final lateYesterday = DateTime(2026, 10, 7, 23, 50);

  group('mealWidgetDayKey', () {
    test('is the local calendar date with zero padding', () {
      expect(mealWidgetDayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(mealWidgetDayKey(DateTime(2026, 10, 8)), '2026-10-08');
    });
  });

  group('snapshot json', () {
    test('writes the day next to the figures', () {
      final raw = LockScreenMealCodec.encodeSnapshot(
        const LockScreenMealSnapshot(
          ownerUserId: 'user-1',
          homeButtons: [],
          lockButtons: [],
          figures: MealWidgetFigures(
            remainingKcal: 1200,
            intakeKcal: 800,
            burnKcal: 0,
            targetKcal: 2000,
            day: '2026-10-08',
          ),
        ),
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['day'], '2026-10-08');
      expect(json['target'], 2000);
    });

    test('leaves the day out when there are no figures', () {
      final raw = LockScreenMealCodec.encodeSnapshot(
        const LockScreenMealSnapshot(
          ownerUserId: 'user-1',
          homeButtons: [],
          lockButtons: [],
        ),
      );
      expect((jsonDecode(raw) as Map).containsKey('day'), isFalse);
    });
  });

  group('mealWidgetFiguresForToday', () {
    test('same day keeps the stored numbers', () {
      final kept = mealWidgetFiguresForToday(
        yesterdayFigures,
        now: lateYesterday,
      );
      expect(kept, same(yesterdayFigures));
    });

    test('a new day shows 0 eaten, the target left, and an empty ring', () {
      final fresh = mealWidgetFiguresForToday(
        yesterdayFigures,
        now: afterMidnight,
      );
      expect(fresh.day, '2026-10-08');
      expect(fresh.intakeKcal, 0);
      expect(fresh.burnKcal, 0);
      expect(fresh.remainingKcal, 2000);
      expect(fresh.targetKcal, 2000);
      expect(fresh.overageKcal, isNull);
      expect(fresh.ringProgress, 0);
    });

    test('old data without a day keeps the current behavior', () {
      const old = MealWidgetFigures(
        remainingKcal: 0,
        intakeKcal: 2300,
        targetKcal: 2000,
        overageKcal: 300,
      );
      expect(mealWidgetFiguresForToday(old, now: afterMidnight), same(old));
    });

    test('target 0 starts at 0 left; no target leaves it unknown', () {
      final zero = mealWidgetFiguresForToday(
        const MealWidgetFigures(
          remainingKcal: 0,
          intakeKcal: 500,
          targetKcal: 0,
          overageKcal: 500,
          day: '2026-10-07',
        ),
        now: afterMidnight,
      );
      expect(zero.remainingKcal, 0);
      expect(zero.overageKcal, isNull);
      final unknown = mealWidgetFiguresForToday(
        const MealWidgetFigures(day: '2026-10-07'),
        now: afterMidnight,
      );
      expect(unknown.remainingKcal, isNull);
      expect(unknown.intakeKcal, 0);
    });
  });

  group('button presses across midnight', () {
    test('after midnight a press starts from 0 instead of yesterday', () {
      final next = applyMealWidgetFigures(
        figures: yesterdayFigures,
        intakeDelta: 400,
        burnDelta: 0,
        now: afterMidnight,
      );
      expect(next.day, '2026-10-08');
      expect(next.intakeKcal, 400);
      expect(next.burnKcal, 0);
      expect(next.remainingKcal, 1600);
      expect(next.overageKcal, isNull);
      expect(next.ringProgress, closeTo(0.2, 1e-12));
    });

    test('an exercise press after midnight also starts from 0', () {
      final next = applyMealWidgetFigures(
        figures: yesterdayFigures,
        intakeDelta: 0,
        burnDelta: 250,
        now: afterMidnight,
      );
      expect(next.intakeKcal, 0);
      expect(next.burnKcal, 250);
      expect(next.remainingKcal, 2250);
    });

    test('a second press the same new day adds on', () {
      final first = applyMealWidgetFigures(
        figures: yesterdayFigures,
        intakeDelta: 400,
        burnDelta: 0,
        now: afterMidnight,
      );
      final second = applyMealWidgetFigures(
        figures: first,
        intakeDelta: 300,
        burnDelta: 0,
        now: afterMidnight.add(const Duration(hours: 8)),
      );
      expect(second.intakeKcal, 700);
      expect(second.remainingKcal, 1300);
      expect(second.day, '2026-10-08');
    });

    test('before midnight it still adds onto the same day', () {
      final next = applyMealWidgetFigures(
        figures: const MealWidgetFigures(
          remainingKcal: 500,
          intakeKcal: 1500,
          burnKcal: 0,
          targetKcal: 2000,
          day: '2026-10-07',
        ),
        intakeDelta: 200,
        burnDelta: 0,
        now: lateYesterday,
      );
      expect(next.intakeKcal, 1700);
      expect(next.remainingKcal, 300);
      expect(next.day, '2026-10-07');
    });

    test('undoing a record from yesterday does not move today', () {
      final next = applyMealWidgetFigures(
        figures: yesterdayFigures,
        intakeDelta: -500,
        burnDelta: 0,
        now: afterMidnight,
      );
      expect(next.intakeKcal, 0);
      expect(next.remainingKcal, 2000);
      expect(next.day, '2026-10-08');
    });

    test('old data without a day keeps adding like before', () {
      final next = applyMealWidgetFigures(
        figures: const MealWidgetFigures(
          remainingKcal: 500,
          intakeKcal: 1500,
          targetKcal: 2000,
        ),
        intakeDelta: 200,
        burnDelta: 0,
        now: afterMidnight,
      );
      expect(next.intakeKcal, 1700);
      expect(next.remainingKcal, 300);
      expect(next.day, isNull);
    });
  });

  group('import of widget presses', () {
    // Swift の LockScreenMealButton.makePendingRecord と同じ形。
    String pendingJson(String id, String loggedAt) => jsonEncode([
      {
        'registrationId': id,
        'ownerUserId': 'user-1',
        'slot': 0,
        'kind': 'meal',
        'templateId': 'widget-meal-0',
        'mealGroupId': 'group-$id',
        'mealGroupName': '朝',
        'loggedAt': loggedAt,
        'surface': 'home',
        'items': [
          {
            'id': 'item-$id',
            'name': 'ご飯',
            'baseAmount': 100,
            'consumedAmount': 150,
            'kcalPerBase': 168,
            'unitType': 'g',
          },
        ],
      },
    ]);

    test('each record keeps its own press time across midnight', () {
      final before = LockScreenMealCodec.decodePending(
        pendingJson('a', '2026-10-07T23:50:00.000'),
      ).single;
      final after = LockScreenMealCodec.decodePending(
        pendingJson('b', '2026-10-08T00:10:00.000'),
      ).single;
      final plan = planLockScreenMealImport(
        pending: [before, after],
        ownerUserId: 'user-1',
        existingEntryIds: const {},
      );
      expect(plan.entries.map((entry) => entry.loggedAt), [
        lateYesterday,
        afterMidnight,
      ]);
    });

    test('the controller files them on their own days', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 0, 10);
      final yesterday = today.subtract(const Duration(minutes: 20));
      String wall(DateTime value) => formatLockScreenLoggedAt(value);
      final gateway = _MemoryGateway(
        pending: [
          ...LockScreenMealCodec.decodePending(
            pendingJson('y', wall(yesterday)),
          ),
          ...LockScreenMealCodec.decodePending(pendingJson('t', wall(today))),
        ],
      );
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final controller = AppController(
        authenticationRepository: auth,
        lockScreenMealGateway: gateway,
        healthRepository: MockHealthRepository(isAvailable: false),
      );

      await controller.syncLockScreenMeals();

      final byId = {
        for (final FoodEntry entry in controller.foodEntries) entry.id: entry,
      };
      expect(byId['item-y']!.loggedAt, yesterday);
      expect(byId['item-t']!.loggedAt, today);
      await auth.dispose();
    });
  });

  test('the app writes today as the day of the widget figures', () async {
    final gateway = _MemoryGateway();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      lockScreenMealGateway: gateway,
    );
    final now = DateTime.now();
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
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
        targetWeightKg: 75,
        targetDate: now.add(const Duration(days: 90)),
      ),
    );
    await controller.publishLockScreenMealSnapshot();

    final figures = gateway.published!.figures;
    expect(controller.summary, isNotNull);
    expect(figures.day, mealWidgetDayKey(DateTime.now()));
    expect(figures.targetKcal, controller.summary!.targetKcal.round());
    expect(figures.intakeKcal, 0);
    final json =
        jsonDecode(LockScreenMealCodec.encodeSnapshot(gateway.published!))
            as Map<String, dynamic>;
    expect(json['day'], mealWidgetDayKey(DateTime.now()));
  });
}

class _MemoryGateway implements LockScreenMealGateway {
  _MemoryGateway({List<PendingLockScreenMeal>? pending})
    : pending = pending ?? [];

  LockScreenMealConfig config = LockScreenMealConfig.defaults();
  bool paid = false;
  List<PendingLockScreenMeal> pending;
  LockScreenMealSnapshot? published;

  @override
  Future<void> acknowledge(List<String> registrationIds) async {
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
    this.config = config;
  }

  @override
  Future<void> setPaid(bool isPaid) async {
    paid = isPaid;
  }
}
