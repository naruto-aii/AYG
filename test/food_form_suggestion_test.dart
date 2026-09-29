import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_form_suggestion.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/search_suggestion_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('Food form suggestions', () {
    const suggestionService = SearchSuggestionService();

    test(
      'ranks foods and templates without mixing owners in service layer',
      () {
        final now = DateTime(2026, 8, 1);
        final ranked = suggestionService.rankFoodFormSuggestions(
          foods: [
            SavedFood(
              foodId: 'f1',
              ownerUserId: 'user-a',
              name: 'Rice',
              normalizedName: 'rice',
              baseAmount: 100,
              unitType: FoodUnitType.g,
              useCount: 5,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          templates: [
            MealTemplate(
              templateId: 't1',
              ownerUserId: 'user-a',
              name: 'Breakfast',
              normalizedName: 'breakfast',
              totalKcal: 400,
              totalProteinG: 20,
              totalFatG: 10,
              totalCarbG: 50,
              useCount: 10,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          templateItemCounts: {'t1': 3},
        );

        expect(ranked.first, isA<MealTemplateFormSuggestion>());
        expect((ranked.first as MealTemplateFormSuggestion).itemCount, 3);
        expect(ranked.any((s) => s is SavedFoodFormSuggestion), isTrue);
      },
    );

    test(
      'AppController getFoodFormSuggestions returns only current owner data',
      () async {
        final harness = await IsarTestHarness.create();
        addTearDown(harness.dispose);

        final controllerA = AppController(
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

        await controllerA.saveMealTemplate(
          draft: MealTemplateDraft(
            name: 'User A Set',
            items: [
              MealTemplateItemDraft(
                name: 'Egg',
                baseAmount: 1,
                unitType: FoodUnitType.serving,
                kcalPerBase: 80,
                consumedAmount: 1,
                sortOrder: 1,
              ),
            ],
          ),
        );

        final suggestions = await controllerA.getFoodFormSuggestions('');
        expect(
          suggestions.whereType<MealTemplateFormSuggestion>(),
          hasLength(1),
        );
        expect(
          (suggestions.first as MealTemplateFormSuggestion).template.name,
          'User A Set',
        );

        controllerA.dispose();

        final controllerB = AppController(
          healthRepository: MockHealthRepository(isAvailable: false),
          authenticationRepository: MockAuthenticationRepository(
            currentUser: const AuthUser(id: 'user-b', email: 'b@test.com'),
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

        final bSuggestions = await controllerB.getFoodFormSuggestions('');
        expect(bSuggestions.whereType<MealTemplateFormSuggestion>(), isEmpty);
        controllerB.dispose();
      },
    );
  });
}
