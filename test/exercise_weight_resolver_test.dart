import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/services/exercise_weight_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ExerciseWeightResolver();

  WeightEntry entry({
    required String id,
    required double kg,
    required DateTime at,
  }) {
    return WeightEntry(
      id: id,
      weightKg: kg,
      recordedAt: at,
      source: WeightSource.manual,
    );
  }

  UserProfile profile({double weightKg = 70}) {
    return UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 170,
      weightKg: weightKg,
    );
  }

  group('ExerciseWeightResolver', () {
    test('uses latest weight on or before exercise datetime', () {
      final exerciseAt = DateTime(2026, 8, 1, 18);
      final ref = resolver.resolve(
        exerciseLoggedAt: exerciseAt,
        weightEntries: [
          entry(id: 'w1', kg: 72, at: DateTime(2026, 7, 30)),
          entry(id: 'w2', kg: 71, at: DateTime(2026, 8, 1, 8)),
          entry(id: 'w3', kg: 69, at: DateTime(2026, 8, 2)),
        ],
        profile: profile(),
      );

      expect(ref?.weightKg, 71);
      expect(ref?.source, WeightReferenceSource.weightEntry);
    });

    test('does not use future weight entries', () {
      final exerciseAt = DateTime(2026, 8, 1, 12);
      final ref = resolver.resolve(
        exerciseLoggedAt: exerciseAt,
        weightEntries: [
          entry(id: 'future', kg: 60, at: DateTime(2026, 8, 1, 18)),
          entry(id: 'past', kg: 68, at: DateTime(2026, 8, 1, 11, 59)),
        ],
        profile: profile(weightKg: 75),
      );

      expect(ref?.weightKg, 68);
    });

    test('uses profile fallback when no prior weight entry', () {
      final ref = resolver.resolve(
        exerciseLoggedAt: DateTime(2026, 8, 1),
        weightEntries: [entry(id: 'future', kg: 60, at: DateTime(2026, 8, 2))],
        profile: profile(weightKg: 73),
      );

      expect(ref?.weightKg, 73);
      expect(ref?.source, WeightReferenceSource.profile);
    });

    test('returns null when no weight source exists', () {
      final ref = resolver.resolve(
        exerciseLoggedAt: DateTime(2026, 8, 1),
        weightEntries: const [],
        profile: null,
      );
      expect(ref, isNull);
    });

    test(
      'same-day multiple entries picks most recent before exercise time',
      () {
        final exerciseAt = DateTime(2026, 8, 1, 15, 30);
        final ref = resolver.resolve(
          exerciseLoggedAt: exerciseAt,
          weightEntries: [
            entry(id: 'morning', kg: 70, at: DateTime(2026, 8, 1, 7)),
            entry(id: 'noon', kg: 69.5, at: DateTime(2026, 8, 1, 12)),
            entry(id: 'after', kg: 69, at: DateTime(2026, 8, 1, 16)),
          ],
          profile: profile(),
        );

        expect(ref?.weightKg, 69.5);
      },
    );
  });
}
