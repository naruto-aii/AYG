import '../models/food_entry.dart';
import '../models/food_unit_type.dart';
import '../utils/food_search_normalizer.dart';
import '../utils/local_date.dart';
import '../utils/record_clock.dart';

/// 直近3日（今日を含む）に登録した食品。同じ食品は最新の1件だけ。
class RecentFood {
  const RecentFood(this.latest);

  final FoodEntry latest;
}

const recentFoodWindowDays = 3;

String recentFoodKey(FoodEntry entry) {
  final code = entry.officialFoodCode?.trim();
  if (code != null && code.isNotEmpty) {
    return 'code:$code';
  }
  final saved = entry.savedFoodId?.trim();
  if (saved != null && saved.isNotEmpty) {
    final owner = entry.sourceFoodOwnerUserId?.trim() ?? '';
    return 'saved:$owner:$saved';
  }
  return 'name:${FoodSearchNormalizer.normalize(entry.name)}';
}

bool foodLoggedWithinRecentWindow(DateTime loggedAt, DateTime now) {
  final start = localDayStart(
    civilClock(now),
  ).subtract(const Duration(days: recentFoodWindowDays - 1));
  final day = localDayStart(civilClock(loggedAt));
  return !day.isBefore(start);
}

List<RecentFood> recentFoods(List<FoodEntry> entries, DateTime now) {
  final latestByKey = <String, FoodEntry>{};
  for (final entry in entries) {
    if (!foodLoggedWithinRecentWindow(entry.loggedAt, now)) {
      continue;
    }
    final key = recentFoodKey(entry);
    final current = latestByKey[key];
    if (current == null ||
        compareRecordInstants(entry.loggedAt, current.loggedAt) > 0) {
      latestByKey[key] = entry;
    }
  }
  final foods = latestByKey.values.map(RecentFood.new).toList()
    ..sort(
      (a, b) => compareRecordInstants(b.latest.loggedAt, a.latest.loggedAt),
    );
  return foods;
}

String formatFoodAmount(FoodEntry entry) {
  final amount = entry.consumedAmount;
  final text = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1);
  return '$text${entry.unitType.label}';
}
