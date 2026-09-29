import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/services/weight_trend_suggestion_service.dart';

void main() {
  const service = WeightTrendSuggestionService();

  group('WeightTrendSuggestionService', () {
    test('returns null for maintain goal', () {
      final suggestion = service.suggest(
        weightEntries: [
          WeightEntry(
            id: '1',
            weightKg: 70,
            recordedAt: DateTime(2026, 7, 1),
            source: WeightSource.manual,
          ),
          WeightEntry(
            id: '2',
            weightKg: 71,
            recordedAt: DateTime(2026, 7, 20),
            source: WeightSource.manual,
          ),
        ],
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: DateTime(2026, 12, 31),
        ),
        currentPace: GoalPace.standard,
        referenceDate: DateTime(2026, 7, 21),
      );

      expect(suggestion, isNull);
    });

    test('suggests review when lose goal but weight increased', () {
      final suggestion = service.suggest(
        weightEntries: [
          WeightEntry(
            id: '1',
            weightKg: 72,
            recordedAt: DateTime(2026, 7, 1),
            source: WeightSource.manual,
          ),
          WeightEntry(
            id: '2',
            weightKg: 73,
            recordedAt: DateTime(2026, 7, 18),
            source: WeightSource.manual,
          ),
        ],
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 68,
          targetDate: DateTime(2026, 12, 31),
          goalPace: GoalPace.standard,
        ),
        currentPace: GoalPace.standard,
        referenceDate: DateTime(2026, 7, 21),
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.suggestedPace, GoalPace.slow);
      expect(suggestion.message, contains('自動では変更しません'));
    });
  });
}
