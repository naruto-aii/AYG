import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_workout_template_repository.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('Meal template sync regression', () {
    test(
      'save template and register meal are independent operations',
      () async {
        final harness = await IsarTestHarness.create();
        addTearDown(harness.dispose);

        final controller = AppController(
          healthRepository: MockHealthRepository(isAvailable: false),
          authenticationRepository: MockAuthenticationRepository(
            currentUser: const AuthUser(id: 'user-a', email: 'a@test.com'),
          ),
          dataSyncRepository: MockDataSyncRepository(),
          userRepository: harness.userRepository,
          settingsRepository: harness.settingsRepository,
          foodRepository: harness.foodRepository,
          exerciseRepository: harness.exerciseRepository,
          weightRepository: harness.weightRepository,
          savedFoodRepository: harness.savedFoodRepository,
          mealTemplateRepository: harness.mealTemplateRepository,
          workoutTemplateRepository: harness.workoutTemplateRepository,
        );
        addTearDown(controller.dispose);

        await controller.saveMealTemplate(
          draft: MealTemplateDraft(
            name: 'Template Only',
            items: [
              MealTemplateItemDraft(
                name: 'Rice',
                baseAmount: 150,
                unitType: FoodUnitType.g,
                kcalPerBase: 250,
                consumedAmount: 150,
                sortOrder: 1,
              ),
            ],
          ),
        );

        expect(controller.foodEntries, isEmpty);

        await controller.registerFoodMealFromDrafts(
          mealGroupName: 'Direct Meal',
          items: [
            MealTemplateItemDraft(
              name: 'Bread',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 200,
              consumedAmount: 1,
              sortOrder: 1,
            ),
          ],
          loggedAt: DateTime(2026, 8, 1, 12),
        );

        expect(controller.foodEntries, hasLength(1));
        expect(controller.foodEntries.single.name, 'Bread');
        expect(
          await harness.mealTemplateRepository.getAll('user-a'),
          hasLength(1),
        );
      },
    );

    test('edit template removes orphan items locally', () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);

      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(id: 'user-a', email: 'a@test.com'),
        ),
        dataSyncRepository: MockDataSyncRepository(),
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
        savedFoodRepository: harness.savedFoodRepository,
        mealTemplateRepository: harness.mealTemplateRepository,
        workoutTemplateRepository: harness.workoutTemplateRepository,
      );
      addTearDown(controller.dispose);

      final saved = await controller.saveMealTemplate(
        draft: MealTemplateDraft(
          name: 'Two items',
          items: [
            MealTemplateItemDraft(
              itemId: 'keep',
              name: 'Keep',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 100,
              consumedAmount: 1,
              sortOrder: 1,
            ),
            MealTemplateItemDraft(
              itemId: 'drop',
              name: 'Drop',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 50,
              consumedAmount: 1,
              sortOrder: 2,
            ),
          ],
        ),
      );

      await controller.saveMealTemplate(
        draft: MealTemplateDraft(
          name: 'Two items',
          items: [
            MealTemplateItemDraft(
              itemId: 'keep',
              name: 'Keep',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 100,
              consumedAmount: 1,
              sortOrder: 1,
            ),
          ],
        ),
        templateId: saved.templateId,
      );

      final items = await harness.mealTemplateRepository.getItems(
        ownerUserId: 'user-a',
        templateId: saved.templateId,
      );
      expect(items, hasLength(1));
      expect(items.single.itemId, 'keep');
    });

    test('failed push retry does not wipe local templates', () async {
      final local = InMemoryWorkoutTemplateRepository();
      const userId = 'user-a';
      final template = sampleWorkoutTemplate(
        ownerUserId: userId,
        templateId: 'retry-1',
      );
      await local.saveWithItems(
        template: template,
        items: sampleWorkoutItems(templateId: 'retry-1'),
      );

      final remote = InMemoryWorkoutTemplateRepository();
      var pushAttempts = 0;
      Future<void> pushWithFailure() async {
        pushAttempts++;
        if (pushAttempts == 1) {
          throw Exception('network failure');
        }
        await syncPushWorkoutTemplates(
          userId: userId,
          local: local,
          remote: remote,
        );
      }

      await expectLater(pushWithFailure(), throwsException);
      expect(await local.getAll(userId), hasLength(1));

      await pushWithFailure();
      expect(await remote.getAll(userId), hasLength(1));
    });
  });
}
