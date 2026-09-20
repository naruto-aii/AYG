import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/local_subscription_usage_store.dart';
import 'package:ayg/services/subscription_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SubscriptionPolicy();

  test('free users can search five times a day', () {
    expect(
      policy.canSearchPublicFood(isPlus: false, usedToday: 4),
      isTrue,
    );
    expect(
      policy.canSearchPublicFood(isPlus: false, usedToday: 5),
      isFalse,
    );
    expect(
      policy.canSearchPublicFood(isPlus: true, usedToday: 20),
      isTrue,
    );
  });

  test('free users can keep three templates', () {
    expect(
      policy.canCreateMealTemplate(isPlus: false, currentCount: 2),
      isTrue,
    );
    expect(
      policy.canCreateMealTemplate(isPlus: false, currentCount: 3),
      isFalse,
    );
    expect(
      policy.canCreateWorkoutTemplate(isPlus: false, currentCount: 3),
      isFalse,
    );
  });

  test('catalog matches the locked prices and limits', () {
    expect(SubscriptionCatalog.monthlyYen, 380);
    expect(SubscriptionCatalog.yearlyYen, 4180);
    expect(SubscriptionCatalog.publicFoodSearchesPerDay, 5);
    expect(SubscriptionCatalog.mealTemplateLimit, 3);
    expect(SubscriptionCatalog.workoutTemplateLimit, 3);
  });

  test('usage store counts searches per user and day', () async {
    final store = LocalSubscriptionUsageStore();
    final day = DateTime(2026, 9, 20, 15);
    expect(await store.publicSearchCount(userId: 'u1', day: day), 0);
    expect(await store.incrementPublicSearch(userId: 'u1', day: day), 1);
    expect(await store.incrementPublicSearch(userId: 'u1', day: day), 2);
    expect(await store.publicSearchCount(userId: 'u2', day: day), 0);
    expect(
      await store.publicSearchCount(userId: 'u1', day: DateTime(2026, 9, 21)),
      0,
    );
  });
}
