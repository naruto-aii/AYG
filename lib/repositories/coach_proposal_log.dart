import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/daily_coach.dart';
import '../services/daily_coach_session.dart';
import '../utils/id_generator.dart';

/// 経営判断スプレッドシート。アプリはこの版では書き込まない。
const coachDecisionSpreadsheetId =
    '148oUF5Coz17Bk7poFs0xQOdiO3Z_tkNB-PKN5w74H80';

/// 出した提案1件。保存するのは提案内容、登録したか、日時だけ。
class CoachProposalRecord {
  const CoachProposalRecord({
    required this.id,
    required this.proposal,
    required this.recordedAt,
    this.registered = false,
  });

  final String id;
  final String proposal;
  final bool registered;
  final DateTime recordedAt;

  CoachProposalRecord copyWithRegistered() {
    return CoachProposalRecord(
      id: id,
      proposal: proposal,
      recordedAt: recordedAt,
      registered: true,
    );
  }
}

List<CoachProposalRecord> coachProposalRecords({
  required DateTime now,
  required DailyCoachLoadResult result,
}) {
  if (result.status != DailyCoachStatus.ready) {
    return const [];
  }
  final records = <CoachProposalRecord>[];
  if (result.offersMeals) {
    for (final meal in result.meals.take(3)) {
      final text = coachMealProposalText(meal);
      if (text.isEmpty) {
        continue;
      }
      records.add(
        CoachProposalRecord(
          id: generateUniqueId(),
          proposal: text,
          recordedAt: now,
        ),
      );
    }
  }
  if (result.offersExercise) {
    final exercise = (result.exercise?.message ?? result.exerciseMessage)
        ?.trim();
    if (exercise != null && exercise.isNotEmpty) {
      records.add(
        CoachProposalRecord(
          id: generateUniqueId(),
          proposal: exercise,
          recordedAt: now,
        ),
      );
    }
  }
  return records;
}

String coachMealProposalText(CoachMealProposal meal) {
  final lines = <String>[
    meal.headline.trim(),
    '約${meal.kcal.round()}kcal',
    for (final item in meal.components) '${item.displayName} ${item.grams}g',
    if (meal.macroNote != null && meal.macroNote!.trim().isNotEmpty)
      meal.macroNote!.trim(),
  ].where((line) => line.isNotEmpty);
  final text = lines.join('\n');
  if (text.length <= 2000) {
    return text;
  }
  return text.substring(0, 2000);
}

abstract class CoachProposalLog {
  Future<void> recordShown(List<CoachProposalRecord> records);

  Future<void> markRegistered({required String id});
}

class NoOpCoachProposalLog implements CoachProposalLog {
  const NoOpCoachProposalLog();

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {}

  @override
  Future<void> markRegistered({required String id}) async {}
}

class MemoryCoachProposalLog implements CoachProposalLog {
  final List<CoachProposalRecord> records = [];

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {
    this.records.addAll(records);
  }

  @override
  Future<void> markRegistered({required String id}) async {
    final index = records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    records[index] = records[index].copyWithRegistered();
  }
}

/// 失敗しても提案の表示と食事の登録は止めない。シートへは送らない。
class SupabaseCoachProposalLog implements CoachProposalLog {
  SupabaseCoachProposalLog({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {
    if (records.isEmpty) {
      return;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await _supabase.from('coach_proposal_logs').insert([
        for (final record in records)
          {
            'id': record.id,
            'user_id': userId,
            'proposal': record.proposal,
            'registered': record.registered,
            'recorded_at': record.recordedAt.toUtc().toIso8601String(),
          },
      ]);
    } catch (_) {}
  }

  @override
  Future<void> markRegistered({required String id}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    try {
      await _supabase
          .from('coach_proposal_logs')
          .update({'registered': true})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {}
  }
}
