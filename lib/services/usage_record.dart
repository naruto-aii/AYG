// 端末がすでに受け取っている行動を、用途ごとの表へ書くときの形。
// ヘルスケアの測定値（体重、消費カロリー、性別など）は列にしない。
// advertising_use は常に false で、広告利用の印は付けられない。

const usageQueryMaxLength = 256;

abstract final class FoodSearchSources {
  static const officialFood = 'official_food';
  static const publicFood = 'public_food';
  static const savedFood = 'saved_food';
  static const mealTemplate = 'meal_template';

  static const all = <String>{
    officialFood,
    publicFood,
    savedFood,
    mealTemplate,
  };
}

abstract final class ExerciseSearchSources {
  static const catalog = 'exercise_catalog';
  static const workoutTemplate = 'workout_template';

  static const all = <String>{catalog, workoutTemplate};
}

abstract final class UsageScreen {
  static const home = 'home';
  static const food = 'food';
  static const workout = 'workout';
  static const weight = 'weight';
  static const settings = 'settings';
  static const firstMealGuide = 'first_meal_guide';
  static const homeWidget = 'home_widget';
  static const lockScreen = 'lock_screen';
}

abstract final class UsageScreenAction {
  static const open = 'open';
  static const select = 'select';
  static const mealButton = 'meal_button';
  static const shareMeal = 'share_meal';
}

abstract final class UsageEntitlementStatus {
  static const active = 'active';
  static const expired = 'expired';
  static const inactive = 'inactive';
}

const plusEntitlementColumns = <String>[
  'user_id',
  'product_id',
  'expires_at',
  'status',
  'advertising_use',
];

String capUsageQuery(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final units = <int>[];
  for (final rune in trimmed.runes) {
    if (units.length == usageQueryMaxLength) {
      return String.fromCharCodes(units);
    }
    units.add(rune);
  }
  return trimmed;
}

bool foodSearchSourceAllowed(String source) {
  return FoodSearchSources.all.contains(source);
}

bool exerciseSearchSourceAllowed(String source) {
  return ExerciseSearchSources.all.contains(source);
}

bool screenActionAllowed({required String screen, required String action}) {
  if (screen == UsageScreen.home && action == UsageScreenAction.shareMeal) {
    return true;
  }
  if (screen == UsageScreen.homeWidget || screen == UsageScreen.lockScreen) {
    return action == UsageScreenAction.mealButton;
  }
  if (screen == UsageScreen.firstMealGuide) {
    return action == UsageScreenAction.open;
  }
  const tabs = {
    UsageScreen.home,
    UsageScreen.food,
    UsageScreen.workout,
    UsageScreen.weight,
    UsageScreen.settings,
  };
  if (!tabs.contains(screen)) {
    return false;
  }
  return action == UsageScreenAction.open || action == UsageScreenAction.select;
}

/// ウィジェットが pending に書く `surface`。食事の中身は返さない。
({String screen, String action})? widgetSurfaceAction(String? surface) {
  return switch (surface) {
    'home' => (
      screen: UsageScreen.homeWidget,
      action: UsageScreenAction.mealButton,
    ),
    'lock' => (
      screen: UsageScreen.lockScreen,
      action: UsageScreenAction.mealButton,
    ),
    _ => null,
  };
}

/// 取り消した加入は期限が未来でも inactive。通常の加入は期限と現在時刻で決める。
String statusForEntitlement({
  required DateTime? expiresAt,
  required DateTime now,
  required bool inactive,
}) {
  if (inactive || expiresAt == null) {
    return UsageEntitlementStatus.inactive;
  }
  if (expiresAt.isAfter(now)) {
    return UsageEntitlementStatus.active;
  }
  return UsageEntitlementStatus.expired;
}

Map<String, dynamic> plusEntitlementPayload({
  required String userId,
  required String productId,
  required DateTime? expiresAt,
  required String status,
}) {
  return {
    'user_id': userId,
    'product_id': productId,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'status': status,
    'advertising_use': false,
  };
}
