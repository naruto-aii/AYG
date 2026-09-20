import 'dart:convert';

import 'exercise_entry.dart';

class StrengthSetLog {
  const StrengthSetLog({this.weightKg, this.reps});

  final double? weightKg;
  final int? reps;

  bool get isEmpty => weightKg == null && reps == null;

  Map<String, Object?> toJson() => {'kg': weightKg, 'reps': reps};

  static StrengthSetLog fromJson(Map<String, dynamic> json) {
    return StrengthSetLog(
      weightKg: (json['kg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
    );
  }
}

class StrengthExerciseLog {
  const StrengthExerciseLog({required this.name, required this.sets});

  final String name;
  final List<StrengthSetLog> sets;

  Map<String, Object?> toJson() => {
    'name': name,
    'sets': sets.map((set) => set.toJson()).toList(),
  };

  static StrengthExerciseLog fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    return StrengthExerciseLog(
      name: (json['name'] as String? ?? '').trim(),
      sets: rawSets is List
          ? rawSets
                .whereType<Map>()
                .map(
                  (set) =>
                      StrengthSetLog.fromJson(Map<String, dynamic>.from(set)),
                )
                .toList()
          : const [],
    );
  }
}

class StrengthWorkoutLog {
  const StrengthWorkoutLog({required this.exercises});

  final List<StrengthExerciseLog> exercises;

  bool get isEmpty => exercises.isEmpty;

  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  String get summary {
    return exercises
        .map((exercise) {
          if (exercise.sets.isEmpty) {
            return exercise.name;
          }
          final first = exercise.sets.first;
          final same = exercise.sets.every(
            (set) =>
                set.weightKg == first.weightKg && set.reps == first.reps,
          );
          final setLabel = '${exercise.sets.length}セット';
          if (same && first.weightKg != null && first.reps != null) {
            return '${exercise.name} $setLabel ${first.weightKg}kg×${first.reps}';
          }
          return '${exercise.name} $setLabel';
        })
        .join(' · ');
  }

  Map<String, Object?> toJson() => {
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  static StrengthWorkoutLog fromJson(Map<String, dynamic> json) {
    final raw = json['exercises'];
    return StrengthWorkoutLog(
      exercises: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (exercise) => StrengthExerciseLog.fromJson(
                    Map<String, dynamic>.from(exercise),
                  ),
                )
                .where((exercise) => exercise.name.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class StrengthNotesPayload {
  const StrengthNotesPayload({this.log, this.memo = ''});

  final StrengthWorkoutLog? log;
  final String memo;
}

/// Persists the multi-exercise set log inside `notes` so no DB migration is needed.
class StrengthNotesCodec {
  static const startMarker = '<!--ayg-strength-v1-->';
  static const endMarker = '<!--/ayg-strength-v1-->';

  static String encode({StrengthWorkoutLog? log, String memo = ''}) {
    final trimmedMemo = memo.trim();
    if (log == null || log.isEmpty) {
      return trimmedMemo;
    }
    final buffer = StringBuffer()
      ..writeln(startMarker)
      ..writeln(jsonEncode(log.toJson()))
      ..writeln(endMarker);
    if (trimmedMemo.isNotEmpty) {
      buffer.write(trimmedMemo);
    }
    return buffer.toString().trim();
  }

  static StrengthNotesPayload parse(String? raw) {
    final text = raw ?? '';
    final start = text.indexOf(startMarker);
    final end = text.indexOf(endMarker);
    if (start < 0 || end < 0 || end <= start) {
      return StrengthNotesPayload(memo: text.trim());
    }
    final jsonText = text.substring(start + startMarker.length, end).trim();
    final memo = text.substring(end + endMarker.length).trim();
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        final log = StrengthWorkoutLog.fromJson(decoded);
        return StrengthNotesPayload(
          log: log.isEmpty ? null : log,
          memo: memo,
        );
      }
    } catch (_) {}
    return StrengthNotesPayload(memo: memo.isEmpty ? text.trim() : memo);
  }
}

extension ExerciseStrengthDetails on ExerciseEntry {
  StrengthWorkoutLog? get strengthLog {
    final parsed = StrengthNotesCodec.parse(notes).log;
    if (parsed != null && !parsed.isEmpty) {
      return parsed;
    }
    return legacyStrengthLog;
  }

  StrengthWorkoutLog? get legacyStrengthLog {
    if (sets == null && reps == null && liftWeightKg == null) {
      return null;
    }
    final setCount = sets != null && sets! > 0 ? sets! : 1;
    return StrengthWorkoutLog(
      exercises: [
        StrengthExerciseLog(
          name: name.trim().isEmpty ? '筋トレ' : name.trim(),
          sets: [
            for (var i = 0; i < setCount; i++)
              StrengthSetLog(weightKg: liftWeightKg, reps: reps),
          ],
        ),
      ],
    );
  }

  String get memoText => StrengthNotesCodec.parse(notes).memo;

  String? get strengthSummary {
    final log = strengthLog;
    if (log == null || log.isEmpty) {
      return null;
    }
    return log.summary;
  }
}
