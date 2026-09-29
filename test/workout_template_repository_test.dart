import 'dart:io';

import 'package:ayg/database/isar_service.dart';
import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/repositories/isar/workout_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  group('WorkoutTemplateRepository', () {
    test('saves template with ordered items', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 8, 1);

      await harness.workoutTemplateRepository.saveWithItems(
        template: WorkoutTemplate(
          templateId: 'wt-1',
          ownerUserId: 'user-a',
          name: 'Leg Day',
          normalizedName: 'leg day',
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          WorkoutTemplateItem(
            itemId: 'item-2',
            name: 'Squat',
            categoryKey: ExerciseCategory.strength.id,
            durationMin: 20,
            sortOrder: 2,
          ),
          WorkoutTemplateItem(
            itemId: 'item-1',
            name: 'Run',
            categoryKey: ExerciseCategory.aerobic.id,
            durationMin: 30,
            sortOrder: 1,
          ),
        ],
      );

      final items = await harness.workoutTemplateRepository.getItems(
        ownerUserId: 'user-a',
        templateId: 'wt-1',
      );

      expect(items, hasLength(2));
      expect(items.first.name, 'Run');
      expect(items.last.name, 'Squat');
    });

    test('persists after Isar close and reopen', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await IsarService.close();
      final directory = await Directory.systemTemp.createTemp(
        'ayg_workout_persist_',
      );
      final path = directory.path;

      {
        final isar = await IsarService.openForTesting(path);
        final repo = WorkoutTemplateRepository(isar);
        final now = DateTime(2026, 8, 2);
        await repo.saveWithItems(
          template: WorkoutTemplate(
            templateId: 'persist-1',
            ownerUserId: 'user-a',
            name: 'Morning',
            normalizedName: 'morning',
            createdAt: now,
            updatedAt: now,
          ),
          items: [
            WorkoutTemplateItem(
              itemId: 'item-1',
              name: 'Walk',
              durationMin: 15,
              sortOrder: 1,
            ),
          ],
        );
        await IsarService.close();
      }

      final isar2 = await IsarService.openForTesting(path);
      addTearDown(() async {
        await IsarService.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final repo2 = WorkoutTemplateRepository(isar2);
      final loaded = await repo2.getById(
        ownerUserId: 'user-a',
        templateId: 'persist-1',
      );
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Morning');
      final items = await repo2.getItems(
        ownerUserId: 'user-a',
        templateId: 'persist-1',
      );
      expect(items.single.name, 'Walk');
    });

    test('reassignOwnerUserId migrates templates and items', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 8, 3);

      await harness.workoutTemplateRepository.saveWithItems(
        template: WorkoutTemplate(
          templateId: 'migrate-1',
          ownerUserId: 'local-owner',
          name: 'Temp',
          normalizedName: 'temp',
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          WorkoutTemplateItem(
            itemId: 'item-1',
            name: 'Bike',
            durationMin: 25,
            sortOrder: 1,
          ),
        ],
      );

      await harness.workoutTemplateRepository.reassignOwnerUserId(
        fromOwnerUserId: 'local-owner',
        toOwnerUserId: 'uuid-user',
      );

      expect(
        await harness.workoutTemplateRepository.getAll('local-owner'),
        isEmpty,
      );
      final migrated = await harness.workoutTemplateRepository.getById(
        ownerUserId: 'uuid-user',
        templateId: 'migrate-1',
      );
      expect(migrated, isNotNull);
      final items = await harness.workoutTemplateRepository.getItems(
        ownerUserId: 'uuid-user',
        templateId: 'migrate-1',
      );
      expect(items.single.name, 'Bike');
    });

    test('clearForOwner removes only matching owner', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 8, 4);

      for (final owner in ['user-a', 'user-b']) {
        await harness.workoutTemplateRepository.saveWithItems(
          template: WorkoutTemplate(
            templateId: 'tmpl-$owner',
            ownerUserId: owner,
            name: owner,
            normalizedName: owner,
            createdAt: now,
            updatedAt: now,
          ),
          items: [
            WorkoutTemplateItem(
              itemId: 'item-$owner',
              name: 'Move',
              durationMin: 10,
              sortOrder: 1,
            ),
          ],
        );
      }

      await harness.workoutTemplateRepository.clearForOwner('user-a');

      expect(await harness.workoutTemplateRepository.getAll('user-a'), isEmpty);
      expect(
        await harness.workoutTemplateRepository.getAll('user-b'),
        hasLength(1),
      );
    });
  });
}
