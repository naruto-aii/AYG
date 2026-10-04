import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/review_prompt_store.dart';
import 'package:ayg/screens/review/store_review_request.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/review_prompt.dart';
import 'package:ayg/services/siri_voice_gateway.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/services/store_review.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Set<DateTime> daysEndingToday(int count) {
    final today = reviewDay(DateTime.now());
    return {
      for (var offset = 0; offset < count; offset++)
        today.subtract(Duration(days: offset)),
    };
  }

  test('a log completes the streak only on the seventh consecutive day', () {
    final now = DateTime.now();
    final six = daysEndingToday(6);
    final seven = daysEndingToday(7);
    expect(reviewCoversStreak(six, now), isFalse);
    expect(reviewCoversStreak(seven, now), isTrue);
    expect(
      reviewStreakJustCompleted(daysBefore: six, daysAfter: seven, now: now),
      isTrue,
    );
    expect(
      reviewStreakJustCompleted(daysBefore: seven, daysAfter: seven, now: now),
      isFalse,
    );

    final gapped = {...seven}
      ..remove(reviewDay(now).subtract(const Duration(days: 3)));
    expect(reviewCoversStreak(gapped, now), isFalse);
  });

  test('health weights are not records', () {
    final today = DateTime.now();
    final days = reviewLoggedDays(
      foodLoggedAts: const [],
      exerciseLoggedAts: const [],
      alcoholConsumedAts: const [],
      weightEntries: [
        WeightEntry(
          id: 'health',
          weightKg: 60,
          recordedAt: today,
          source: WeightSource.health,
        ),
        WeightEntry(
          id: 'manual',
          weightKg: 60,
          recordedAt: today.subtract(const Duration(days: 1)),
          source: WeightSource.manual,
        ),
      ],
    );
    expect(days, {reviewDay(today.subtract(const Duration(days: 1)))});
  });

  test('a decline is remembered and the review itself is not stored', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesReviewPromptStore(
      preferences: await SharedPreferences.getInstance(),
    );
    expect(await store.markDue(streak: true, external: false), isTrue);
    expect(await store.hasDue(), isTrue);
    expect(await store.markDue(streak: false, external: true), isFalse);
    await store.markDeclined();
    expect(await store.isClosed(), isTrue);
    expect(await store.hasDue(), isFalse);
    expect(await store.markDue(streak: true, external: true), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PreferencesReviewPromptStore.declinedKey), isTrue);
    expect(prefs.getKeys().any((key) => key.contains('rating')), isFalse);
    expect(prefs.getKeys().any((key) => key.contains('text')), isFalse);
  });

  test('seven food logs ask once, and a decline blocks the next one', () async {
    final store = _MemoryReviewPromptStore();
    final controller = AppController(reviewPromptStore: store);
    final today = reviewDay(DateTime.now());
    for (var offset = 6; offset >= 1; offset--) {
      await controller.addFood(
        FoodEntry(
          id: 'food-$offset',
          name: 'ごはん',
          kcalPerBase: 100,
          loggedAt: today.subtract(Duration(days: offset)),
        ),
      );
    }
    expect(store.streakDue, isFalse);
    expect(controller.reviewPromptTick.value, 0);

    await controller.addFood(
      FoodEntry(id: 'food-0', name: 'ごはん', kcalPerBase: 100, loggedAt: today),
    );
    expect(store.streakDue, isTrue);
    expect(store.externalDue, isFalse);
    expect(controller.reviewPromptTick.value, 1);

    await controller.addFood(
      FoodEntry(
        id: 'food-again',
        name: 'ごはん',
        kcalPerBase: 100,
        loggedAt: today.add(const Duration(hours: 1)),
      ),
    );
    expect(controller.reviewPromptTick.value, 1);

    await store.markDeclined();
    final later = AppController(reviewPromptStore: store);
    for (var offset = 6; offset >= 0; offset--) {
      await later.addFood(
        FoodEntry(
          id: 'later-$offset',
          name: 'ごはん',
          kcalPerBase: 100,
          loggedAt: today.subtract(Duration(days: offset)),
        ),
      );
    }
    expect(later.reviewPromptTick.value, 0);
    expect(store.streakDue, isFalse);
  });

  test('a widget registration asks on the next open, once', () async {
    final store = _MemoryReviewPromptStore();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final loggedAt = DateTime.now();
    final meal = PendingLockScreenMeal(
      registrationId: 'reg-1',
      ownerUserId: 'user-1',
      slot: 0,
      templateId: 'template',
      mealGroupId: 'group',
      mealGroupName: '朝',
      loggedAt: loggedAt,
      surface: 'home',
      entries: [
        FoodEntry(
          id: 'widget-food',
          name: 'ごはん',
          kcalPerBase: 100,
          loggedAt: loggedAt,
        ),
      ],
    );
    final gateway = _MealGateway([meal]);
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      reviewPromptStore: store,
    );

    await controller.syncLockScreenMeals();

    expect(controller.foodEntries, hasLength(1));
    expect(store.externalDue, isTrue);
    expect(controller.reviewPromptTick.value, 1);

    await controller.syncLockScreenMeals();
    expect(controller.reviewPromptTick.value, 1);
    await auth.dispose();
  });

  test('a Siri registration asks on the next open', () async {
    final store = _MemoryReviewPromptStore();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final food = FoodEntry(
      id: 'siri-food',
      name: '鶏むね',
      kcalPerBase: 100,
      loggedAt: DateTime.now(),
    );
    final gateway = _SiriGateway(
      SiriVoiceCodec.encodePending(ownerUserId: 'user-1', food: food),
    );
    final controller = AppController(
      authenticationRepository: auth,
      siriVoiceGateway: gateway,
      reviewPromptStore: store,
    );

    await controller.syncSiriVoiceLogs();

    expect(controller.foodEntries, hasLength(1));
    expect(store.externalDue, isTrue);
    expect(store.streakDue, isFalse);
    expect(controller.reviewPromptTick.value, 1);
    await auth.dispose();
  });

  testWidgets('declining never shows the request again', (tester) async {
    final store = _MemoryReviewPromptStore()..externalDue = true;
    final requester = _CountingReview();
    await _openPrompt(tester, store: store, requester: requester);

    expect(find.text('レビューをお願いできますか'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('断る'));
    await tester.pumpAndSettle();

    expect(store.declined, isTrue);
    expect(store.asked, isFalse);
    expect(requester.calls, 0);
    expect(find.byType(AlertDialog), findsNothing);

    store.externalDue = true;
    await _openPrompt(tester, store: store, requester: requester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(requester.calls, 0);
  });

  testWidgets('accepting opens the store review and does not ask again', (
    tester,
  ) async {
    final store = _MemoryReviewPromptStore()..streakDue = true;
    final requester = _CountingReview();
    await _openPrompt(tester, store: store, requester: requester);

    await tester.tap(find.text('レビューする'));
    await tester.pumpAndSettle();

    expect(store.asked, isTrue);
    expect(store.declined, isFalse);
    expect(requester.calls, 1);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('レビューをお願いできますか'), findsNothing);

    store.streakDue = true;
    store.externalDue = true;
    await _openPrompt(tester, store: store, requester: requester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(requester.calls, 1);
  });

  test('a Siri exercise registration is an external record', () async {
    final store = _MemoryReviewPromptStore();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final exercise = ExerciseEntry(
      id: 'siri-run',
      name: 'ランニング',
      activityId: 'running',
      durationMin: 20,
      distanceKm: 2,
      burnedKcal: 120,
      weightKgSnapshot: 60,
      loggedAt: DateTime.now(),
    );
    final gateway = _SiriGateway(
      SiriVoiceCodec.encodePending(
        ownerUserId: 'user-1',
        exercise: exercise,
        weightKg: 60,
      ),
    );
    final controller = AppController(
      authenticationRepository: auth,
      siriVoiceGateway: gateway,
      reviewPromptStore: store,
    );

    await controller.syncSiriVoiceLogs();

    expect(controller.exerciseEntries, hasLength(1));
    expect(store.externalDue, isTrue);
    await auth.dispose();
  });
}

Future<void> _openPrompt(
  WidgetTester tester, {
  required _MemoryReviewPromptStore store,
  required StoreReviewRequester requester,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () {
              presentStoreReviewRequest(
                context: context,
                store: store,
                requester: requester,
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _CountingReview implements StoreReviewRequester {
  int calls = 0;

  @override
  Future<void> request() async {
    calls++;
  }
}

class _MemoryReviewPromptStore implements ReviewPromptStore {
  bool declined = false;
  bool asked = false;
  bool streakDue = false;
  bool externalDue = false;

  bool get closed => declined || asked;

  @override
  Future<bool> isClosed() async => closed;

  @override
  Future<bool> hasDue() async => !closed && (streakDue || externalDue);

  @override
  Future<bool> markDue({required bool streak, required bool external}) async {
    if (closed || (!streak && !external)) {
      return false;
    }
    final wasDue = streakDue || externalDue;
    if (streak) {
      streakDue = true;
    }
    if (external) {
      externalDue = true;
    }
    return !wasDue;
  }

  @override
  Future<void> markDeclined() async {
    declined = true;
    streakDue = false;
    externalDue = false;
  }

  @override
  Future<void> markAsked() async {
    asked = true;
    streakDue = false;
    externalDue = false;
  }
}

class _MealGateway implements LockScreenMealGateway {
  _MealGateway(this.pending);

  List<PendingLockScreenMeal> pending;
  final List<String> acknowledged = [];

  @override
  Future<void> acknowledge(List<String> registrationIds) async {
    acknowledged.addAll(registrationIds);
    pending = [
      for (final meal in pending)
        if (!registrationIds.contains(meal.registrationId)) meal,
    ];
  }

  @override
  Future<bool> isPaid() async => true;

  @override
  Future<LockScreenMealConfig> loadConfig() async {
    return LockScreenMealConfig.defaults();
  }

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async => pending;

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {}

  @override
  Future<void> setPaid(bool isPaid) async {}
}

class _SiriGateway implements SiriVoiceGateway {
  _SiriGateway(this.pending);

  String pending;

  @override
  Future<void> acknowledge(List<String> ids) async {
    pending = '[]';
  }

  @override
  Future<void> publishCatalog(String catalogJson) async {}

  @override
  Future<String> readPending() async => pending;
}
