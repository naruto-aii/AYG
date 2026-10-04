import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  test('the fifth meal template is the first paid one', () {
    expect(
      SubscriptionCatalog.mealTemplateCreateRequiresPlus(
        savedCount: 3,
        isPlus: false,
      ),
      isFalse,
    );
    expect(
      SubscriptionCatalog.mealTemplateCreateRequiresPlus(
        savedCount: 4,
        isPlus: false,
      ),
      isTrue,
    );
    expect(
      SubscriptionCatalog.mealTemplateCreateRequiresPlus(
        savedCount: 4,
        isPlus: true,
      ),
      isFalse,
    );
    expect(
      SubscriptionLimitExceededException(
        SubscriptionLimitKind.mealTemplate,
      ).toString(),
      '食事テンプレートは何件でも、カロナビ+です。',
    );
  });

  test('a free account cannot save a fifth meal template', () async {
    final harness = await IsarTestHarness.create();
    addTearDown(harness.dispose);
    final controller = _controller(harness);
    addTearDown(controller.dispose);

    for (var index = 0; index < 4; index++) {
      await controller.saveMealTemplate(draft: _draft('朝食$index'));
    }

    expect(
      controller.saveMealTemplate(draft: _draft('5件目')),
      throwsA(isA<SubscriptionLimitExceededException>()),
    );

    final first = (await harness.mealTemplateRepository.getAll(
      'test-user-id',
    )).first;
    await controller.saveMealTemplate(
      draft: _draft('編集'),
      templateId: first.templateId,
    );
    expect(
      await harness.mealTemplateRepository.getAll('test-user-id'),
      hasLength(4),
    );
  });

  test('Calonavi Plus can save meal templates without a count cap', () async {
    final harness = await IsarTestHarness.create();
    addTearDown(harness.dispose);
    final controller = _controller(harness, plus: true);
    addTearDown(controller.dispose);

    for (var index = 0; index < 8; index++) {
      await controller.saveMealTemplate(draft: _draft('朝食$index'));
    }
    expect(
      await harness.mealTemplateRepository.getAll('test-user-id'),
      hasLength(8),
    );
  });
}

MealTemplateDraft _draft(String name) {
  return MealTemplateDraft(
    name: name,
    items: [
      MealTemplateItemDraft(
        name: 'ご飯',
        baseAmount: 150,
        unitType: FoodUnitType.g,
        kcalPerBase: 234,
        consumedAmount: 150,
        sortOrder: 1,
      ),
    ],
  );
}

AppController _controller(IsarTestHarness harness, {bool plus = false}) {
  return AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: 'test-user-id',
        email: 'test@example.com',
      ),
    ),
    dataSyncRepository: MockDataSyncRepository(),
    subscriptionRepository: _Plus(plus),
    userRepository: harness.userRepository,
    settingsRepository: harness.settingsRepository,
    foodRepository: harness.foodRepository,
    exerciseRepository: harness.exerciseRepository,
    weightRepository: harness.weightRepository,
    savedFoodRepository: harness.savedFoodRepository,
    mealTemplateRepository: harness.mealTemplateRepository,
  );
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => const Stream.empty();
}
