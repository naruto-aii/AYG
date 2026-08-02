import '../models/calculation/goal_pace.dart';
import '../models/goal.dart';
import '../models/weight_entry.dart';

/// 14〜28 日の体重推移から調整候補を算出する純粋サービス。
/// ユーザー確認なしの自動適用は行わない。
class WeightTrendSuggestionService {
  const WeightTrendSuggestionService();

  static const minWindowDays = 14;
  static const maxWindowDays = 28;

  /// 体重記録が十分にある場合、目標ペース見直しの提案を返す。
  WeightTrendSuggestion? suggest({
    required List<WeightEntry> weightEntries,
    required Goal goal,
    required GoalPace currentPace,
    DateTime? referenceDate,
  }) {
    if (goal.type == GoalType.maintain) {
      return null;
    }

    final now = referenceDate ?? DateTime.now();
    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: maxWindowDays));

    final recent =
        weightEntries
            .where((entry) => !entry.recordedAt.isBefore(windowStart))
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (recent.length < 2) {
      return null;
    }

    final spanDays = recent.last.recordedAt
        .difference(recent.first.recordedAt)
        .inDays;
    if (spanDays < minWindowDays) {
      return null;
    }

    final deltaKg = recent.last.weightKg - recent.first.weightKg;
    final expectedDirection = switch (goal.type) {
      GoalType.lose => -1,
      GoalType.gain => 1,
      GoalType.maintain => 0,
    };
    final actualDirection = deltaKg == 0 ? 0 : (deltaKg > 0 ? 1 : -1);

    if (expectedDirection == 0 || actualDirection == expectedDirection) {
      return null;
    }

    final suggestedPace = currentPace == GoalPace.standard
        ? GoalPace.slow
        : GoalPace.slow;

    return WeightTrendSuggestion(
      observedDeltaKg: deltaKg,
      windowDays: spanDays,
      currentPace: currentPace,
      suggestedPace: suggestedPace,
      message:
          '直近${spanDays}日の体重推移（${deltaKg >= 0 ? '+' : ''}'
          '${deltaKg.toStringAsFixed(1)} kg）から、'
          '目標ペースの見直し候補があります。'
          '自動では変更しません。設定画面でご確認ください。',
    );
  }
}

class WeightTrendSuggestion {
  const WeightTrendSuggestion({
    required this.observedDeltaKg,
    required this.windowDays,
    required this.currentPace,
    required this.suggestedPace,
    required this.message,
  });

  final double observedDeltaKg;
  final int windowDays;
  final GoalPace currentPace;
  final GoalPace suggestedPace;
  final String message;
}
