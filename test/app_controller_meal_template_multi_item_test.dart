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
  group('AppController meal template multi-item', () {
    late IsarTestHarness harness;
    late AppController controller;

    setUp(() async {
      harness = await IsarTestHarness.create();
      controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(
            id: 'test-user-id',
            email: 'test@example.com',
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
      );
    });

    tearDown(() async {
      controller.dispose();
      await harness.dispose();
    });

    MealTemplateDraft threeItemDraft() {
      return MealTemplateDraft(
        name: 'Three Item Set',
        items: [
          MealTemplateItemDraft(
            name: 'A',
            baseAmount: 100,
            unitType: FoodUnitType.g,
            kcalPerBase: 100,
            consumedAmount: 100,
            sortOrder: 1,
          ),
          MealTemplateItemDraft(
            name: 'B',
            baseAmount: 100,
            unitType: FoodUnitType.g,
            kcalPerBase: 200,
            consumedAmount: 100,
            sortOrder: 2,
          ),
          MealTemplateItemDraft(
            name: 'C',
            baseAmount: 1,
            unitType: FoodUnitType.serving,
            kcalPerBase: 50,
            consumedAmount: 1,
            sortOrder: 3,
          ),
        ],
      );
    }

    test(
      'saveMealTemplate persists three distinct items after reload',
      () async {
        final saved = await controller.saveMealTemplate(
          draft: threeItemDraft(),
        );

        final reloaded = await controller.getMealTemplateWithItems(
          saved.templateId,
        );

        expect(reloaded, isNotNull);
        expect(reloaded!.items, hasLength(3));
        expect(reloaded.items.map((item) => item.itemId).toSet(), hasLength(3));
        expect(reloaded.items.map((item) => item.name), ['A', 'B', 'C']);
      },
    );

    test(
      'applyMealTemplate creates three food entries with distinct ids',
      () async {
        final saved = await controller.saveMealTemplate(
          draft: threeItemDraft(),
        );
        final beforeCount = controller.foodEntries.length;

        final result = await controller.applyMealTemplate(
          templateId: saved.templateId,
        );

        expect(result.success, isTrue);
        expect(result.createdEntryCount, 3);
        expect(controller.foodEntries.length, beforeCount + 3);

        final created = controller.foodEntries
            .where((entry) => {'A', 'B', 'C'}.contains(entry.name))
            .toList();
        expect(created, hasLength(3));
        expect(created.map((entry) => entry.id).toSet(), hasLength(3));
      },
    );

    test(
      'rapid apply attempts do not duplicate entries when guarded externally',
      () async {
        final saved = await controller.saveMealTemplate(
          draft: threeItemDraft(),
        );

        final first = await controller.applyMealTemplate(
          templateId: saved.templateId,
        );
        final second = await controller.applyMealTemplate(
          templateId: saved.templateId,
        );

        expect(first.success, isTrue);
        expect(second.success, isTrue);
        expect(first.createdEntryCount, 3);
        expect(second.createdEntryCount, 3);
        expect(
          controller.foodEntries.map((entry) => entry.id).toSet(),
          hasLength(6),
        );
      },
    );

    test(
      'saveWithItems keeps parent and all items in one repository transaction',
      () async {
        final saved = await controller.saveMealTemplate(
          draft: threeItemDraft(),
        );
        final items = await harness.mealTemplateRepository.getItems(
          ownerUserId: 'test-user-id',
          templateId: saved.templateId,
        );
        final template = await harness.mealTemplateRepository.getById(
          ownerUserId: 'test-user-id',
          templateId: saved.templateId,
        );

        expect(template, isNotNull);
        expect(items, hasLength(3));
      },
    );
  });
}
