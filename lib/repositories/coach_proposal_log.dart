import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/daily_coach_session.dart';
import '../utils/id_generator.dart';

/// 今日のコーチが出した提案と、それを登録したか。
///
/// Good/Bad は付けない。表計算への定期反映もしない。保存だけ。
class CoachShownFood {
  const CoachShownFood({
    required this.code,
    required this.name,
    required this.units,
    required this.grams,
  });

  final String code;
  final String name;
  final int units;
  final int grams;

  Map<String, Object?> toJson() {
    return {'code': code, 'name': name, 'units': units, 'grams': grams};
  }
}

class CoachShownMeal {
  const CoachShownMeal({
    required this.position,
    required this.headline,
    required this.kcal,
    required this.foods,
  });

  final int position;
  final String headline;
  final double kcal;
  final List<CoachShownFood> foods;

  Map<String, Object?> toJson() {
    return {
      'position': position,
      'headline': headline,
      'kcal': kcal,
      'foods': [for (final food in foods) food.toJson()],
    };
  }
}

class CoachProposalSnapshot {
  const CoachProposalSnapshot({
    required this.id,
    required this.localDate,
    required this.shownAt,
    required this.meals,
    this.exerciseMessage,
    this.registeredPosition,
  });

  final String id;
  final String localDate;
  final DateTime shownAt;
  final List<CoachShownMeal> meals;
  final String? exerciseMessage;
  final int? registeredPosition;

  factory CoachProposalSnapshot.shown({
    required DateTime now,
    required DailyCoachLoadResult result,
    String? id,
  }) {
    final meals = <CoachShownMeal>[];
    for (var i = 0; i < result.meals.length && i < 3; i++) {
      final meal = result.meals[i];
      meals.add(
        CoachShownMeal(
          position: i + 1,
          headline: meal.headline,
          kcal: meal.kcal,
          foods: [
            for (final item in meal.components)
              CoachShownFood(
                code: item.foodCode,
                name: item.displayName,
                units: item.units,
                grams: item.grams,
              ),
          ],
        ),
      );
    }
    final exercise = result.exerciseMessage?.trim();
    return CoachProposalSnapshot(
      id: id ?? generateUniqueId(),
      localDate:
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      shownAt: now,
      meals: meals,
      exerciseMessage: exercise == null || exercise.isEmpty ? null : exercise,
    );
  }

  CoachProposalSnapshot copyWithRegistered(int position) {
    return CoachProposalSnapshot(
      id: id,
      localDate: localDate,
      shownAt: shownAt,
      meals: meals,
      exerciseMessage: exerciseMessage,
      registeredPosition: position,
    );
  }

  List<Map<String, Object?>> get mealsJson => [
    for (final meal in meals) meal.toJson(),
  ];
}

abstract class CoachProposalLog {
  Future<void> recordShown(CoachProposalSnapshot snapshot);

  Future<void> markRegistered({required String id, required int position});
}

class NoOpCoachProposalLog implements CoachProposalLog {
  const NoOpCoachProposalLog();

  @override
  Future<void> recordShown(CoachProposalSnapshot snapshot) async {}

  @override
  Future<void> markRegistered({required String id, required int position}) async {}
}

class MemoryCoachProposalLog implements CoachProposalLog {
  final List<CoachProposalSnapshot> records = [];

  @override
  Future<void> recordShown(CoachProposalSnapshot snapshot) async {
    records.add(snapshot);
  }

  @override
  Future<void> markRegistered({required String id, required int position}) async {
    final index = records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    records[index] = records[index].copyWithRegistered(position);
  }
}

/// 失敗しても提案の表示と食事の登録は止めない。
class SupabaseCoachProposalLog implements CoachProposalLog {
  SupabaseCoachProposalLog({SupabaseClient? this._client});

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<void> recordShown(CoachProposalSnapshot snapshot) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null ||
        (snapshot.meals.isEmpty && snapshot.exerciseMessage == null)) {
      return;
    }
    try {
      await _supabase.from('coach_proposal_logs').insert({
        'id': snapshot.id,
        'user_id': userId,
        'local_date': snapshot.localDate,
        'shown_at': snapshot.shownAt.toUtc().toIso8601String(),
        'meals': snapshot.mealsJson,
        'exercise_message': snapshot.exerciseMessage,
        'advertising_use': false,
      });
    } catch (_) {}
  }

  @override
  Future<void> markRegistered({required String id, required int position}) async {
    if (position < 1 || position > 3) {
      return;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await _supabase
          .from('coach_proposal_logs')
          .update({
            'registered_position': position,
            'registered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {}
  }
}
