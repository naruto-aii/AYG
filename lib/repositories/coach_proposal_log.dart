import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/daily_coach.dart';
import '../services/daily_coach_session.dart';
import '../utils/id_generator.dart';
import 'persistent_event_outbox.dart';

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
    // 画面の通し番号（案ごと・回ごと）と同じ順で残す。
    for (final meal in [
      for (final plan in result.dayPlans) ...plan.meals,
    ]) {
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
    if (meal.slotLabel != null && meal.slotLabel!.trim().isNotEmpty)
      meal.slotLabel!.trim(),
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

  /// 送れなかった提案を、セッションがあるうちに再送する。
  Future<void> flushPending() async {}
}

class NoOpCoachProposalLog implements CoachProposalLog {
  const NoOpCoachProposalLog();

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {}

  @override
  Future<void> markRegistered({required String id}) async {}

  @override
  Future<void> flushPending() async {}
}

class MemoryCoachProposalLog implements CoachProposalLog {
  final List<CoachProposalRecord> records = [];

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {
    this.records.addAll(records);
  }

  @override
  Future<void> flushPending() async {}

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
  SupabaseCoachProposalLog({
    SupabaseClient? client,
    SharedPreferences? preferences,
    this.currentUserId,
    this.insertRow,
    this.updateRow,
    PersistentEventOutbox? outbox,
  }) : _client = client,
       _outbox =
           outbox ??
           PersistentEventOutbox(
             preferences: preferences,
             key: coachProposalOutboxKey,
           );

  final SupabaseClient? _client;
  final String? Function()? currentUserId;
  final Future<void> Function(Map<String, dynamic> row)? insertRow;
  final Future<void> Function(String id, String userId)? updateRow;
  final PersistentEventOutbox _outbox;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String? _userId() {
    final override = currentUserId;
    if (override != null) {
      return override();
    }
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {
    if (records.isEmpty) {
      return;
    }
    final userId = _userId();
    for (final record in records) {
      final payload = <String, dynamic>{
        'id': record.id,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'proposal': record.proposal,
        'registered': record.registered,
        'recorded_at': record.recordedAt.toUtc().toIso8601String(),
      };
      await _outbox.append({
        'id': record.id,
        'kind': 'coach_insert',
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'payload': payload,
      });
      if (userId == null || userId.isEmpty) {
        continue;
      }
      final sent = await _sendInsert(payload);
      if (sent) {
        await _remove(record.id);
      }
    }
  }

  @override
  Future<void> flushPending() async {
    final userId = _userId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final pending = await _outbox.read();
    final left = <Map<String, dynamic>>[];
    for (final row in pending) {
      if (outboxRowBelongsToOtherUser(row, userId)) {
        left.add(row);
        continue;
      }
      final payload = outboxPayloadForUser(row, userId);
      final sent = row['kind'] == 'coach_update'
          ? await _sendUpdate(payload['id'] as String, userId)
          : await _sendInsert(payload);
      if (!sent) {
        left.add(row);
      }
    }
    await _outbox.replace(left);
  }

  @override
  Future<void> markRegistered({required String id}) async {
    final pending = await _outbox.read();
    final index = pending.indexWhere(
      (row) => row['id'] == id && row['kind'] == 'coach_insert',
    );
    if (index != -1) {
      final payload = Map<String, dynamic>.from(
        pending[index]['payload'] as Map,
      );
      payload['registered'] = true;
      pending[index]['payload'] = payload;
      await _outbox.replace(pending);
    }
    final userId = _userId();
    if (userId == null || userId.isEmpty) {
      if (index == -1) {
        await _outbox.append({
          'id': 'registered:$id',
          'kind': 'coach_update',
          'payload': {'id': id, 'registered': true},
        });
      }
      return;
    }
    final sent = await _sendUpdate(id, userId);
    if (!sent && index == -1) {
      await _outbox.append({
        'id': 'registered:$id',
        'kind': 'coach_update',
        'user_id': userId,
        'payload': {'id': id, 'user_id': userId, 'registered': true},
      });
    }
  }

  Future<bool> _sendInsert(Map<String, dynamic> payload) {
    return deliverPersistentRow(
      table: 'coach_proposal_logs',
      payload: payload,
      requiredColumns: const {'id', 'user_id', 'proposal', 'recorded_at'},
      send: (row) async {
        final hook = insertRow;
        if (hook != null) {
          await hook(row);
          return;
        }
        await _supabase.from('coach_proposal_logs').insert(row);
      },
    );
  }

  Future<bool> _sendUpdate(String id, String userId) async {
    try {
      final hook = updateRow;
      if (hook != null) {
        await hook(id, userId);
        return true;
      }
      await _supabase
          .from('coach_proposal_logs')
          .update({'registered': true})
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } on PostgrestException catch (error, stackTrace) {
      if (error.code == '23505') {
        return true;
      }
      debugPrint('[AYG] coach proposal update failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[AYG] coach proposal update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _remove(String id) async {
    final rows = await _outbox.read();
    rows.removeWhere((row) => row['id'] == id);
    await _outbox.replace(rows);
  }
}

const coachProposalOutboxKey = 'coach_proposal_outbox';
