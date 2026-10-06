import 'package:ayg/services/usage_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3, 4);

  test('entitlement status follows expiry and a revocation stays inactive', () {
    expect(
      statusForEntitlement(
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
        inactive: false,
      ),
      UsageEntitlementStatus.active,
    );
    expect(
      statusForEntitlement(
        expiresAt: now.subtract(const Duration(minutes: 1)),
        now: now,
        inactive: false,
      ),
      UsageEntitlementStatus.expired,
    );
    expect(
      statusForEntitlement(
        expiresAt: now.add(const Duration(days: 30)),
        now: now,
        inactive: true,
      ),
      UsageEntitlementStatus.inactive,
    );
    expect(
      statusForEntitlement(expiresAt: null, now: now, inactive: false),
      UsageEntitlementStatus.inactive,
    );
  });

  test('purchase payload has product, expiry, and status, not a receipt', () {
    final payload = plusEntitlementPayload(
      userId: 'user-1',
      productId: 'calonavi_plus_yearly',
      expiresAt: now,
      status: UsageEntitlementStatus.active,
    );
    expect(payload.keys.toList(), plusEntitlementColumns);
    expect(payload['advertising_use'], isFalse);
    expect(payload.containsKey('receipt'), isFalse);
    expect(payload.containsKey('purchaseToken'), isFalse);
    expect(payload.containsKey('verificationData'), isFalse);
  });

  test('search text is capped and unknown sources are refused', () {
    expect(capUsageQuery('  ごはん  '), 'ごはん');
    expect(capUsageQuery(''), isEmpty);
    expect(capUsageQuery('あ' * 300).runes.length, usageQueryMaxLength);
    expect(foodSearchSourceAllowed(FoodSearchSources.officialFood), isTrue);
    expect(foodSearchSourceAllowed('health_weight'), isFalse);
    expect(exerciseSearchSourceAllowed(ExerciseSearchSources.catalog), isTrue);
    expect(exerciseSearchSourceAllowed(FoodSearchSources.savedFood), isFalse);
  });

  test('screen actions stay on screens the app already opens', () {
    expect(
      screenActionAllowed(
        screen: UsageScreen.home,
        action: UsageScreenAction.open,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.weight,
        action: UsageScreenAction.select,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.firstMealGuide,
        action: UsageScreenAction.open,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.lockScreen,
        action: UsageScreenAction.mealButton,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.home,
        action: UsageScreenAction.shareMeal,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.home,
        action: UsageScreenAction.shareStreak,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.weight,
        action: UsageScreenAction.shareWeight,
      ),
      isTrue,
    );
    expect(
      screenActionAllowed(
        screen: UsageScreen.weight,
        action: UsageScreenAction.shareMeal,
      ),
      isFalse,
    );
    expect(
      screenActionAllowed(screen: UsageScreen.home, action: 'kcal'),
      isFalse,
    );
    expect(
      screenActionAllowed(screen: UsageScreen.home, action: 'share_meal_1800'),
      isFalse,
    );
    expect(
      screenActionAllowed(screen: 'health_snapshot', action: 'open'),
      isFalse,
    );
    expect(widgetSurfaceAction('home')?.screen, UsageScreen.homeWidget);
    expect(widgetSurfaceAction('lock')?.action, UsageScreenAction.mealButton);
    expect(widgetSurfaceAction('health'), isNull);
    expect(widgetSurfaceAction(null), isNull);
  });
}
