import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('Meal template owner migration regression', () {
    test('reassignOwnerUserId preserves template and items', () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);

      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(
            id: 'local-owner',
            email: 'local@example.com',
          ),
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

      final saved = await controller.saveMealTemplate(
        draft: MealTemplateDraft(
          name: 'Local Breakfast',
          items: [
            MealTemplateItemDraft(
              name: 'Toast',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 200,
              consumedAmount: 1,
              sortOrder: 1,
            ),
          ],
        ),
      );
      controller.dispose();

      await harness.mealTemplateRepository.reassignOwnerUserId(
        fromOwnerUserId: 'local-owner',
        toOwnerUserId: 'uuid-user',
      );

      final reloaded = await harness.mealTemplateRepository.getById(
        ownerUserId: 'uuid-user',
        templateId: saved.templateId,
      );
      expect(reloaded, isNotNull);
      expect(reloaded!.name, 'Local Breakfast');

      final items = await harness.mealTemplateRepository.getItems(
        ownerUserId: 'uuid-user',
        templateId: saved.templateId,
      );
      expect(items, hasLength(1));
      expect(items.single.name, 'Toast');
      expect(
        await harness.mealTemplateRepository.getAll('local-owner'),
        isEmpty,
      );
    });

    test('clearForOwner removes only matching owner templates', () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);

      await _saveTemplateForOwner(harness, 'user-a');
      await _saveTemplateForOwner(harness, 'user-b');

      await harness.mealTemplateRepository.clearForOwner('user-a');

      expect(await harness.mealTemplateRepository.getAll('user-a'), isEmpty);
      expect(
        await harness.mealTemplateRepository.getAll('user-b'),
        hasLength(1),
      );
    });
  });
}

Future<void> _saveTemplateForOwner(
  IsarTestHarness harness,
  String owner,
) async {
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: AuthUser(id: owner, email: '$owner@example.com'),
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

  await controller.saveMealTemplate(
    draft: MealTemplateDraft(
      name: 'Set $owner',
      items: [
        MealTemplateItemDraft(
          name: 'Item',
          baseAmount: 1,
          unitType: FoodUnitType.serving,
          kcalPerBase: 100,
          consumedAmount: 1,
          sortOrder: 1,
        ),
      ],
    ),
  );
  controller.dispose();
}
