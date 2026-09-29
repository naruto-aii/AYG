import 'package:ayg/models/exercise_calculation_source.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_workout_template_repository.dart';

void main() {
  group('Workout template sync boundary (fake remote/local)', () {
    test('push/pull preserves template and items for same owner', () async {
      final local = InMemoryWorkoutTemplateRepository();
      final remote = InMemoryWorkoutTemplateRepository();
      const userId = 'user-a';
      final template = sampleWorkoutTemplate(
        ownerUserId: userId,
        templateId: 'wt-1',
      );
      final items = sampleWorkoutItems(templateId: 'wt-1');

      await local.saveWithItems(template: template, items: items);
      await syncPushWorkoutTemplates(
        userId: userId,
        local: local,
        remote: remote,
      );

      final freshLocal = InMemoryWorkoutTemplateRepository();
      await syncPullWorkoutTemplates(
        userId: userId,
        local: freshLocal,
        remote: remote,
      );

      final loaded = await freshLocal.getById(
        ownerUserId: userId,
        templateId: 'wt-1',
      );
      expect(loaded, isNotNull);
      final loadedItems = await freshLocal.getItems(
        ownerUserId: userId,
        templateId: 'wt-1',
      );
      expect(loadedItems, hasLength(2));
    });

    test(
      'pull replaces local owner data without touching other owners',
      () async {
        final local = InMemoryWorkoutTemplateRepository();
        final remote = InMemoryWorkoutTemplateRepository();

        await remote.saveWithItems(
          template: sampleWorkoutTemplate(
            ownerUserId: 'user-a',
            templateId: 'remote-a',
          ),
          items: sampleWorkoutItems(templateId: 'remote-a'),
        );
        await local.saveWithItems(
          template: sampleWorkoutTemplate(
            ownerUserId: 'user-b',
            templateId: 'local-b',
          ),
          items: sampleWorkoutItems(templateId: 'local-b'),
        );
        await local.saveWithItems(
          template: sampleWorkoutTemplate(
            ownerUserId: 'user-a',
            templateId: 'stale-a',
          ),
          items: sampleWorkoutItems(templateId: 'stale-a'),
        );

        await syncPullWorkoutTemplates(
          userId: 'user-a',
          local: local,
          remote: remote,
        );

        expect(await local.getAll('user-a'), hasLength(1));
        expect(
          await local.getById(ownerUserId: 'user-a', templateId: 'remote-a'),
          isNotNull,
        );
        expect(await local.getAll('user-b'), hasLength(1));
      },
    );

    test('push removes orphan items on re-sync', () async {
      final local = InMemoryWorkoutTemplateRepository();
      final remote = InMemoryWorkoutTemplateRepository();
      const userId = 'user-a';
      final template = sampleWorkoutTemplate(
        ownerUserId: userId,
        templateId: 'wt-edit',
      );

      await remote.saveWithItems(
        template: template,
        items: sampleWorkoutItems(templateId: 'wt-edit'),
      );
      await syncPullWorkoutTemplates(
        userId: userId,
        local: local,
        remote: remote,
      );

      final editedItems = [sampleWorkoutItems(templateId: 'wt-edit').first];
      await local.saveWithItems(template: template, items: editedItems);
      await syncPushWorkoutTemplates(
        userId: userId,
        local: local,
        remote: remote,
      );

      final remoteItems = await remote.getItems(
        ownerUserId: userId,
        templateId: 'wt-edit',
      );
      expect(remoteItems, hasLength(1));
      expect(remoteItems.single.name, 'Run');
    });

    test('re-sync does not duplicate templates', () async {
      final local = InMemoryWorkoutTemplateRepository();
      final remote = InMemoryWorkoutTemplateRepository();
      const userId = 'user-a';
      final template = sampleWorkoutTemplate(
        ownerUserId: userId,
        templateId: 'wt-dup',
      );
      await local.saveWithItems(
        template: template,
        items: sampleWorkoutItems(templateId: 'wt-dup'),
      );

      await syncPushWorkoutTemplates(
        userId: userId,
        local: local,
        remote: remote,
      );
      await syncPushWorkoutTemplates(
        userId: userId,
        local: local,
        remote: remote,
      );

      expect(await remote.loadAllOwnIncludingDeleted(userId), hasLength(1));
    });
  });

  group('Exercise entry calculation row mapper', () {
    test('roundtrips MET, gross, net, weight snapshot, source', () {
      final entry = ExerciseEntry(
        id: 'ex-1',
        name: 'Run',
        durationMin: 30,
        burnedKcal: 300,
        loggedAt: DateTime(2026, 8, 1, 18),
        grossKcal: 300,
        netKcal: 250,
        metValue: 8,
        weightKgSnapshot: 68,
        calculationSource: ExerciseCalculationSource.metEstimate,
        calculationVersion: 'v1',
        sourceKey: 'run-moderate',
      );

      final row = ExerciseEntryRowMapper.toRow(entry, userId: 'user-a');
      final restored = ExerciseEntryRowMapper.fromRow(row);

      expect(restored.grossKcal, 300);
      expect(restored.netKcal, 250);
      expect(restored.metValue, 8);
      expect(restored.weightKgSnapshot, 68);
      expect(restored.calculationSource, ExerciseCalculationSource.metEstimate);
      expect(restored.effectiveNetKcal, 250);
    });

    test('legacy row without net keeps burnedKcal fallback', () {
      final row = {
        'entry_id': 'legacy',
        'name': 'Old',
        'duration_min': 20,
        'burned_kcal': 180,
        'logged_at': DateTime(2026, 7, 1).toIso8601String(),
      };
      final restored = ExerciseEntryRowMapper.fromRow(row);
      expect(restored.effectiveNetKcal, 180);
    });
  });
}
